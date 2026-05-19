import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { llm, LLM_MAX_TOKENS, LLM_MODEL, isLlmConfigured } from '../llm/client.js'
import {
  DR_PAULA_MATOS_SLUG,
  buildDrPaulaFallbackResponse,
  buildDrPaulaMessages,
  buildMemorySummary,
  buildPrivateTriageNote,
  extractPrevidenciarioTriage,
  retrieveDrPaulaKnowledge,
  scorePrevidenciarioLead,
  type AgentMessage,
  type PrevidenciarioTriageSnapshot,
} from '../agents/drPaulaMatos.js'
import {
  getAgentConversationMemory,
  upsertAgentConversationMemory,
} from '../agents/memory.js'

const CHATWOOT_BASE_URL = (process.env.CHATWOOT_BASE_URL ?? 'http://core:3000').replace(/\/$/, '')
const CHATWOOT_BOT_TOKEN = process.env.CHATWOOT_BOT_TOKEN ?? ''

const AgentBotPayloadSchema = z.object({
  event: z.string(),
  content: z.string().nullish(),
  message_type: z.string().optional(),
  content_type: z.string().optional(),
  conversation: z.object({
    id: z.number(),
    account_id: z.number(),
  }),
  sender: z
    .object({
      name: z.string().optional(),
      type: z.string().optional(),
    })
    .optional(),
})

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
}

function asStoredTriage(value: unknown): Partial<PrevidenciarioTriageSnapshot> | null {
  return value && typeof value === 'object'
    ? (value as Partial<PrevidenciarioTriageSnapshot>)
    : null
}

async function fetchConversationHistory(
  accountId: number,
  conversationId: number,
): Promise<ChatMessage[]> {
  if (!CHATWOOT_BOT_TOKEN) return []
  try {
    const url = `${CHATWOOT_BASE_URL}/api/v1/accounts/${accountId}/conversations/${conversationId}/messages`
    const resp = await fetch(url, {
      headers: { api_access_token: CHATWOOT_BOT_TOKEN },
      signal: AbortSignal.timeout(10_000),
    })
    if (!resp.ok) return []

    const data = (await resp.json()) as { payload?: unknown[] }
    const messages = data?.payload ?? []

    return (messages as Record<string, unknown>[])
      .filter(
        (m) =>
          (m.message_type === 0 || m.message_type === 1) &&
          m.content_type === 'text' &&
          m.private !== true &&
          typeof m.content === 'string' &&
          (m.content as string).trim().length > 0,
      )
      .slice(-12)
      .map((m) => ({
        role: m.message_type === 0 ? ('user' as const) : ('assistant' as const),
        content: (m.content as string).trim(),
      }))
  } catch {
    return []
  }
}

async function postReply(
  accountId: number,
  conversationId: number,
  content: string,
  options: { private?: boolean } = {},
): Promise<void> {
  const url = `${CHATWOOT_BASE_URL}/api/v1/accounts/${accountId}/conversations/${conversationId}/messages`
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      api_access_token: CHATWOOT_BOT_TOKEN,
    },
    body: JSON.stringify({
      content,
      message_type: 'outgoing',
      content_type: 'text',
      private: options.private ?? false,
    }),
    signal: AbortSignal.timeout(15_000),
  })

  if (!response.ok) {
    throw new Error(`Chatwoot post failed with status ${response.status}`)
  }
}

const agentRoute: FastifyPluginAsync = async (fastify) => {
  fastify.post('/agent/message', async (request, reply) => {
    const result = AgentBotPayloadSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: 'INVALID_PAYLOAD' })
    }

    const payload = result.data

    if (payload.event !== 'message_created' || payload.message_type !== 'incoming') {
      return reply.status(200).send({ ok: true, skipped: true })
    }

    const userMessage = payload.content?.trim()
    if (!userMessage) {
      return reply.status(200).send({ ok: true, skipped: 'empty_content' })
    }

    const { conversation } = payload
    const { account_id: accountId, id: conversationId } = conversation

    const history = await fetchConversationHistory(accountId, conversationId)

    const messages: ChatMessage[] = []
    const lastMsg = history[history.length - 1]
    const alreadyIncluded =
      lastMsg?.role === 'user' && lastMsg.content === userMessage

    messages.push(...history)
    if (!alreadyIncluded) {
      messages.push({ role: 'user', content: userMessage })
    }

    try {
      const memory = await getAgentConversationMemory({
        accountId,
        conversationId: String(conversationId),
        profileSlug: DR_PAULA_MATOS_SLUG,
      })

      const triage = extractPrevidenciarioTriage({
        text: messages.map((m) => `${m.role}: ${m.content}`).join('\n'),
        previous: asStoredTriage(memory?.triageJson),
      })
      const nextMessageCount = (memory?.messageCount ?? 0) + 1
      const score = scorePrevidenciarioLead({
        triage,
        latestMessage: userMessage,
        messageCount: nextMessageCount,
      })
      const memorySummary = buildMemorySummary(triage, score)
      const retrievedDocuments = retrieveDrPaulaKnowledge(`${userMessage}\n${memorySummary}`)
      const status = score.handoff.recommended ? 'handoff_recommended' : 'active'

      await upsertAgentConversationMemory({
        accountId,
        conversationId: String(conversationId),
        profileSlug: DR_PAULA_MATOS_SLUG,
        senderName: payload.sender?.name ?? null,
        summary: memorySummary,
        factsJson: { sources: retrievedDocuments.map((doc) => doc.id) },
        triageJson: triage as unknown as Record<string, unknown>,
        scoreJson: score as unknown as Record<string, unknown>,
        lastUserMessage: userMessage,
        messageCount: nextMessageCount,
        status,
      })

      let responseText: string | undefined

      if (isLlmConfigured()) {
        const agentMessages = buildDrPaulaMessages({
          conversation: messages as AgentMessage[],
          memorySummary,
          triage,
          score,
          retrievedDocuments,
        })

        const completion = await llm.chat.completions.create({
          model: LLM_MODEL,
          messages: agentMessages,
          max_tokens: Math.min(900, LLM_MAX_TOKENS),
          temperature: 0.35,
        })

        responseText = completion.choices[0]?.message?.content?.trim()
      } else {
        request.log.warn('[AGENT] LLM_API_KEY not configured; using deterministic response')
        responseText = buildDrPaulaFallbackResponse({ triage, retrievedDocuments })
      }

      if (!responseText) {
        request.log.warn('[AGENT] Empty agent response')
        return reply.status(200).send({ ok: false, reason: 'empty_agent_response' })
      }

      await postReply(accountId, conversationId, responseText)

      if (score.handoff.recommended && memory?.status !== 'handoff_recommended') {
        await postReply(
          accountId,
          conversationId,
          buildPrivateTriageNote({ triage, score }),
          { private: true },
        )
      }

      request.log.info(
        `[AGENT] Dra. Paula respondeu conversa ${conversationId} score=${score.total}: ${responseText.slice(0, 100)}`,
      )
      return reply.status(200).send({
        ok: true,
        agent: DR_PAULA_MATOS_SLUG,
        score: score.total,
        handoffRecommended: score.handoff.recommended,
      })
    } catch (err) {
      request.log.error({ err }, '[AGENT] Falha ao gerar ou enviar resposta')
      return reply.status(500).send({ error: 'AGENT_ERROR' })
    }
  })
}

export default agentRoute
