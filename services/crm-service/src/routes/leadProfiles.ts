import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq, and, desc, isNull, sql, inArray } from 'drizzle-orm'
import { db } from '../db/client.js'
import { crmLabelgings, crmLabels, leadProfiles, scoreComponents } from '../db/schema.js'
import { writeAuditEvent } from '../lib/audit.js'
import { leadScoringQueue } from '../queues/index.js'

const createSchema = z.object({
  // Deprecated: accepted for backwards compatibility but IGNORED — the tenant
  // is always derived from the verified JWT (request.auth.accountId).
  accountId: z.number().int().positive().optional(),
  chatwootContactId: z.number().int().positive(),
  fullName: z.string().min(1).max(255),
  phone: z.string().min(1).max(30),
  email: z.string().email().max(255),
  courseInterest: z.string().max(255).optional(),
  campusInterest: z.string().max(255).optional(),
  preferredShift: z.string().max(50).optional(),
  enrollmentUrgency: z.string().max(50).optional(),
  relationshipStatus: z.enum(['lead', 'customer']).optional(),
  lifecycleStage: z.string().max(100).optional(),
  ownerId: z.number().int().positive().nullable().optional(),
  ownerSource: z.string().max(50).optional(),
  stage: z.string().max(100).optional(),
  score: z.number().int().min(0).max(100).optional(),
  sourceChannel: z.string().max(100).optional(),
  utmSource: z.string().max(255).optional(),
  utmCampaign: z.string().max(255).optional(),
})

// CRM-H3: chatwootContactId and score are server-controlled — not client-writable.
const updateSchema = createSchema.partial().omit({ accountId: true, chatwootContactId: true, score: true })

const listQuerySchema = z.object({
  // Deprecated: accepted but IGNORED in favor of the token claim.
  accountId: z.coerce.number().int().positive().optional(),
  stage: z.string().optional(),
  relationshipStatus: z.enum(['lead', 'customer']).optional(),
  lifecycleStage: z.string().optional(),
  ownerId: z.coerce.number().int().positive().optional(),
  label: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
})

const accountQuerySchema = z.object({
  // Deprecated: accepted but IGNORED in favor of the token claim.
  accountId: z.coerce.number().int().positive().optional(),
})

const recomputeBodySchema = z.object({
  // Deprecated: accepted but IGNORED in favor of the token claim.
  accountId: z.number().int().positive().optional(),
})

async function targetIdsForLabel(accountId: number, labelSlug: string) {
  const rows = await db
    .select({ targetId: crmLabelgings.targetId })
    .from(crmLabelgings)
    .innerJoin(crmLabels, eq(crmLabelgings.labelId, crmLabels.id))
    .where(
      and(
        eq(crmLabelgings.accountId, accountId),
        eq(crmLabelgings.targetType, 'contact'),
        eq(crmLabels.slug, labelSlug),
        isNull(crmLabels.archivedAt)
      )
    )

  return rows.map((row) => row.targetId)
}

async function labelsForTargets(accountId: number, targetType: string, targetIds: string[]) {
  if (targetIds.length === 0) return new Map<string, Array<typeof crmLabels.$inferSelect>>()

  const rows = await db
    .select({
      targetId: crmLabelgings.targetId,
      label: crmLabels,
    })
    .from(crmLabelgings)
    .innerJoin(crmLabels, eq(crmLabelgings.labelId, crmLabels.id))
    .where(
      and(
        eq(crmLabelgings.accountId, accountId),
        eq(crmLabelgings.targetType, targetType),
        inArray(crmLabelgings.targetId, targetIds),
        isNull(crmLabels.archivedAt)
      )
    )

  const map = new Map<string, Array<typeof crmLabels.$inferSelect>>()
  for (const row of rows) {
    const labels = map.get(row.targetId) ?? []
    labels.push(row.label)
    map.set(row.targetId, labels)
  }
  return map
}

async function withLabels<T extends { id: string; accountId: number }>(records: T[], targetType = 'contact') {
  const accountId = records[0]?.accountId
  if (!accountId) return records.map((record) => ({ ...record, labels: [] }))

  const labelMap = await labelsForTargets(accountId, targetType, records.map((record) => record.id))
  return records.map((record) => ({ ...record, labels: labelMap.get(record.id) ?? [] }))
}

async function applySystemLabel(accountId: number, targetType: string, targetId: string, slug: string, source: string) {
  const [label] = await db
    .select({ id: crmLabels.id })
    .from(crmLabels)
    .where(and(eq(crmLabels.accountId, accountId), eq(crmLabels.slug, slug), isNull(crmLabels.archivedAt)))
    .limit(1)

  if (!label) return

  await db
    .insert(crmLabelgings)
    .values({
      accountId,
      labelId: label.id,
      targetType,
      targetId,
      source,
    })
    .onConflictDoNothing()
}

function lifecyclePatch(
  existing: typeof leadProfiles.$inferSelect,
  data: z.infer<typeof updateSchema>
) {
  const patch: Partial<typeof leadProfiles.$inferInsert> = { ...data, updatedAt: new Date() }

  if (data.lifecycleStage && data.lifecycleStage !== existing.lifecycleStage) {
    patch.lifecycleStageChangedAt = new Date()
  }

  if (data.relationshipStatus === 'customer' && existing.relationshipStatus !== 'customer') {
    patch.becameCustomerAt = new Date()
    patch.lifecycleStageChangedAt = patch.lifecycleStageChangedAt ?? new Date()
    patch.lifecycleStage = data.lifecycleStage ?? 'customer'
  }

  if (Object.prototype.hasOwnProperty.call(data, 'ownerId') && data.ownerId !== existing.ownerId) {
    patch.ownerAssignedAt = data.ownerId ? new Date() : null
    patch.ownerSource = data.ownerId ? (data.ownerSource ?? 'manual') : null
  }

  return patch
}

export async function leadProfileRoutes(app: FastifyInstance): Promise<void> {
  app.get('/lead-profiles', async (request, reply) => {
    try {
      const query = listQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const { stage, relationshipStatus, lifecycleStage, ownerId, label, page, limit } = query.data
      const accountId = request.auth.accountId
      const offset = (page - 1) * limit

      const conditions = [
        eq(leadProfiles.accountId, accountId),
        isNull(leadProfiles.deletedAt),
      ]
      if (stage) {
        conditions.push(eq(leadProfiles.stage, stage))
      }
      if (relationshipStatus) {
        conditions.push(eq(leadProfiles.relationshipStatus, relationshipStatus))
      }
      if (lifecycleStage) {
        conditions.push(eq(leadProfiles.lifecycleStage, lifecycleStage))
      }
      if (ownerId) {
        conditions.push(eq(leadProfiles.ownerId, ownerId))
      }
      if (label) {
        const targetIds = await targetIdsForLabel(accountId, label)
        if (targetIds.length === 0) {
          return reply.send({ data: [], total: 0, page, limit })
        }
        conditions.push(inArray(leadProfiles.id, targetIds))
      }

      const where = and(...conditions)

      const [data, countResult] = await Promise.all([
        db
          .select()
          .from(leadProfiles)
          .where(where)
          .limit(limit)
          .offset(offset),
        db
          .select({ count: sql<number>`cast(count(*) as int)` })
          .from(leadProfiles)
          .where(where),
      ])

      return reply.send({
        data: await withLabels(data),
        total: countResult[0]?.count ?? 0,
        page,
        limit,
      })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.get('/lead-profiles/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [profile] = await db
        .select()
        .from(leadProfiles)
        .where(and(eq(leadProfiles.id, id), eq(leadProfiles.accountId, request.auth.accountId), isNull(leadProfiles.deletedAt)))
        .limit(1)

      if (!profile) {
        return reply.status(404).send({ error: 'NotFound', message: 'Lead profile not found' })
      }

      const [enriched] = await withLabels([profile])
      return reply.send(enriched)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.get('/lead-profiles/:id/score', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }
      const query = accountQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const [profile] = await db
        .select()
        .from(leadProfiles)
        .where(and(eq(leadProfiles.id, id), eq(leadProfiles.accountId, request.auth.accountId), isNull(leadProfiles.deletedAt)))
        .limit(1)

      if (!profile) {
        return reply.status(404).send({ error: 'NotFound', message: 'Lead profile not found' })
      }

      const [latest] = await db
        .select()
        .from(scoreComponents)
        .where(eq(scoreComponents.contactId, id))
        .orderBy(desc(scoreComponents.computedAt))
        .limit(1)

      return reply.send({
        score: profile.score,
        component: latest ?? null,
      })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/lead-profiles/:id/recompute-score', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }
      const body = recomputeBodySchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [profile] = await db
        .select({ id: leadProfiles.id, accountId: leadProfiles.accountId })
        .from(leadProfiles)
        .where(and(eq(leadProfiles.id, id), eq(leadProfiles.accountId, request.auth.accountId), isNull(leadProfiles.deletedAt)))
        .limit(1)

      if (!profile) {
        return reply.status(404).send({ error: 'NotFound', message: 'Lead profile not found' })
      }

      await leadScoringQueue.add(
        'recompute',
        { contactId: profile.id, accountId: profile.accountId },
        { jobId: `manual-score:${profile.id}:${Date.now()}` }
      )

      return reply.status(202).send({ queued: true })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/lead-profiles', async (request, reply) => {
    try {
      const body = createSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [created] = await db
        .insert(leadProfiles)
        .values({
          ...body.data,
          accountId: request.auth.accountId,
          relationshipStatus: body.data.relationshipStatus ?? 'lead',
          lifecycleStage: body.data.lifecycleStage ?? body.data.stage ?? 'lead',
          becameLeadAt: body.data.relationshipStatus === 'customer' ? undefined : new Date(),
          becameCustomerAt: body.data.relationshipStatus === 'customer' ? new Date() : undefined,
          lifecycleStageChangedAt: new Date(),
          lastInteractionAt: new Date(),
          ownerAssignedAt: body.data.ownerId ? new Date() : undefined,
          ownerSource: body.data.ownerId ? (body.data.ownerSource ?? 'manual') : undefined,
        })
        .returning()

      await applySystemLabel(
        created.accountId,
        'contact',
        created.id,
        created.relationshipStatus === 'customer' ? 'rel.cliente' : 'rel.lead',
        'system'
      )
      if (!created.ownerId) {
        await applySystemLabel(created.accountId, 'contact', created.id, 'status.sem_responsavel', 'system')
      }

      await writeAuditEvent({
        accountId: created.accountId,
        entityType: 'lead_profile',
        entityId: created.id,
        action: 'created',
        after: created,
      })

      const [enriched] = await withLabels([created])
      return reply.status(201).send(enriched)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.patch('/lead-profiles/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const body = updateSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [existing] = await db
        .select()
        .from(leadProfiles)
        .where(and(eq(leadProfiles.id, id), eq(leadProfiles.accountId, request.auth.accountId), isNull(leadProfiles.deletedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Lead profile not found' })
      }

      const patch = lifecyclePatch(existing, body.data)

      const [updated] = await db
        .update(leadProfiles)
        .set(patch)
        .where(and(eq(leadProfiles.id, id), eq(leadProfiles.accountId, request.auth.accountId)))
        .returning()

      if (updated.relationshipStatus !== existing.relationshipStatus) {
        await applySystemLabel(
          updated.accountId,
          'contact',
          updated.id,
          updated.relationshipStatus === 'customer' ? 'rel.cliente' : 'rel.lead',
          'system'
        )
      }

      await writeAuditEvent({
        accountId: updated.accountId,
        entityType: 'lead_profile',
        entityId: updated.id,
        action:
          updated.relationshipStatus !== existing.relationshipStatus ||
          updated.lifecycleStage !== existing.lifecycleStage
            ? 'lifecycle_changed'
            : 'updated',
        before: existing,
        after: updated,
        metadata: {
          fromRelationshipStatus: existing.relationshipStatus,
          toRelationshipStatus: updated.relationshipStatus,
          fromLifecycleStage: existing.lifecycleStage,
          toLifecycleStage: updated.lifecycleStage,
        },
      })

      const [enriched] = await withLabels([updated])
      return reply.send(enriched)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.delete('/lead-profiles/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [existing] = await db
        .select()
        .from(leadProfiles)
        .where(and(eq(leadProfiles.id, id), eq(leadProfiles.accountId, request.auth.accountId), isNull(leadProfiles.deletedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Lead profile not found' })
      }

      await db
        .update(leadProfiles)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(leadProfiles.id, id), eq(leadProfiles.accountId, request.auth.accountId)))

      await writeAuditEvent({
        accountId: existing.accountId,
        entityType: 'lead_profile',
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
