import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, eq, isNull, sql, inArray } from 'drizzle-orm'
import { db } from '../db/client.js'
import { crmLabelgings, crmLabels, deals, leadProfiles, lossReasons, pipelineStages } from '../db/schema.js'
import { writeAuditEvent } from '../lib/audit.js'
import { leadScoringQueue } from '../queues/index.js'

const createSchema = z.object({
  // Deprecated: accepted for backwards compatibility but IGNORED — the tenant
  // is always derived from the verified JWT (request.auth.accountId).
  accountId: z.number().int().positive().optional(),
  leadProfileId: z.string().uuid(),
  pipelineId: z.string().uuid().optional(),
  stageId: z.string().uuid().optional(),
  title: z.string().min(1).max(255),
  stage: z.string().max(100).optional(),
  probabilityPct: z.number().int().min(0).max(100).optional(),
  score: z.number().int().min(0).optional(),
  ownerId: z.number().int().positive().optional(),
  courseId: z.string().uuid().optional(),
  expectedRevenue: z.number().optional(),
  lossReasonId: z.string().uuid().optional(),
  lostReasonNote: z.string().max(500).optional(),
})

// CRM-H3: score and leadProfileId are server-controlled — not client-writable.
const updateSchema = createSchema.partial().omit({ accountId: true, score: true, leadProfileId: true })
type DealCreatePayload = z.infer<typeof createSchema> & { accountId: number }
type DealUpdatePayload = z.infer<typeof updateSchema> & { accountId: number }

const listQuerySchema = z.object({
  // Deprecated: accepted but IGNORED in favor of the token claim.
  accountId: z.coerce.number().int().positive().optional(),
  stage: z.string().optional(),
  pipelineId: z.string().uuid().optional(),
  stageId: z.string().uuid().optional(),
  lossReasonId: z.string().uuid().optional(),
  ownerId: z.coerce.number().int().positive().optional(),
  relationshipStatus: z.enum(['lead', 'customer']).optional(),
  lifecycleStage: z.string().optional(),
  label: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
})

const isClosedStage = (stage?: string) => {
  const normalized = String(stage ?? '').toLowerCase()
  return ['ganho', 'won', 'perdido', 'lost'].includes(normalized)
}

async function hydrateStage<T extends DealCreatePayload | DealUpdatePayload>(payload: T): Promise<T | null> {
  if (!payload.stageId) return payload

  const [stage] = await db
    .select()
    .from(pipelineStages)
    .where(and(eq(pipelineStages.id, payload.stageId), eq(pipelineStages.accountId, payload.accountId)))
    .limit(1)

  if (!stage) return null

  return {
    ...payload,
    pipelineId: stage.pipelineId,
    stage: stage.name,
    probabilityPct: stage.probabilityPct,
  } as T
}

async function hasValidLossReason(accountId: number, lossReasonId?: string) {
  if (!lossReasonId) return true

  const [reason] = await db
    .select({ id: lossReasons.id })
    .from(lossReasons)
    .where(and(eq(lossReasons.id, lossReasonId), eq(lossReasons.accountId, accountId), isNull(lossReasons.archivedAt)))
    .limit(1)

  return Boolean(reason)
}

async function contactIdsForLabel(accountId: number, labelSlug: string) {
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

async function labelsForContacts(accountId: number, contactIds: string[]) {
  if (contactIds.length === 0) return new Map<string, Array<typeof crmLabels.$inferSelect>>()

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
        eq(crmLabelgings.targetType, 'contact'),
        inArray(crmLabelgings.targetId, contactIds),
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

async function withLeadContext<T extends typeof deals.$inferSelect>(records: T[]) {
  const accountId = records[0]?.accountId
  if (!accountId || records.length === 0) return records.map((record) => ({ ...record, leadProfile: null }))

  const contactIds = Array.from(new Set(records.map((record) => record.leadProfileId)))
  const profiles = await db
    .select()
    .from(leadProfiles)
    .where(and(eq(leadProfiles.accountId, accountId), inArray(leadProfiles.id, contactIds), isNull(leadProfiles.deletedAt)))

  const labelMap = await labelsForContacts(accountId, contactIds)
  const profileMap = new Map(
    profiles.map((profile) => [
      profile.id,
      {
        ...profile,
        labels: labelMap.get(profile.id) ?? [],
      },
    ])
  )

  return records.map((record) => ({
    ...record,
    effectiveOwnerId: record.ownerId ?? profileMap.get(record.leadProfileId)?.ownerId ?? null,
    leadProfile: profileMap.get(record.leadProfileId) ?? null,
  }))
}

export async function dealRoutes(app: FastifyInstance): Promise<void> {
  app.get('/deals', async (request, reply) => {
    try {
      const query = listQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const {
        stage,
        pipelineId,
        stageId,
        lossReasonId,
        ownerId,
        relationshipStatus,
        lifecycleStage,
        label,
        page,
        limit,
      } = query.data
      const accountId = request.auth.accountId
      const offset = (page - 1) * limit

      const conditions = [
        eq(deals.accountId, accountId),
        isNull(deals.deletedAt),
      ]
      if (stage) conditions.push(eq(deals.stage, stage))
      if (pipelineId) conditions.push(eq(deals.pipelineId, pipelineId))
      if (stageId) conditions.push(eq(deals.stageId, stageId))
      if (lossReasonId) conditions.push(eq(deals.lossReasonId, lossReasonId))
      if (ownerId) conditions.push(eq(deals.ownerId, ownerId))
      if (relationshipStatus || lifecycleStage || label) {
        const profileConditions = [eq(leadProfiles.accountId, accountId), isNull(leadProfiles.deletedAt)]
        if (relationshipStatus) profileConditions.push(eq(leadProfiles.relationshipStatus, relationshipStatus))
        if (lifecycleStage) profileConditions.push(eq(leadProfiles.lifecycleStage, lifecycleStage))
        if (label) {
          const contactIds = await contactIdsForLabel(accountId, label)
          if (contactIds.length === 0) {
            return reply.send({ data: [], total: 0, page, limit })
          }
          profileConditions.push(inArray(leadProfiles.id, contactIds))
        }

        const matchingProfiles = await db
          .select({ id: leadProfiles.id })
          .from(leadProfiles)
          .where(and(...profileConditions))

        const ids = matchingProfiles.map((profile) => profile.id)
        if (ids.length === 0) {
          return reply.send({ data: [], total: 0, page, limit })
        }
        conditions.push(inArray(deals.leadProfileId, ids))
      }

      const where = and(...conditions)

      const [data, countResult] = await Promise.all([
        db.select().from(deals).where(where).limit(limit).offset(offset),
        db.select({ count: sql<number>`cast(count(*) as int)` }).from(deals).where(where),
      ])

      return reply.send({
        data: await withLeadContext(data),
        total: countResult[0]?.count ?? 0,
        page,
        limit,
      })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.get('/deals/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [deal] = await db
        .select()
        .from(deals)
        .where(and(eq(deals.id, id), eq(deals.accountId, request.auth.accountId), isNull(deals.deletedAt)))
        .limit(1)

      if (!deal) {
        return reply.status(404).send({ error: 'NotFound', message: 'Deal not found' })
      }

      const [enriched] = await withLeadContext([deal])
      return reply.send(enriched)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/deals', async (request, reply) => {
    try {
      const body = createSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const hydratedPayload = await hydrateStage({ ...body.data, accountId: request.auth.accountId })
      if (!hydratedPayload) {
        return reply.status(400).send({ error: 'ValidationError', message: 'Stage does not belong to account' })
      }

      const lossReasonIsValid = await hasValidLossReason(
        hydratedPayload.accountId,
        hydratedPayload.lossReasonId
      )
      if (!lossReasonIsValid) {
        return reply.status(400).send({ error: 'ValidationError', message: 'Loss reason does not belong to account' })
      }

      const [created] = await db
        .insert(deals)
        .values({
          ...hydratedPayload,
          closedAt: isClosedStage(hydratedPayload.stage) || hydratedPayload.lossReasonId ? new Date() : undefined,
        })
        .returning()

      await writeAuditEvent({
        accountId: created.accountId,
        entityType: 'deal',
        entityId: created.id,
        action: 'created',
        after: created,
      })

      const [enriched] = await withLeadContext([created])
      return reply.status(201).send(enriched)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.patch('/deals/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const body = updateSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [existing] = await db
        .select()
        .from(deals)
        .where(and(eq(deals.id, id), eq(deals.accountId, request.auth.accountId), isNull(deals.deletedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Deal not found' })
      }

      const hydratedPayload = await hydrateStage({
        ...body.data,
        accountId: existing.accountId,
      })
      if (!hydratedPayload) {
        return reply.status(400).send({ error: 'ValidationError', message: 'Stage does not belong to account' })
      }

      const lossReasonIsValid = await hasValidLossReason(
        existing.accountId,
        hydratedPayload.lossReasonId
      )
      if (!lossReasonIsValid) {
        return reply.status(400).send({ error: 'ValidationError', message: 'Loss reason does not belong to account' })
      }

      const { accountId: _accountId, ...payload } = hydratedPayload
      const nextStage = payload.stage ?? existing.stage
      const stageChanged = Boolean(nextStage && nextStage !== existing.stage)
      const shouldClose = (isClosedStage(nextStage) || Boolean(payload.lossReasonId)) && !existing.closedAt

      const [updated] = await db
        .update(deals)
        .set({
          ...payload,
          ...(shouldClose ? { closedAt: new Date() } : {}),
          updatedAt: new Date(),
        })
        .where(and(eq(deals.id, id), eq(deals.accountId, request.auth.accountId)))
        .returning()

      if (stageChanged) {
        await leadScoringQueue.add(
          'recompute',
          { contactId: existing.leadProfileId, accountId: existing.accountId },
          { jobId: `stage-changed:${id}:${Date.now()}` }
        )
        app.log.info({ dealId: id, from: existing.stage, to: updated.stage }, 'deal.stage_changed')
      }

      await writeAuditEvent({
        accountId: updated.accountId,
        entityType: 'deal',
        entityId: updated.id,
        action: stageChanged ? 'stage_changed' : 'updated',
        before: existing,
        after: updated,
        metadata: stageChanged ? { from: existing.stage, to: updated.stage } : {},
      })

      const [enriched] = await withLeadContext([updated])
      return reply.send(enriched)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.delete('/deals/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [existing] = await db
        .select()
        .from(deals)
        .where(and(eq(deals.id, id), eq(deals.accountId, request.auth.accountId), isNull(deals.deletedAt)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Deal not found' })
      }

      await db
        .update(deals)
        .set({ deletedAt: new Date(), updatedAt: new Date() })
        .where(and(eq(deals.id, id), eq(deals.accountId, request.auth.accountId)))

      await writeAuditEvent({
        accountId: existing.accountId,
        entityType: 'deal',
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
