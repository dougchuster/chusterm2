import { Worker, Job } from 'bullmq'
import { and, eq, isNull, sql } from 'drizzle-orm'
import { db } from '../db/client.js'
import { activities, deals, leadProfiles, scoreComponents, scoreModels } from '../db/schema.js'
import { redisConnection } from '../lib/redis.js'

interface LeadScoringJobData {
  contactId: string
  accountId: number
}

function clamp(value: number, max: number) {
  return Math.max(0, Math.min(max, value))
}

function scoreFit(profile: typeof leadProfiles.$inferSelect) {
  let score = 0
  const factors: Record<string, number | boolean | string | null> = {}

  if (profile.courseInterest) {
    score += 14
    factors.courseInterest = profile.courseInterest
  }
  if (profile.campusInterest) {
    score += 8
    factors.campusInterest = profile.campusInterest
  }
  if (profile.preferredShift) {
    score += 5
    factors.preferredShift = profile.preferredShift
  }
  if (profile.phone) {
    score += 6
    factors.hasPhone = true
  }
  if (profile.email) {
    score += 4
    factors.hasEmail = true
  }
  if (profile.sourceChannel) {
    score += 3
    factors.sourceChannel = profile.sourceChannel
  }

  return { score: clamp(score, 40), factors }
}

async function scoreEngagement(contactId: string, accountId: number) {
  const [activityStats] = await db
    .select({
      total: sql<number>`cast(count(*) as int)`,
      completed: sql<number>`cast(count(*) filter (where ${activities.completedAt} is not null) as int)`,
      overdue: sql<number>`cast(count(*) filter (where ${activities.completedAt} is null and ${activities.dueAt} < now()) as int)`,
    })
    .from(activities)
    .where(and(eq(activities.accountId, accountId), eq(activities.leadProfileId, contactId), isNull(activities.deletedAt)))

  const [dealStats] = await db
    .select({
      total: sql<number>`cast(count(*) as int)`,
      active: sql<number>`cast(count(*) filter (where ${deals.closedAt} is null) as int)`,
    })
    .from(deals)
    .where(and(eq(deals.accountId, accountId), eq(deals.leadProfileId, contactId), isNull(deals.deletedAt)))

  const completed = activityStats?.completed ?? 0
  const overdue = activityStats?.overdue ?? 0
  const activeDeals = dealStats?.active ?? 0
  const score = clamp((completed * 7) + (activeDeals * 10) - (overdue * 5), 35)

  return {
    score,
    factors: {
      activities: activityStats?.total ?? 0,
      completedActivities: completed,
      overdueActivities: overdue,
      activeDeals,
    },
  }
}

async function scoreIntent(profile: typeof leadProfiles.$inferSelect) {
  const profileDeals = await db
    .select()
    .from(deals)
    .where(and(eq(deals.accountId, profile.accountId), eq(deals.leadProfileId, profile.id), isNull(deals.deletedAt)))

  const highestProbability = profileDeals.reduce(
    (max, deal) => Math.max(max, deal.probabilityPct ?? 0),
    0
  )
  const hasRevenue = profileDeals.some(deal => Number(deal.expectedRevenue ?? 0) > 0)
  const urgency = String(profile.enrollmentUrgency ?? '').toLowerCase()

  let score = Math.round(highestProbability * 0.14)
  if (hasRevenue) score += 4
  if (['alta', 'high', 'urgente', 'urgent'].includes(urgency)) score += 7
  if (profileDeals.some(deal => ['proposta', 'negociacao'].includes(String(deal.stage).toLowerCase()))) {
    score += 4
  }

  return {
    score: clamp(score, 25),
    factors: {
      highestProbability,
      hasRevenue,
      enrollmentUrgency: profile.enrollmentUrgency,
      openDeals: profileDeals.filter(deal => !deal.closedAt).length,
    },
  }
}

async function ensureActiveModel(accountId: number) {
  const [existing] = await db
    .select()
    .from(scoreModels)
    .where(eq(scoreModels.accountId, accountId))
    .limit(1)

  if (existing) return existing

  const [created] = await db
    .insert(scoreModels)
    .values({
      accountId,
      name: 'Lead Scoring v2',
      version: '2.0',
      weightsJson: { fit: 40, engagement: 35, intent: 25 },
      status: 'active',
    })
    .returning()

  return created
}

async function processLeadScoring(job: Job<LeadScoringJobData>): Promise<void> {
  const { contactId, accountId } = job.data

  const [profile] = await db
    .select()
    .from(leadProfiles)
    .where(and(eq(leadProfiles.id, contactId), eq(leadProfiles.accountId, accountId), isNull(leadProfiles.deletedAt)))
    .limit(1)

  if (!profile) {
    throw new Error(`LeadProfile not found: ${contactId}`)
  }

  const model = await ensureActiveModel(accountId)
  const fit = scoreFit(profile)
  const engagement = await scoreEngagement(contactId, accountId)
  const intent = await scoreIntent(profile)
  const total = clamp(fit.score + engagement.score + intent.score, 100)

  await db.insert(scoreComponents).values({
    contactId,
    modelId: model.id,
    fit: fit.score,
    engagement: engagement.score,
    intent: intent.score,
    total,
    factorsJson: {
      fit: fit.factors,
      engagement: engagement.factors,
      intent: intent.factors,
    },
    computedAt: new Date(),
  })

  await db
    .update(leadProfiles)
    .set({ score: total, updatedAt: new Date() })
    .where(eq(leadProfiles.id, contactId))

  await db
    .update(deals)
    .set({ score: total, updatedAt: new Date() })
    .where(and(eq(deals.accountId, accountId), eq(deals.leadProfileId, contactId), isNull(deals.deletedAt)))
}

type WorkerLogger = {
  error: (obj: unknown, msg?: string) => void
}

export function startLeadScoringWorker(logger?: WorkerLogger): Worker<LeadScoringJobData> {
  const logError = (obj: unknown, msg: string) => {
    if (logger) logger.error(obj, msg)
    else console.error(msg, obj)
  }

  const worker = new Worker<LeadScoringJobData>(
    'lead-scoring',
    processLeadScoring,
    {
      connection: redisConnection,
      concurrency: 5,
      // Bound job throughput so a scoring burst cannot starve the DB.
      limiter: { max: 50, duration: 10_000 },
    }
  )

  worker.on('failed', (job, err) => {
    logError({ err: err.message, jobId: job?.id }, 'lead-scoring job failed')
  })

  // CRM-M4: without an 'error' listener, Redis connection errors are re-emitted
  // as unhandled EventEmitter 'error' events and crash the process.
  worker.on('error', (err) => {
    logError({ err: err.message }, 'lead-scoring worker error')
  })

  return worker
}
