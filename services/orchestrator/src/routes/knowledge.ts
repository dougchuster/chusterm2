import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { eq, and, ilike, or } from 'drizzle-orm'
import { db } from '../db/client.js'
import { knowledgeCollections, knowledgeArticles } from '../db/schema.js'
import { requireServiceAuth, resolveAccountId } from '../plugins/auth.js'

// ─── Collections ──────────────────────────────────────────────────────────────

const CreateCollectionSchema = z.object({
  // Deprecated for JWT callers: the tenant comes from the token claim. Still
  // accepted for trusted x-service-token (server-to-server) callers.
  accountId: z.number().int().positive().optional(),
  name: z.string().min(1).max(255),
  description: z.string().default(''),
  scope: z.array(z.string()).default([]),
})

// ─── Articles ─────────────────────────────────────────────────────────────────

const CreateArticleSchema = z.object({
  // Deprecated for JWT callers: the tenant comes from the token claim.
  accountId: z.number().int().positive().optional(),
  collectionId: z.string().uuid(),
  title: z.string().min(1).max(500),
  content: z.string().min(1),
  tags: z.array(z.string()).default([]),
  isPublished: z.boolean().default(false),
})

// ─── Route plugin ─────────────────────────────────────────────────────────────

const knowledgeRoute: FastifyPluginAsync = async (fastify) => {
  // ORC-H1: knowledge content is later injected into LLM prompts — writes must
  // be authenticated, and JWT callers are always scoped to their own tenant.
  fastify.addHook('onRequest', requireServiceAuth)

  // GET /knowledge/collections?accountId=
  fastify.get('/knowledge/collections', async (request, reply) => {
    const queryResult = z
      .object({ accountId: z.coerce.number().int().positive().optional() })
      .safeParse(request.query)

    if (!queryResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId must be a positive integer',
      })
    }

    const accountId = resolveAccountId(request, queryResult.data.accountId)
    if (accountId === null) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId is required',
      })
    }

    try {
      const collections = await db
        .select()
        .from(knowledgeCollections)
        .where(eq(knowledgeCollections.accountId, accountId))
        .orderBy(knowledgeCollections.createdAt)

      return reply.status(200).send({ data: collections })
    } catch (err) {
      request.log.error({ err }, 'Failed to fetch knowledge collections')
      return reply.status(500).send({
        error: 'DB_ERROR',
        message: 'Failed to fetch collections',
      })
    }
  })

  // POST /knowledge/collections
  fastify.post('/knowledge/collections', async (request, reply) => {
    const bodyResult = CreateCollectionSchema.safeParse(request.body)
    if (!bodyResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: bodyResult.error.issues.map((i) => i.message).join('; '),
      })
    }

    const accountId = resolveAccountId(request, bodyResult.data.accountId)
    if (accountId === null) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId is required',
      })
    }

    try {
      const [created] = await db
        .insert(knowledgeCollections)
        .values({ ...bodyResult.data, accountId })
        .returning()

      return reply.status(201).send({ data: created })
    } catch (err) {
      request.log.error({ err }, 'Failed to create knowledge collection')
      return reply.status(500).send({
        error: 'DB_ERROR',
        message: 'Failed to create collection',
      })
    }
  })

  // GET /knowledge/articles?accountId=&collectionId=&q=
  fastify.get('/knowledge/articles', async (request, reply) => {
    const queryResult = z
      .object({
        accountId: z.coerce.number().int().positive().optional(),
        collectionId: z.string().uuid().optional(),
        q: z.string().optional(),
      })
      .safeParse(request.query)

    if (!queryResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId must be a positive integer',
      })
    }

    const accountId = resolveAccountId(request, queryResult.data.accountId)
    if (accountId === null) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId is required',
      })
    }

    const { collectionId, q } = queryResult.data

    try {
      const conditions = [eq(knowledgeArticles.accountId, accountId)]

      if (collectionId) {
        conditions.push(eq(knowledgeArticles.collectionId, collectionId))
      }

      if (q && q.trim().length > 0) {
        const pattern = `%${q.trim()}%`
        conditions.push(
          or(
            ilike(knowledgeArticles.title, pattern),
            ilike(knowledgeArticles.content, pattern),
          )!,
        )
      }

      const articles = await db
        .select()
        .from(knowledgeArticles)
        .where(and(...conditions))
        .orderBy(knowledgeArticles.createdAt)

      return reply.status(200).send({ data: articles })
    } catch (err) {
      request.log.error({ err }, 'Failed to fetch knowledge articles')
      return reply.status(500).send({
        error: 'DB_ERROR',
        message: 'Failed to fetch articles',
      })
    }
  })

  // POST /knowledge/articles
  fastify.post('/knowledge/articles', async (request, reply) => {
    const bodyResult = CreateArticleSchema.safeParse(request.body)
    if (!bodyResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: bodyResult.error.issues.map((i) => i.message).join('; '),
      })
    }

    const accountId = resolveAccountId(request, bodyResult.data.accountId)
    if (accountId === null) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId is required',
      })
    }

    // Verify the collection exists and belongs to the same accountId
    try {
      const collection = await db
        .select({ id: knowledgeCollections.id, accountId: knowledgeCollections.accountId })
        .from(knowledgeCollections)
        .where(
          and(
            eq(knowledgeCollections.id, bodyResult.data.collectionId),
            eq(knowledgeCollections.accountId, accountId),
          ),
        )
        .limit(1)

      if (collection.length === 0) {
        return reply.status(404).send({
          error: 'COLLECTION_NOT_FOUND',
          message: 'Collection not found or does not belong to this account',
        })
      }
    } catch (err) {
      request.log.error({ err }, 'Failed to verify collection ownership')
      return reply.status(500).send({
        error: 'DB_ERROR',
        message: 'Failed to verify collection',
      })
    }

    try {
      const [created] = await db
        .insert(knowledgeArticles)
        .values({ ...bodyResult.data, accountId })
        .returning()

      return reply.status(201).send({ data: created })
    } catch (err) {
      request.log.error({ err }, 'Failed to create knowledge article')
      return reply.status(500).send({
        error: 'DB_ERROR',
        message: 'Failed to create article',
      })
    }
  })

  // GET /knowledge/articles/:id
  fastify.get<{ Params: { id: string } }>('/knowledge/articles/:id', async (request, reply) => {
    const { id } = request.params

    const idResult = z.string().uuid().safeParse(id)
    if (!idResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'Article id must be a valid UUID',
      })
    }

    // JWT callers are scoped to their own tenant; trusted x-service-token
    // callers (request.auth undefined) may read any tenant's article.
    const tokenAccountId = request.auth?.accountId

    try {
      const [article] = await db
        .select()
        .from(knowledgeArticles)
        .where(
          tokenAccountId !== undefined
            ? and(eq(knowledgeArticles.id, id), eq(knowledgeArticles.accountId, tokenAccountId))
            : eq(knowledgeArticles.id, id),
        )
        .limit(1)

      if (!article) {
        return reply.status(404).send({
          error: 'ARTICLE_NOT_FOUND',
          message: 'Article not found',
        })
      }

      return reply.status(200).send({ data: article })
    } catch (err) {
      request.log.error({ err }, 'Failed to fetch knowledge article')
      return reply.status(500).send({
        error: 'DB_ERROR',
        message: 'Failed to fetch article',
      })
    }
  })
}

export default knowledgeRoute
