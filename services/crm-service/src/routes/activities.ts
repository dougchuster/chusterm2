import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, asc, eq, isNull, sql } from 'drizzle-orm'
import { db } from '../db/client.js'
import { activities } from '../db/schema.js'
import { writeAuditEvent } from '../lib/audit.js'

const dateSchema = z.string().datetime().transform(value => new Date(value))

const createSchema = z.object({
  accountId: z.number().int().positive(),
  leadProfileId: z.string().uuid(),
  dealId: z.string().uuid().optional(),
  activityType: z.string().min(1).max(100),
  title: z.string().min(1).max(255),
  description: z.string().max(1000).optional(),
  priority: z.enum(['low', 'normal', 'high', 'urgent']).optional(),
  dueAt: dateSchema.optional(),
  reminderAt: dateSchema.optional(),
})

const updateSchema = createSchema
  .partial()
  .omit({ accountId: true })
  .extend({
    completedAt: dateSchema.optional(),
    outcome: z.string().max(255).optional(),
  })

const listQuerySchema = z.object({
  accountId: z.coerce.number().int().positive(),
  leadProfileId: z.string().uuid().optional(),
  dealId: z.string().uuid().optional(),
  status: z.enum(['pending', 'completed', 'overdue', 'upcoming']).optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
})

export async function activityRoutes(app: FastifyInstance): Promise<void> {
  app.get('/activities', async (request, reply) => {
    try {
      const query = listQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const { accountId, leadProfileId, dealId, status, page, limit } = query.data
      const offset = (page - 1) * limit

      const conditions = [
        eq(activities.accountId, accountId),
        isNull(activities.deletedAt),
      ]

      if (leadProfileId) conditions.push(eq(activities.leadProfileId, leadProfileId))
      if (dealId) conditions.push(eq(activities.dealId, dealId))
      if (status === 'completed') {
        conditions.push(sql`${activities.completedAt} IS NOT NULL`)
      } else if (status === 'pending') {
        conditions.push(isNull(activities.completedAt))
      } else if (status === 'overdue') {
        conditions.push(isNull(activities.completedAt))
        conditions.push(sql`${activities.dueAt} < now()`)
      } else if (status === 'upcoming') {
        conditions.push(isNull(activities.completedAt))
        conditions.push(sql`${activities.dueAt} >= now()`)
      }

      const where = and(...conditions)

      const [data, countResult] = await Promise.all([
        db
          .select()
          .from(activities)
          .where(where)
          .orderBy(asc(activities.dueAt), asc(activities.createdAt))
          .limit(limit)
          .offset(offset),
        db.select({ count: sql<number>`cast(count(*) as int)` }).from(activities).where(where),
      ])

      return reply.send({
        data,
        total: countResult[0]?.count ?? 0,
        page,
        limit,
      })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.get('/activities/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [activity] = await db
        .select()
        .from(activities)
        .where(and(eq(activities.id, id), isNull(activities.deletedAt)))
        .limit(1)

      if (!activity) {
        return reply.status(404).send({ error: 'NotFound', message: 'Activity not found' })
      }

      return reply.send(activity)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/activities', async (request, reply) => {
    try {
      const body = createSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [created] = await db.insert(activities).values(body.data).returning()

      await writeAuditEvent({
        accountId: created.accountId,
        entityType: 'activity',
        entityId: created.id,
        action: 'created',
        after: created,
      })

      return reply.status(201).send(created)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.patch('/activities/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const body = updateSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [existing] = await db
        .select()
        .from(activities)
        .where(and(eq(activities.id, id), isNull(activities.deletedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Activity not found' })
      }

      const [updated] = await db
        .update(activities)
        .set({ ...body.data, updatedAt: new Date() })
        .where(eq(activities.id, id))
        .returning()

      await writeAuditEvent({
        accountId: updated.accountId,
        entityType: 'activity',
        entityId: updated.id,
        action: body.data.completedAt ? 'completed' : 'updated',
        before: existing,
        after: updated,
      })

      return reply.send(updated)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.delete('/activities/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [existing] = await db
        .select()
        .from(activities)
        .where(and(eq(activities.id, id), isNull(activities.deletedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Activity not found' })
      }

      await db
        .update(activities)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(eq(activities.id, id))

      await writeAuditEvent({
        accountId: existing.accountId,
        entityType: 'activity',
        entityId: existing.id,
        action: 'deleted',
        before: existing,
      })

      return reply.status(204).send()
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })
}
