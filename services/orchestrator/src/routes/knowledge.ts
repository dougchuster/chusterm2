import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { eq, and, ilike, or } from 'drizzle-orm'
import { db } from '../db/client.js'
import { knowledgeCollections, knowledgeArticles } from '../db/schema.js'

// ─── Collections ──────────────────────────────────────────────────────────────

const CreateCollectionSchema = z.object({
  accountId: z.number().int().positive(),
  name: z.string().min(1).max(255),
  description: z.string().default(''),
  scope: z.array(z.string()).default([]),
})

// ─── Articles ─────────────────────────────────────────────────────────────────

const CreateArticleSchema = z.object({
  accountId: z.number().int().positive(),
  collectionId: z.string().uuid(),
  title: z.string().min(1).max(500),
  content: z.string().min(1),
  tags: z.array(z.string()).default([]),
  isPublished: z.boolean().default(false),
})

// ─── Route plugin ─────────────────────────────────────────────────────────────

const knowledgeRoute: FastifyPluginAsync = async (fastify) => {
  // GET /knowledge/collections?accountId=
  fastify.get('/knowledge/collections', async (request, reply) => {
    const queryResult = z
      .object({ accountId: z.coerce.number().int().positive() })
      .safeParse(request.query)

    if (!queryResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId is required and must be a positive integer',
      })
    }

    try {
      const collections = await db
        .select()
        .from(knowledgeCollections)
        .where(eq(knowledgeCollections.accountId, queryResult.data.accountId))
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

    try {
      const [created] = await db
        .insert(knowledgeCollections)
        .values(bodyResult.data)
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
        accountId: z.coerce.number().int().positive(),
        collectionId: z.string().uuid().optional(),
        q: z.string().optional(),
      })
      .safeParse(request.query)

    if (!queryResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId is required and must be a positive integer',
      })
    }

    const { accountId, collectionId, q } = queryResult.data

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

    // Verify the collection exists and belongs to the same accountId
    try {
      const collection = await db
        .select({ id: knowledgeCollections.id, accountId: knowledgeCollections.accountId })
        .from(knowledgeCollections)
        .where(
          and(
            eq(knowledgeCollections.id, bodyResult.data.collectionId),
            eq(knowledgeCollections.accountId, bodyResult.data.accountId),
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
        .values(bodyResult.data)
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

    try {
      const [article] = await db
        .select()
        .from(knowledgeArticles)
        .where(eq(knowledgeArticles.id, id))
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
