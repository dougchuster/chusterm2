import type { FastifyInstance } from 'fastify'
import { healthRoutes } from './health.js'
import { leadProfileRoutes } from './leadProfiles.js'
import { dealRoutes } from './deals.js'
import { pipelineRoutes } from './pipelines.js'
import { activityRoutes } from './activities.js'
import { lossReasonRoutes } from './lossReasons.js'
import { auditEventRoutes } from './auditEvents.js'
import { labelRoutes } from './labels.js'

export async function registerRoutes(app: FastifyInstance): Promise<void> {
  await app.register(healthRoutes)
  await app.register(leadProfileRoutes)
  await app.register(dealRoutes)
  await app.register(pipelineRoutes)
  await app.register(activityRoutes)
  await app.register(lossReasonRoutes)
  await app.register(auditEventRoutes)
  await app.register(labelRoutes)
}
