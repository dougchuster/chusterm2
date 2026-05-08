import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { llm, LLM_MODEL, isLlmConfigured } from '../llm/client.js'

const CHATWOOT_BASE_URL = (process.env.CHATWOOT_BASE_URL ?? 'http://core:3000').replace(/\/$/, '')
const CHATWOOT_BOT_TOKEN = process.env.CHATWOOT_BOT_TOKEN ?? ''

// ─── Chatwoot AgentBot webhook payload ───────────────────────────────────────

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

// ─── Helpers ─────────────────────────────────────────────────────────────────

interface ChatMessage {
  role: 'user' | 'assistant'
  content: string
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
): Promise<void> {
  const url = `${CHATWOOT_BASE_URL}/api/v1/accounts/${accountId}/conversations/${conversationId}/messages`
  await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      api_access_token: CHATWOOT_BOT_TOKEN,
    },
    body: JSON.stringify({
      content,
      message_type: 'outgoing',
      content_type: 'text',
      private: false,
    }),
    signal: AbortSignal.timeout(15_000),
  })
}

// ─── Route ───────────────────────────────────────────────────────────────────

const SYSTEM_PROMPT = `Você é a Dra. Juliana, advogada do escritório Coimbra e Ruas, especializada em direito previdenciário, trabalhista e cível.
Seja cordial, profissional e objetiva. Use linguagem acessível, sem jargões desnecessários.
Quando o cliente iniciar a conversa, cumprimente e pergunte em que pode ajudar.
Não forneça pareceres jurídicos definitivos sem conhecer todos os fatos — oriente o cliente a agendar uma consulta presencial ou por videochamada.
Responda sempre em português brasileiro.`

const agentRoute: FastifyPluginAsync = async (fastify) => {
  fastify.post('/agent/message', async (request, reply) => {
    const result = AgentBotPayloadSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: 'INVALID_PAYLOAD' })
    }

    const payload = result.data

    // Só processa mensagens recebidas do contato
    if (payload.event !== 'message_created' || payload.message_type !== 'incoming') {
      return reply.status(200).send({ ok: true, skipped: true })
    }

    const userMessage = payload.content?.trim()
    if (!userMessage) {
      return reply.status(200).send({ ok: true, skipped: 'empty_content' })
    }

    if (!isLlmConfigured()) {
      request.log.warn('[AGENT] LLM_API_KEY não configurada — não é possível responder')
      return reply.status(200).send({ ok: false, reason: 'llm_not_configured' })
    }

    const { conversation } = payload
    const { account_id: accountId, id: conversationId } = conversation

    // Busca histórico da conversa para contexto
    const history = await fetchConversationHistory(accountId, conversationId)

    // Garante que a última mensagem do usuário está no histórico sem duplicar
    const messages: ChatMessage[] = []
    const lastMsg = history[history.length - 1]
    const alreadyIncluded =
      lastMsg?.role === 'user' && lastMsg.content === userMessage

    messages.push(...history)
    if (!alreadyIncluded) {
      messages.push({ role: 'user', content: userMessage })
    }

    try {
      const completion = await llm.chat.completions.create({
        model: LLM_MODEL,
        messages: [{ role: 'system', content: SYSTEM_PROMPT }, ...messages],
        max_tokens: 512,
      })

      const responseText = completion.choices[0]?.message?.content?.trim()
      if (!responseText) {
        request.log.warn('[AGENT] LLM retornou resposta vazia')
        return reply.status(200).send({ ok: false, reason: 'empty_llm_response' })
      }

      await postReply(accountId, conversationId, responseText)
      request.log.info(
        `[AGENT] Respondeu conversa ${conversationId}: ${responseText.slice(0, 100)}`,
      )
      return reply.status(200).send({ ok: true })
    } catch (err) {
      request.log.error({ err }, '[AGENT] Falha ao gerar ou enviar resposta')
      return reply.status(500).send({ error: 'AGENT_ERROR' })
    }
  })
}

export default agentRoute
