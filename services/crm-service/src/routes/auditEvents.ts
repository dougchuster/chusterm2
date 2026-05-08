import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { and, desc, eq } from 'drizzle-orm'
import { db } from '../db/client.js'
import { auditEvents } from '../db/schema.js'

const listQuerySchema = z.object({
  accountId: z.coerce.number().int().positive(),
  entityType: z.string().max(100).optional(),
  entityId: z.string().max(100).optional(),
  action: z.string().max(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
})

export async function auditEventRoutes(app: FastifyInstance): Promise<void> {
  app.get('/audit-events', async (request, reply) => {
    try {
      const query = listQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const conditions = [eq(auditEvents.accountId, query.data.accountId)]

      if (query.data.entityType) {
        conditions.push(eq(auditEvents.entityType, query.data.entityType))
      }
      if (query.data.entityId) {
        conditions.push(eq(auditEvents.entityId, query.data.entityId))
      }
      if (query.data.action) {
        conditions.push(eq(auditEvents.action, query.data.action))
      }

      const data = await db
        .select()
        .from(auditEvents)
        .where(and(...conditions))
        .orderBy(desc(auditEvents.createdAt))
        .limit(query.data.limit)

      return reply.send({ data, total: data.length, page: 1, limit: query.data.limit })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })
}
