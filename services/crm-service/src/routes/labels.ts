import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, eq, isNull } from 'drizzle-orm'
import { db } from '../db/client.js'
import { crmLabelgings, crmLabels } from '../db/schema.js'
import { writeAuditEvent } from '../lib/audit.js'

const listLabelsQuerySchema = z.object({
  accountId: z.coerce.number().int().positive(),
  category: z.string().optional(),
  scope: z.string().optional(),
})

const createLabelSchema = z.object({
  accountId: z.number().int().positive(),
  category: z.string().min(1).max(80),
  slug: z.string().min(1).max(160),
  displayName: z.string().min(1).max(160),
  color: z.string().max(20).optional(),
  description: z.string().max(1000).nullable().optional(),
  scope: z.string().max(50).optional(),
  isSystem: z.boolean().optional(),
})

const listLabelgingsQuerySchema = z.object({
  accountId: z.coerce.number().int().positive(),
  targetType: z.string().min(1).max(50),
  targetId: z.string().min(1).max(100),
})

const createLabelgingSchema = z.object({
  accountId: z.number().int().positive(),
  labelId: z.string().uuid().optional(),
  slug: z.string().max(160).optional(),
  targetType: z.string().min(1).max(50),
  targetId: z.string().min(1).max(100),
  source: z.string().max(50).optional(),
  confidence: z.number().int().min(0).max(100).optional(),
  createdById: z.number().int().positive().optional(),
})

async function resolveLabel(accountId: number, labelId?: string, slug?: string) {
  if (labelId) {
    const [label] = await db
      .select()
      .from(crmLabels)
      .where(and(eq(crmLabels.id, labelId), eq(crmLabels.accountId, accountId), isNull(crmLabels.archivedAt)))
      .limit(1)
    return label
  }

  if (slug) {
    const [label] = await db
      .select()
      .from(crmLabels)
      .where(and(eq(crmLabels.slug, slug), eq(crmLabels.accountId, accountId), isNull(crmLabels.archivedAt)))
      .limit(1)
    return label
  }

  return null
}

export async function labelRoutes(app: FastifyInstance): Promise<void> {
  app.get('/labels', async (request, reply) => {
    try {
      const query = listLabelsQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const { accountId, category, scope } = query.data
      const conditions = [eq(crmLabels.accountId, accountId), isNull(crmLabels.archivedAt)]
      if (category) conditions.push(eq(crmLabels.category, category))
      if (scope) conditions.push(eq(crmLabels.scope, scope))

      const labels = await db
        .select()
        .from(crmLabels)
        .where(and(...conditions))

      return reply.send({ data: labels })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/labels', async (request, reply) => {
    try {
      const body = createLabelSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [created] = await db
        .insert(crmLabels)
        .values({
          ...body.data,
          color: body.data.color ?? '#8b8b99',
          scope: body.data.scope ?? 'all',
          isSystem: body.data.isSystem ?? false,
        })
        .returning()

      await writeAuditEvent({
        accountId: created.accountId,
        entityType: 'crm_label',
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

  app.get('/labelgings', async (request, reply) => {
    try {
      const query = listLabelgingsQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const { accountId, targetType, targetId } = query.data

      const rows = await db
        .select({
          id: crmLabelgings.id,
          accountId: crmLabelgings.accountId,
          targetType: crmLabelgings.targetType,
          targetId: crmLabelgings.targetId,
          source: crmLabelgings.source,
          confidence: crmLabelgings.confidence,
          createdAt: crmLabelgings.createdAt,
          label: crmLabels,
        })
        .from(crmLabelgings)
        .innerJoin(crmLabels, eq(crmLabelgings.labelId, crmLabels.id))
        .where(
          and(
            eq(crmLabelgings.accountId, accountId),
            eq(crmLabelgings.targetType, targetType),
            eq(crmLabelgings.targetId, targetId),
            isNull(crmLabels.archivedAt)
          )
        )

      return reply.send({ data: rows })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/labelgings', async (request, reply) => {
    try {
      const body = createLabelgingSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const label = await resolveLabel(body.data.accountId, body.data.labelId, body.data.slug)
      if (!label) {
        return reply.status(404).send({ error: 'NotFound', message: 'Label not found' })
      }

      const [created] = await db
        .insert(crmLabelgings)
        .values({
          accountId: body.data.accountId,
          labelId: label.id,
          targetType: body.data.targetType,
          targetId: body.data.targetId,
          source: body.data.source ?? 'manual',
          confidence: body.data.confidence,
          createdById: body.data.createdById,
        })
        .onConflictDoNothing()
        .returning()

      if (!created) {
        return reply.status(200).send({ duplicated: true, label })
      }

      await writeAuditEvent({
        accountId: created.accountId,
        entityType: body.data.targetType,
        entityId: body.data.targetId,
        action: 'label_added',
        after: { label, labelging: created },
      })

      return reply.status(201).send({ ...created, label })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.delete('/labelgings/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [existing] = await db
        .select()
        .from(crmLabelgings)
        .where(eq(crmLabelgings.id, id))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Labelging not found' })
      }

      await db.delete(crmLabelgings).where(eq(crmLabelgings.id, id))

      await writeAuditEvent({
        accountId: existing.accountId,
        entityType: existing.targetType,
        entityId: existing.targetId,
        action: 'label_removed',
        before: existing,
      })

      return reply.status(204).send()
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })
}
