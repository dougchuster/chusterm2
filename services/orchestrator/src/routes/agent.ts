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
  senderType?: string
  contentAttributes?: Record<string, unknown>
}

const HUMAN_INTERVENTION_STATUS = 'human_intervention_requested'
const HUMAN_TAKEOVER_STATUS = 'human_takeover_detected'
const PAUSED_AUTOMATION_STATUSES = new Set([
  HUMAN_INTERVENTION_STATUS,
  HUMAN_TAKEOVER_STATUS,
])
const AUTOMATION_SOURCE = 'orchestrator'

function normalizeText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim()
}

function isDrPaulaOpening(content: string): boolean {
  const normalized = normalizeText(content)
  return (
    normalized.includes('aqui e a dra paula matos') &&
    normalized.includes('como posso te ajudar hoje')
  )
}

function isAgentGeneratedMessage(message: ChatMessage): boolean {
  return (
    message.senderType === 'agent_bot' ||
    message.contentAttributes?.generated_by === AUTOMATION_SOURCE ||
    message.contentAttributes?.chusterm_agent === DR_PAULA_MATOS_SLUG ||
    isDrPaulaOpening(message.content)
  )
}

function shouldPauseForHumanIntervention(text: string): boolean {
  const normalized = normalizeText(text)
  const mentionsAutomation =
    /\b(ia|inteligencia artificial|robo|bot|automat[a-z]*)\b/.test(normalized)
  const asksToStop =
    /\b(para|pare|parar|pause|pausa|pausar|assumir|humano|atendente|respondi|digitando)\b/.test(
      normalized,
    ) ||
    normalized.includes('sem ia') ||
    normalized.includes('ao mesmo tempo')

  return mentionsAutomation && asksToStop
}

function lastOutgoingMessage(messages: ChatMessage[]): ChatMessage | undefined {
  return [...messages].reverse().find((message) => message.role === 'assistant')
}

function hasHumanTakeover(messages: ChatMessage[]): boolean {
  const lastOutgoing = lastOutgoingMessage(messages)
  return Boolean(lastOutgoing && !isAgentGeneratedMessage(lastOutgoing))
}

function responseWasAlreadySent(
  messages: ChatMessage[],
  responseText: string,
): boolean {
  const normalizedResponse = normalizeText(responseText)
  return messages
    .filter((message) => message.role === 'assistant')
    .slice(-4)
    .some((message) => normalizeText(message.content) === normalizedResponse)
}

async function markConversationPaused(input: {
  accountId: number
  conversationId: number
  senderName?: string | null
  lastUserMessage: string
  messageCount: number
  memory: Awaited<ReturnType<typeof getAgentConversationMemory>>
  status: string
  reason: string
}): Promise<void> {
  await upsertAgentConversationMemory({
    accountId: input.accountId,
    conversationId: String(input.conversationId),
    profileSlug: DR_PAULA_MATOS_SLUG,
    senderName: input.senderName ?? input.memory?.senderName ?? null,
    summary:
      input.memory?.summary ||
      `Automacao pausada: ${input.reason}. Aguardar atendimento humano.`,
    factsJson: input.memory?.factsJson as Record<string, unknown> | undefined,
    triageJson: (input.memory?.triageJson || {}) as Record<string, unknown>,
    scoreJson: (input.memory?.scoreJson || {}) as Record<string, unknown>,
    lastUserMessage: input.lastUserMessage,
    messageCount: input.messageCount,
    status: input.status,
  })
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
        senderType:
          typeof (m.sender as Record<string, unknown> | undefined)?.type ===
          'string'
            ? ((m.sender as Record<string, unknown>).type as string)
            : undefined,
        contentAttributes:
          m.content_attributes &&
          typeof m.content_attributes === 'object' &&
          !Array.isArray(m.content_attributes)
            ? (m.content_attributes as Record<string, unknown>)
            : undefined,
      }))
  } catch {
    return []
  }
}

async function postReply(
  accountId: number,
  conversationId: number,
  content: string,
  options: {
    private?: boolean
    contentAttributes?: Record<string, unknown>
  } = {},
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
      content_attributes: options.contentAttributes,
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

      const nextMessageCount = (memory?.messageCount ?? 0) + 1

      if (memory?.status && PAUSED_AUTOMATION_STATUSES.has(memory.status)) {
        return reply.status(200).send({
          ok: true,
          skipped: memory.status,
        })
      }

      if (shouldPauseForHumanIntervention(userMessage)) {
        await markConversationPaused({
          accountId,
          conversationId,
          senderName: payload.sender?.name ?? null,
          lastUserMessage: userMessage,
          messageCount: nextMessageCount,
          memory,
          status: HUMAN_INTERVENTION_STATUS,
          reason: 'cliente pediu pausa da IA ou atendimento humano',
        })
        request.log.info(
          `[AGENT] Automacao pausada por pedido humano na conversa ${conversationId}`,
        )
        return reply.status(200).send({
          ok: true,
          skipped: HUMAN_INTERVENTION_STATUS,
        })
      }

      if (hasHumanTakeover(history)) {
        await markConversationPaused({
          accountId,
          conversationId,
          senderName: payload.sender?.name ?? null,
          lastUserMessage: userMessage,
          messageCount: nextMessageCount,
          memory,
          status: HUMAN_TAKEOVER_STATUS,
          reason: 'resposta humana detectada antes da nova mensagem',
        })
        request.log.info(
          `[AGENT] Automacao pausada por takeover humano na conversa ${conversationId}`,
        )
        return reply.status(200).send({
          ok: true,
          skipped: HUMAN_TAKEOVER_STATUS,
        })
      }

      const triage = extractPrevidenciarioTriage({
        text: messages.map((m) => `${m.role}: ${m.content}`).join('\n'),
        previous: asStoredTriage(memory?.triageJson),
      })
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

      if (responseWasAlreadySent(messages, responseText)) {
        request.log.info(
          `[AGENT] Resposta duplicada bloqueada na conversa ${conversationId}: ${responseText.slice(0, 100)}`,
        )
        return reply.status(200).send({
          ok: true,
          skipped: 'duplicate_response',
        })
      }

      await postReply(accountId, conversationId, responseText, {
        contentAttributes: {
          chusterm_agent: DR_PAULA_MATOS_SLUG,
          generated_by: AUTOMATION_SOURCE,
        },
      })

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
