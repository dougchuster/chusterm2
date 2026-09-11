import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, asc, eq, isNull } from 'drizzle-orm'
import { db } from '../db/client.js'
import { lossReasons } from '../db/schema.js'
import { writeAuditEvent } from '../lib/audit.js'

const createSchema = z.object({
  // Deprecated: accepted for backwards compatibility but IGNORED — the tenant
  // is always derived from the verified JWT (request.auth.accountId).
  accountId: z.number().int().positive().optional(),
  label: z.string().min(1).max(255),
  slug: z.string().min(1).max(120).optional(),
  position: z.number().int().min(0).optional(),
})

const updateSchema = createSchema.partial().omit({ accountId: true })

const listQuerySchema = z.object({
  // Deprecated: accepted but IGNORED in favor of the token claim.
  accountId: z.coerce.number().int().positive().optional(),
})

const slugify = (value: string) =>
  value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
    .slice(0, 120)

export async function lossReasonRoutes(app: FastifyInstance): Promise<void> {
  app.get('/loss-reasons', async (request, reply) => {
    try {
      const query = listQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const data = await db
        .select()
        .from(lossReasons)
        .where(and(eq(lossReasons.accountId, request.auth.accountId), isNull(lossReasons.archivedAt)))
        .orderBy(asc(lossReasons.position), asc(lossReasons.label))

      return reply.send({ data, total: data.length, page: 1, limit: data.length })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/loss-reasons', async (request, reply) => {
    try {
      const body = createSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const payload = {
        ...body.data,
        accountId: request.auth.accountId,
        slug: body.data.slug ?? slugify(body.data.label),
      }

      const [created] = await db.insert(lossReasons).values(payload).returning()

      await writeAuditEvent({
        accountId: created.accountId,
        entityType: 'loss_reason',
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

  app.patch('/loss-reasons/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }
      const body = updateSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [existing] = await db
        .select()
        .from(lossReasons)
        .where(and(eq(lossReasons.id, id), eq(lossReasons.accountId, request.auth.accountId), isNull(lossReasons.archivedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Loss reason not found' })
      }

      const [updated] = await db
        .update(lossReasons)
        .set({ ...body.data, updatedAt: new Date() })
        .where(and(eq(lossReasons.id, id), eq(lossReasons.accountId, request.auth.accountId)))
        .returning()

      await writeAuditEvent({
        accountId: updated.accountId,
        entityType: 'loss_reason',
        entityId: updated.id,
        action: 'updated',
        before: existing,
        after: updated,
      })

      return reply.send(updated)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.delete('/loss-reasons/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [existing] = await db
        .select()
        .from(lossReasons)
        .where(and(eq(lossReasons.id, id), eq(lossReasons.accountId, request.auth.accountId), isNull(lossReasons.archivedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Loss reason not found' })
      }

      await db
        .update(lossReasons)
        .set({ archivedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(lossReasons.id, id), eq(lossReasons.accountId, request.auth.accountId)))

      await writeAuditEvent({
        accountId: existing.accountId,
        entityType: 'loss_reason',
        entityId: existing.id,
        action: 'archived',
        before: existing,
      })

      return reply.status(204).send()
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })
}
