import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { eq } from 'drizzle-orm'
import { db } from '../db/client.js'
import { skillRuns } from '../db/schema.js'
import { runIntentClassifier } from '../skills/intentClassifier.js'
import { runLeadScorer } from '../skills/leadScorer.js'
import { runNextBestAction } from '../skills/nextBestAction.js'
import { LlmUpstreamError } from '../llm/client.js'
import {
  buildMemorySummary,
  extractPrevidenciarioTriage,
  retrieveDrPaulaKnowledge,
  scorePrevidenciarioLead,
  type PrevidenciarioTriageSnapshot,
} from '../agents/drPaulaMatos.js'
import { requireServiceAuth, resolveAccountId } from '../plugins/auth.js'

// ─── Request schema ───────────────────────────────────────────────────────────

const RunSkillBodySchema = z.object({
  input: z.record(z.unknown()),
  // Deprecated for JWT callers: the tenant comes from the token claim. Still
  // accepted for trusted x-service-token (server-to-server) callers.
  accountId: z.number().int().positive().optional(),
  triggeredBy: z.string().optional(),
  conversationId: z.string().optional(),
  dealId: z.string().optional(),
  contactId: z.string().optional(),
})

// ─── Skill registry ───────────────────────────────────────────────────────────

async function dispatchSkill(slug: string, input: Record<string, unknown>): Promise<{
  output: Record<string, unknown>
  tokensIn?: number
  tokensOut?: number
}> {
  switch (slug) {
    case 'intent-classifier': {
      const parsed = z
        .object({
          conversationId: z.string(),
          messages: z.array(
            z.object({
              role: z.enum(['user', 'assistant']),
              content: z.string(),
            }),
          ),
          accountId: z.number().int().positive(),
        })
        .parse(input)
      const output = await runIntentClassifier(parsed)
      return { output: output as unknown as Record<string, unknown> }
    }

    case 'lead-scorer': {
      const parsed = z
        .object({
          contactId: z.string(),
          accountId: z.number().int().positive(),
          fitAttributes: z.record(z.unknown()).default({}),
          engagementEvents: z
            .array(
              z.object({
                type: z.string(),
                count: z.number().int().nonnegative(),
                lastAt: z.string(),
              }),
            )
            .default([]),
          intentSignals: z.array(z.string()).default([]),
        })
        .parse(input)
      const output = await runLeadScorer(parsed)
      return { output: output as unknown as Record<string, unknown> }
    }

    case 'previdenciario-triage': {
      const parsed = z
        .object({
          accountId: z.number().int().positive(),
          conversationId: z.string().optional(),
          latestMessage: z.string().optional(),
          messages: z
            .array(
              z.object({
                role: z.enum(['user', 'assistant']),
                content: z.string(),
              }),
            )
            .default([]),
          previousTriage: z.record(z.unknown()).optional(),
          messageCount: z.number().int().nonnegative().optional(),
        })
        .parse(input)

      const text = [
        ...parsed.messages.map((message) => `${message.role}: ${message.content}`),
        parsed.latestMessage ? `user: ${parsed.latestMessage}` : null,
      ]
        .filter(Boolean)
        .join('\n')

      const triage = extractPrevidenciarioTriage({
        text,
        previous: parsed.previousTriage as Partial<PrevidenciarioTriageSnapshot> | undefined,
      })
      const score = scorePrevidenciarioLead({
        triage,
        latestMessage: parsed.latestMessage ?? text,
        messageCount: parsed.messageCount ?? parsed.messages.length,
      })
      const ragSources = retrieveDrPaulaKnowledge(`${text}\n${buildMemorySummary(triage, score)}`)

      return {
        output: {
          triage,
          score,
          suggestedQuestions: triage.suggestedQuestions,
          ragSources: ragSources.map((source) => ({
            id: source.id,
            title: source.title,
            source: source.source,
            sourceUrl: source.sourceUrl,
          })),
        },
      }
    }

    case 'previdenciario-lead-scorer': {
      const parsed = z
        .object({
          accountId: z.number().int().positive(),
          latestMessage: z.string().optional(),
          messageCount: z.number().int().nonnegative().optional(),
          triage: z.record(z.unknown()),
        })
        .parse(input)

      const output = scorePrevidenciarioLead({
        triage: parsed.triage as unknown as PrevidenciarioTriageSnapshot,
        latestMessage: parsed.latestMessage,
        messageCount: parsed.messageCount,
      })
      return { output: output as unknown as Record<string, unknown> }
    }

    case 'next-best-action': {
      const parsed = z
        .object({
          contactId: z.string(),
          accountId: z.number().int().positive(),
          dealStage: z.string(),
          daysSinceLastActivity: z.number().int().nonnegative(),
          score: z.number().min(0).max(100),
          conversationSummary: z.string().optional(),
        })
        .parse(input)
      const output = await runNextBestAction(parsed)
      return { output: output as unknown as Record<string, unknown> }
    }

    default:
      throw new UnknownSkillError(`Unknown skill slug: ${slug}`)
  }
}

class UnknownSkillError extends Error {}

// ─── Route plugin ─────────────────────────────────────────────────────────────

const skillsRoute: FastifyPluginAsync = async (fastify) => {
  // ORC-H1: skill execution burns paid LLM tokens — authentication required.
  fastify.addHook('onRequest', requireServiceAuth)

  fastify.post<{ Params: { slug: string } }>('/skills/:slug/run', async (request, reply) => {
    const { slug } = request.params

    // Validate body
    const bodyResult = RunSkillBodySchema.safeParse(request.body)
    if (!bodyResult.success) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: bodyResult.error.issues.map((i) => i.message).join('; '),
      })
    }

    const { input, triggeredBy, conversationId, dealId, contactId } = bodyResult.data

    // Tenant comes from the JWT claim; only trusted x-service-token callers
    // may address an arbitrary tenant via the body field.
    const accountId = resolveAccountId(request, bodyResult.data.accountId)
    if (accountId === null) {
      return reply.status(400).send({
        error: 'VALIDATION_ERROR',
        message: 'accountId is required',
      })
    }

    // Merge accountId into input so skill validators can access it
    const skillInput: Record<string, unknown> = { ...input, accountId }

    // 1. Persist a pending run record
    let runId: string
    try {
      const [inserted] = await db
        .insert(skillRuns)
        .values({
          accountId,
          skillSlug: slug,
          skillVersion: '1.0.0',
          requestJson: skillInput,
          status: 'pending',
          triggeredBy: triggeredBy ?? null,
          conversationId: conversationId ?? null,
          dealId: dealId ?? null,
          contactId: contactId ?? null,
        })
        .returning({ id: skillRuns.id })
      runId = inserted.id
    } catch (err) {
      request.log.error({ err, slug }, 'Failed to insert skillRun record')
      return reply.status(500).send({
        error: 'DB_ERROR',
        message: 'Failed to create skill run record',
      })
    }

    // 2. Execute skill and measure latency
    const startedAt = Date.now()
    let output: Record<string, unknown>
    let tokensIn: number | undefined
    let tokensOut: number | undefined

    try {
      const result = await dispatchSkill(slug, skillInput)
      output = result.output
      tokensIn = result.tokensIn
      tokensOut = result.tokensOut
    } catch (err) {
      const latencyMs = Date.now() - startedAt
      const errorMessage = err instanceof Error ? err.message : String(err)
      const isValidation = err instanceof z.ZodError
      const isUnknown = err instanceof UnknownSkillError

      // Update run to failed
      try {
        await db
          .update(skillRuns)
          .set({ status: 'failed', latencyMs, errorMessage })
          .where(eq(skillRuns.id, runId))
      } catch (dbErr) {
        request.log.error({ dbErr, runId }, 'Failed to update skillRun to failed status')
      }

      if (isUnknown) {
        return reply.status(404).send({
          error: 'SKILL_NOT_FOUND',
          message: `Skill '${slug}' is not registered`,
        })
      }

      if (isValidation) {
        return reply.status(422).send({
          error: 'SKILL_INPUT_INVALID',
          message: (err as z.ZodError).issues.map((i) => i.message).join('; '),
        })
      }

      // LLM upstream failures surface as 502 (bad gateway), not a generic 500.
      if (err instanceof LlmUpstreamError) {
        request.log.error({ err, slug, runId }, 'LLM upstream request failed')
        return reply.status(502).send({
          error: 'LLM_UPSTREAM_ERROR',
          message: 'LLM provider request failed',
        })
      }

      request.log.error({ err, slug, runId }, 'Skill execution failed')
      return reply.status(500).send({
        error: 'SKILL_EXECUTION_ERROR',
        message: 'Skill execution failed',
      })
    }

    const latencyMs = Date.now() - startedAt

    // 3. Update run to completed
    try {
      await db
        .update(skillRuns)
        .set({
          status: 'completed',
          responseJson: output,
          latencyMs,
          tokensIn: tokensIn ?? null,
          tokensOut: tokensOut ?? null,
        })
        .where(eq(skillRuns.id, runId))
    } catch (dbErr) {
      // Non-fatal: the skill executed successfully, DB write failure should not
      // prevent the client from receiving the result. Log and continue.
      request.log.error({ dbErr, runId }, 'Failed to update skillRun to completed status')
    }

    return reply.status(200).send({ runId, output, latencyMs })
  })
}

export default skillsRoute
