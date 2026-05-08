import type { FastifyInstance } from 'fastify'
import { z } from 'zod'
import { eq, and, isNull, sql } from 'drizzle-orm'
import { db } from '../db/client.js'
import { pipelines, pipelineStages } from '../db/schema.js'

const createPipelineSchema = z.object({
  accountId: z.number().int().positive(),
  name: z.string().min(1).max(255),
  slug: z.string().min(1).max(100).regex(/^[a-z0-9-]+$/),
  isDefault: z.boolean().optional(),
  position: z.number().int().min(0).optional(),
})

const updatePipelineSchema = createPipelineSchema.partial().omit({ accountId: true })

const createStageSchema = z.object({
  accountId: z.number().int().positive(),
  name: z.string().min(1).max(255),
  position: z.number().int().min(0).optional(),
  probabilityPct: z.number().int().min(0).max(100).optional(),
  expectedDurationDays: z.number().int().positive().optional(),
  color: z.string().max(20).optional(),
})

const updateStageSchema = createStageSchema.partial().omit({ accountId: true })

const listQuerySchema = z.object({
  accountId: z.coerce.number().int().positive(),
})

export async function pipelineRoutes(app: FastifyInstance): Promise<void> {
  app.get('/pipelines', async (request, reply) => {
    try {
      const query = listQuerySchema.safeParse(request.query)
      if (!query.success) {
        return reply.status(400).send({ error: 'ValidationError', message: query.error.message })
      }

      const data = await db
        .select()
        .from(pipelines)
        .where(and(eq(pipelines.accountId, query.data.accountId), isNull(pipelines.archivedAt)))

      return reply.send({ data, total: data.length, page: 1, limit: data.length })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.get('/pipelines/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [pipeline] = await db
        .select()
        .from(pipelines)
        .where(eq(pipelines.id, id))
        .limit(1)

      if (!pipeline) {
        return reply.status(404).send({ error: 'NotFound', message: 'Pipeline not found' })
      }

      return reply.send(pipeline)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/pipelines', async (request, reply) => {
    try {
      const body = createPipelineSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [created] = await db.insert(pipelines).values(body.data).returning()

      return reply.status(201).send(created)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.patch('/pipelines/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const body = updatePipelineSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [existing] = await db
        .select({ id: pipelines.id })
        .from(pipelines)
        .where(eq(pipelines.id, id))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Pipeline not found' })
      }

      const [updated] = await db
        .update(pipelines)
        .set({ ...body.data, updatedAt: new Date() })
        .where(eq(pipelines.id, id))
        .returning()

      return reply.send(updated)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.delete('/pipelines/:id', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [existing] = await db
        .select({ id: pipelines.id })
        .from(pipelines)
        .where(eq(pipelines.id, id))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Pipeline not found' })
      }

      await db
        .update(pipelines)
        .set({ archivedAt: new Date(), updatedAt: new Date() })
        .where(eq(pipelines.id, id))

      return reply.status(204).send()
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  // ─── Nested: pipeline stages ──────────────────────────────────────────────

  app.get('/pipelines/:id/stages', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [pipeline] = await db
        .select({ id: pipelines.id })
        .from(pipelines)
        .where(eq(pipelines.id, id))
        .limit(1)

      if (!pipeline) {
        return reply.status(404).send({ error: 'NotFound', message: 'Pipeline not found' })
      }

      const data = await db
        .select()
        .from(pipelineStages)
        .where(and(eq(pipelineStages.pipelineId, id), isNull(pipelineStages.archivedAt)))

      return reply.send({ data, total: data.length, page: 1, limit: data.length })
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.post('/pipelines/:id/stages', async (request, reply) => {
    try {
      const { id } = request.params as { id: string }

      const [pipeline] = await db
        .select({ id: pipelines.id })
        .from(pipelines)
        .where(eq(pipelines.id, id))
        .limit(1)

      if (!pipeline) {
        return reply.status(404).send({ error: 'NotFound', message: 'Pipeline not found' })
      }

      const body = createStageSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [created] = await db
        .insert(pipelineStages)
        .values({ ...body.data, pipelineId: id })
        .returning()

      return reply.status(201).send(created)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.patch('/pipelines/:id/stages/:stageId', async (request, reply) => {
    try {
      const { id, stageId } = request.params as { id: string; stageId: string }

      const body = updateStageSchema.safeParse(request.body)
      if (!body.success) {
        return reply.status(400).send({ error: 'ValidationError', message: body.error.message })
      }

      const [existing] = await db
        .select({ id: pipelineStages.id })
        .from(pipelineStages)
        .where(and(eq(pipelineStages.id, stageId), eq(pipelineStages.pipelineId, id)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Stage not found' })
      }

      const [updated] = await db
        .update(pipelineStages)
        .set({ ...body.data, updatedAt: new Date() })
        .where(eq(pipelineStages.id, stageId))
        .returning()

      return reply.send(updated)
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })

  app.delete('/pipelines/:id/stages/:stageId', async (request, reply) => {
    try {
      const { id, stageId } = request.params as { id: string; stageId: string }

      const [existing] = await db
        .select({ id: pipelineStages.id })
        .from(pipelineStages)
        .where(and(eq(pipelineStages.id, stageId), eq(pipelineStages.pipelineId, id)))
        .limit(1)

      if (!existing) {
        return reply.status(404).send({ error: 'NotFound', message: 'Stage not found' })
      }

      await db
        .update(pipelineStages)
        .set({ archivedAt: new Date(), updatedAt: new Date() })
        .where(eq(pipelineStages.id, stageId))

      return reply.status(204).send()
    } catch (err) {
      app.log.error(err)
      return reply.status(500).send({ error: 'InternalError', message: 'Unexpected error' })
    }
  })
}
