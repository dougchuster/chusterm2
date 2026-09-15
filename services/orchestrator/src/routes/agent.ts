import type { FastifyPluginAsync } from 'fastify'
import {
  llm,
  LLM_MAX_TOKENS,
  isLlmConfigured,
} from '../llm/client.js'
import {
  buildAgentAttachmentContext,
  redactCredentialsFromText,
  type AgentMessage,
  type PrevidenciarioTriageSnapshot,
} from '../agents/drPaulaMatos.js'
import {
  resolveAgentProfile,
  type AgentProfile,
} from '../agents/profiles/index.js'
import {
  getAgentConversationMemory,
  upsertAgentConversationMemory,
} from '../agents/memory.js'
import { redis } from '../redis/client.js'
import {
  AgentBotPayloadSchema,
  CONTACT_RELATIONSHIP_FACT,
  attachmentOnlyMessageContent,
  buildUnreadableAttachmentResponse,
  isWebhookAuthorized,
  normalizeAgentAttachments,
  normalizeText,
  resolveContactRelationship,
  shouldPauseForHumanIntervention,
  type NormalizedAgentAttachment,
} from './agentContract.js'

const CHATWOOT_BASE_URL = (process.env.CHATWOOT_BASE_URL ?? 'http://core:3000').replace(/\/$/, '')
const CHATWOOT_BOT_TOKEN = process.env.CHATWOOT_BOT_TOKEN ?? ''

// SEC-02: segredo compartilhado obrigatório no webhook. Configurar o mesmo
// valor em ORCHESTRATOR_WEBHOOK_SECRET e na URL do agent_bot no Chatwoot
// (header x-webhook-secret ou query ?token=).
const WEBHOOK_SECRET = process.env.ORCHESTRATOR_WEBHOOK_SECRET ?? ''

interface ChatMessage {
  id?: number
  role: 'user' | 'assistant'
  content: string
  senderType?: string
  contentAttributes?: Record<string, unknown>
  attachments?: NormalizedAgentAttachment[]
}

const HUMAN_INTERVENTION_STATUS = 'human_intervention_requested'
const HUMAN_TAKEOVER_STATUS = 'human_takeover_detected'
const PAUSED_AUTOMATION_STATUSES = new Set([
  HUMAN_INTERVENTION_STATUS,
  HUMAN_TAKEOVER_STATUS,
])
const AUTOMATION_SOURCE = 'orchestrator'
// Serialize messages from the same conversation instead of discarding the
// second webhook while an LLM call is running. Each request waits for the
// previous one and then reloads the complete, current Chatwoot history.
const activeConversations = new Map<string, Promise<void>>()
// Dedup de webhook vive no Redis (SET NX PX): sobrevive a restart e funciona
// com mais de uma réplica do orchestrator — o Map em memória perdia o estado
// a cada deploy e permitia reprocessar eventos em instâncias paralelas.
const WEBHOOK_EVENT_TTL_MS = 10 * 60 * 1000
const webhookEventRedisKey = (key: string) => `orchestrator:webhook-event:${key}`

function isAgentGeneratedMessage(
  message: ChatMessage,
  profile: AgentProfile,
): boolean {
  return (
    message.senderType === 'agent_bot' ||
    message.contentAttributes?.generated_by === AUTOMATION_SOURCE ||
    message.contentAttributes?.chusterm_agent === profile.slug ||
    profile.isKnownAgentOpening(message.content)
  )
}

function lastOutgoingMessage(messages: ChatMessage[]): ChatMessage | undefined {
  return [...messages].reverse().find((message) => message.role === 'assistant')
}

function hasHumanTakeover(
  messages: ChatMessage[],
  profile: AgentProfile,
): boolean {
  const lastOutgoing = lastOutgoingMessage(messages)
  return Boolean(lastOutgoing && !isAgentGeneratedMessage(lastOutgoing, profile))
}

function responseWasAlreadySent(
  messages: ChatMessage[],
  responseText: string,
  profile: AgentProfile,
): boolean {
  return messages
    .filter((message) => message.role === 'assistant')
    .slice(-6)
    .some((message) =>
      profile.responsesAreNearDuplicates(message.content, responseText),
    )
}

function latestOutgoingMessageId(messages: ChatMessage[]): number | undefined {
  const ids = messages
    .filter((message) => message.role === 'assistant' && message.id !== undefined)
    .map((message) => message.id as number)
  return ids.length > 0 ? Math.max(...ids) : undefined
}

function hasNewOutgoingMessage(
  previousMessages: ChatMessage[],
  latestMessages: ChatMessage[],
): boolean {
  const previousId = latestOutgoingMessageId(previousMessages)
  const latestId = latestOutgoingMessageId(latestMessages)
  if (latestId !== undefined) {
    return previousId === undefined || latestId > previousId
  }

  const previous = lastOutgoingMessage(previousMessages)
  const latest = lastOutgoingMessage(latestMessages)
  return Boolean(latest && (!previous || latest.content !== previous.content))
}

function latestIncomingMessageId(messages: ChatMessage[]): number | undefined {
  const ids = messages
    .filter((message) => message.role === 'user' && message.id !== undefined)
    .map((message) => message.id as number)
  return ids.length > 0 ? Math.max(...ids) : undefined
}

async function markConversationPaused(input: {
  accountId: number
  conversationId: number
  profileSlug: string
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
    profileSlug: input.profileSlug,
    senderName: input.senderName ?? input.memory?.senderName ?? null,
    summary:
      input.memory?.summary ||
      `Automacao pausada: ${input.reason}. Aguardar atendimento humano.`,
    factsJson: input.memory?.factsJson as Record<string, unknown> | undefined,
    triageJson: (input.memory?.triageJson || {}) as Record<string, unknown>,
    scoreJson: (input.memory?.scoreJson || {}) as Record<string, unknown>,
    lastUserMessage: redactCredentialsFromText(input.lastUserMessage),
    messageCount: input.messageCount,
    status: input.status,
  })
}

function asStoredTriage(value: unknown): Partial<PrevidenciarioTriageSnapshot> | null {
  return value && typeof value === 'object'
    ? (value as Partial<PrevidenciarioTriageSnapshot>)
    : null
}

function asStoredFacts(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {}
}

// BUG-02: falha ao obter o histórico deve ABORTAR o processamento (as guardas
// de takeover humano e dedupe dependem dele). Erro aqui vira HistoryUnavailableError,
// nunca um array vazio silencioso.
export class HistoryUnavailableError extends Error {}

function historyRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {}
}

export function chatMessageFromHistoryPayload(value: unknown): ChatMessage | null {
  const message = historyRecord(value)
  if (message.private === true) return null

  const role =
    message.message_type === 0 || message.message_type === 'incoming'
      ? ('user' as const)
      : message.message_type === 1 || message.message_type === 'outgoing'
        ? ('assistant' as const)
        : null
  if (!role) return null

  const attachments = normalizeAgentAttachments(message.attachments)
  const rawContent = typeof message.content === 'string' ? message.content.trim() : ''
  if (!rawContent && attachments.length === 0) return null

  const sender = historyRecord(message.sender)
  const contentAttributes = historyRecord(message.content_attributes)
  return {
    id: typeof message.id === 'number' ? message.id : undefined,
    role,
    content: rawContent || attachmentOnlyMessageContent(attachments),
    senderType: typeof sender.type === 'string' ? sender.type : undefined,
    contentAttributes:
      Object.keys(contentAttributes).length > 0 ? contentAttributes : undefined,
    attachments: attachments.length > 0 ? attachments : undefined,
  }
}

async function fetchConversationHistory(
  accountId: number,
  conversationId: number,
): Promise<ChatMessage[]> {
  if (!CHATWOOT_BOT_TOKEN) {
    throw new HistoryUnavailableError('CHATWOOT_BOT_TOKEN is not configured')
  }
  try {
    const url = `${CHATWOOT_BASE_URL}/api/v1/accounts/${accountId}/conversations/${conversationId}/messages`
    const resp = await fetch(url, {
      headers: { api_access_token: CHATWOOT_BOT_TOKEN },
      signal: AbortSignal.timeout(10_000),
    })
    if (!resp.ok) {
      throw new HistoryUnavailableError(`Chatwoot history request failed with status ${resp.status}`)
    }

    const data = (await resp.json()) as { payload?: unknown[] }
    const messages = data?.payload ?? []

    return messages
      .map(chatMessageFromHistoryPayload)
      .filter((message): message is ChatMessage => Boolean(message))
      .slice(-12)
  } catch (error: unknown) {
    if (error instanceof HistoryUnavailableError) throw error
    throw new HistoryUnavailableError(
      error instanceof Error ? error.message : 'Unexpected error fetching history',
    )
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

export interface AgentRouteOptions {
  webhookSecret?: string
}

const agentRoute: FastifyPluginAsync<AgentRouteOptions> = async (fastify, options) => {
  const webhookSecret = options.webhookSecret ?? WEBHOOK_SECRET

  fastify.post('/agent/message', async (request, reply) => {
    if (
      !isWebhookAuthorized(
        request.headers as Record<string, unknown>,
        request.query,
        webhookSecret,
      )
    ) {
      request.log.warn('Rejected /agent/message call without valid webhook secret')
      return reply.status(401).send({ error: 'UNAUTHORIZED' })
    }

    const result = AgentBotPayloadSchema.safeParse(request.body)
    if (!result.success) {
      return reply.status(400).send({ error: 'INVALID_PAYLOAD' })
    }

    const payload = result.data

    if (payload.event !== 'message_created' || payload.message_type !== 'incoming') {
      return reply.status(200).send({ ok: true, skipped: true })
    }

    const webhookAttachments = normalizeAgentAttachments(payload.attachments)
    const userMessage =
      payload.content?.trim() ||
      (webhookAttachments.length > 0
        ? attachmentOnlyMessageContent(webhookAttachments)
        : '')
    if (!userMessage && webhookAttachments.length === 0) {
      return reply.status(200).send({ ok: true, skipped: 'empty_content' })
    }

    const { conversation } = payload
    const { id: conversationId } = conversation
    // Perfil resolvido por conversa: quem provisiona o agent_bot define
    // custom_attributes.agent_profile (ou chusterm_agent) no conversation.
    const profile = resolveAgentProfile(
      conversation.custom_attributes?.['agent_profile'] ??
        conversation.custom_attributes?.['chusterm_agent'],
    )
    const accountId = conversation.account_id ?? payload.account?.id
    if (accountId === undefined) {
      return reply.status(400).send({ error: 'INVALID_PAYLOAD' })
    }
    const conversationKey = `${accountId}:${conversationId}`
    const webhookEventKey =
      payload.id === undefined ? undefined : `${accountId}:${payload.id}`

    if (webhookEventKey) {
      // SET NX devolve 'OK' na primeira ocorrência e null se a chave já
      // existe dentro do TTL — dedup atômico, sem janela de corrida.
      const firstSeen = await redis.set(
        webhookEventRedisKey(webhookEventKey),
        '1',
        'PX',
        WEBHOOK_EVENT_TTL_MS,
        'NX',
      )
      if (firstSeen === null) {
        return reply.status(200).send({
          ok: true,
          skipped: 'duplicate_webhook_event',
        })
      }
    }

    const previousConversation = activeConversations.get(conversationKey)
    let releaseConversation!: () => void
    const currentConversation = new Promise<void>((resolve) => {
      releaseConversation = resolve
    })
    const queueTail = (previousConversation ?? Promise.resolve())
      .catch(() => undefined)
      .then(() => currentConversation)
    activeConversations.set(conversationKey, queueTail)

    if (previousConversation) {
      request.log.info(
        `[AGENT] Mensagem enfileirada enquanto a conversa ${conversationId} estava em processamento`,
      )
      await previousConversation.catch(() => undefined)
    }

    try {
      let history: ChatMessage[]
      try {
        history = await fetchConversationHistory(accountId, conversationId)
      } catch (error: unknown) {
        // BUG-02: sem histórico não há como checar takeover humano/dedupe —
        // abortar com 503 e deixar o Chatwoot reentregar o webhook.
        request.log.warn(
          { err: error, accountId, conversationId },
          'History unavailable; aborting to avoid replying over a human',
        )
        return reply.status(503).send({ error: 'HISTORY_UNAVAILABLE' })
      }

      const messages: ChatMessage[] = []
      const lastMsg = history[history.length - 1]
      const alreadyIncluded =
        payload.id !== undefined
          ? lastMsg?.role === 'user' && lastMsg.id === payload.id
          : lastMsg?.role === 'user' && lastMsg.content === userMessage

      messages.push(...history)
      if (alreadyIncluded && lastMsg && webhookAttachments.length > 0) {
        lastMsg.attachments = webhookAttachments
      }
      if (!alreadyIncluded) {
        messages.push({
          id: payload.id,
          role: 'user',
          content: userMessage,
          attachments:
            webhookAttachments.length > 0 ? webhookAttachments : undefined,
        })
      }
      const currentIncoming = [...messages]
        .reverse()
        .find((message) => message.role === 'user')
      const currentAttachments =
        webhookAttachments.length > 0
          ? webhookAttachments
          : currentIncoming?.attachments ?? []
      const contextIncomingId =
        latestIncomingMessageId(messages) ?? payload.id

      try {
        const memory = await getAgentConversationMemory({
        accountId,
        conversationId: String(conversationId),
        profileSlug: profile.slug,
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
          profileSlug: profile.slug,
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

      if (hasHumanTakeover(history, profile)) {
        await markConversationPaused({
          accountId,
          conversationId,
          profileSlug: profile.slug,
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

      const attachmentEvidence = buildAgentAttachmentContext(currentAttachments)
      const triage = profile.extractTriage({
        // The stored snapshot already represents previous customer evidence.
        // Applying only the newest turn lets corrections such as "não sou MEI"
        // override an older positive mention instead of re-adding it.
        text: [userMessage, attachmentEvidence].filter(Boolean).join('\n'),
        previous: asStoredTriage(memory?.triageJson),
      })
      const score = profile.scoreLead({
        triage,
        latestMessage: userMessage,
        messageCount: nextMessageCount,
      })
      const storedFacts = asStoredFacts(memory?.factsJson)
      const contactRelationship = resolveContactRelationship(
        payload,
        storedFacts[CONTACT_RELATIONSHIP_FACT],
      )
      const relationshipSummary =
        contactRelationship === 'existing_customer'
          ? 'Relacionamento CRM: cliente existente; nunca usar o aviso de lead novo.'
          : contactRelationship === 'new_lead'
            ? 'Relacionamento CRM: lead novo.'
            : 'Relacionamento CRM: n\u00e3o confirmado; n\u00e3o presumir lead novo.'
      const memorySummary = `${profile.buildMemorySummary(triage, score)}\n${relationshipSummary}`
      const retrievedDocuments = profile.retrieveKnowledge(
        `${userMessage}\n${attachmentEvidence}\n${memorySummary}`,
      )
      const status = score.review.recommended ? 'review_recommended' : 'active'
      const closingAlreadySent =
        storedFacts[profile.newLeadClosingFact] === true
      const isNewLead =
        !closingAlreadySent && contactRelationship === 'new_lead'
      const factsWithSources = {
        ...storedFacts,
        sources: retrievedDocuments.map((doc) => doc.id),
        ...(contactRelationship === 'unknown'
          ? {}
          : { [CONTACT_RELATIONSHIP_FACT]: contactRelationship }),
      }

      await upsertAgentConversationMemory({
        accountId,
        conversationId: String(conversationId),
        profileSlug: profile.slug,
        senderName: payload.sender?.name ?? null,
        summary: memorySummary,
        factsJson: factsWithSources,
        triageJson: triage as unknown as Record<string, unknown>,
        scoreJson: score as unknown as Record<string, unknown>,
        lastUserMessage: redactCredentialsFromText(userMessage),
        messageCount: nextMessageCount,
        status,
      })

      let responseText: string | undefined
      const unreadableAttachmentResponse =
        buildUnreadableAttachmentResponse(currentAttachments)
      const historyHasPublicIdentity = messages.some(
        (message) =>
          message.role === 'assistant' &&
          profile.publicIdentityPattern.test(normalizeText(message.content)),
      )
      const priorityResponse =
        unreadableAttachmentResponse && !historyHasPublicIdentity
          ? `${profile.publicIntro} ${unreadableAttachmentResponse}`
          : unreadableAttachmentResponse ??
            profile.buildPriorityResponse(messages as AgentMessage[])

      if (priorityResponse) {
        responseText = profile.normalizeResponse(priorityResponse) ?? undefined
      } else if (isLlmConfigured()) {
        const agentMessages = profile.buildMessages({
          conversation: messages as AgentMessage[],
          memorySummary,
          triage,
          score,
          retrievedDocuments,
        })

        const modelParameters = profile.llmModel.includes(
          'claude-sonnet-5',
        )
          ? {}
          : { temperature: 0.35 }
        const completion = await llm.chat.completions.create({
          model: profile.llmModel,
          messages: agentMessages,
          // Reasoning-capable models account for internal reasoning inside the
          // completion budget. A 700-token ceiling produced truncated public
          // answers before the short visible response was complete.
          max_tokens: Math.min(2048, LLM_MAX_TOKENS),
          ...modelParameters,
        })

        const rawResponse = completion.choices[0]?.message?.content?.trim()
        responseText = rawResponse
          ? profile.normalizeResponse(rawResponse) ?? undefined
          : undefined
        if (rawResponse && !responseText) {
          request.log.warn(
            {
              accountId,
              conversationId,
              finishReason: completion.choices[0]?.finish_reason,
            },
            '[AGENT] Provider output rejected by public response validator',
          )
          responseText = profile.normalizeResponse(
            profile.buildFallbackResponse({
              triage,
              retrievedDocuments,
              conversation: messages as AgentMessage[],
            }),
          ) ?? undefined
        }
      } else {
        request.log.warn('[AGENT] LLM_API_KEY not configured; using deterministic response')
        responseText = profile.normalizeResponse(
          profile.buildFallbackResponse({
            triage,
            retrievedDocuments,
            conversation: messages as AgentMessage[],
          }),
        ) ?? undefined
      }

      if (!responseText) {
        request.log.warn('[AGENT] Empty agent response')
        return reply.status(200).send({ ok: false, reason: 'empty_agent_response' })
      }

      responseText = profile.ensureNewLeadClosing(responseText, {
        conversation: messages as AgentMessage[],
        closingAlreadySent,
        isNewLead,
      })
      const closingSentNow =
        !closingAlreadySent &&
        profile.responseIncludesNewLeadClosing(responseText)

      if (responseWasAlreadySent(messages, responseText, profile)) {
        request.log.info(
          `[AGENT] Resposta duplicada bloqueada na conversa ${conversationId}`,
        )
        return reply.status(200).send({
          ok: true,
          skipped: 'duplicate_response',
        })
      }

      // Captain (Rails) and the Orchestrator can be enabled on the same inbox.
      // Re-read immediately before posting: if either engine already answered
      // while this model was generating, this route yields instead of sending a
      // second public message for the same customer turn.
      let latestHistory: ChatMessage[]
      try {
        latestHistory = await fetchConversationHistory(accountId, conversationId)
      } catch (error: unknown) {
        request.log.warn(
          { err: error, accountId, conversationId },
          'Final history check unavailable; aborting public reply',
        )
        return reply.status(503).send({ error: 'HISTORY_UNAVAILABLE' })
      }

      if (hasNewOutgoingMessage(history, latestHistory)) {
        request.log.info(
          `[AGENT] Outra resposta já foi criada na conversa ${conversationId}`,
        )
        return reply.status(200).send({
          ok: true,
          skipped: 'reply_already_created',
        })
      }
      const finalIncomingId = latestIncomingMessageId(latestHistory)
      if (
        contextIncomingId !== undefined &&
        finalIncomingId !== undefined &&
        finalIncomingId > contextIncomingId
      ) {
        request.log.info(
          `[AGENT] Resposta antiga descartada; chegou nova mensagem na conversa ${conversationId}`,
        )
        return reply.status(200).send({
          ok: true,
          skipped: 'newer_incoming_exists',
        })
      }
      if (activeConversations.get(conversationKey) !== queueTail) {
        request.log.info(
          `[AGENT] Resposta antiga descartada; há nova mensagem enfileirada na conversa ${conversationId}`,
        )
        return reply.status(200).send({
          ok: true,
          skipped: 'newer_message_queued',
        })
      }
      if (responseWasAlreadySent(latestHistory, responseText, profile)) {
        return reply.status(200).send({
          ok: true,
          skipped: 'duplicate_response',
        })
      }

      await postReply(accountId, conversationId, responseText, {
        contentAttributes: {
          chusterm_agent: profile.slug,
          generated_by: AUTOMATION_SOURCE,
        },
      })

      if (closingSentNow) {
        await upsertAgentConversationMemory({
          accountId,
          conversationId: String(conversationId),
          profileSlug: profile.slug,
          senderName: payload.sender?.name ?? null,
          summary: memorySummary,
          factsJson: {
            ...factsWithSources,
            [profile.newLeadClosingFact]: true,
          },
          triageJson: triage as unknown as Record<string, unknown>,
          scoreJson: score as unknown as Record<string, unknown>,
          lastUserMessage: redactCredentialsFromText(userMessage),
          messageCount: nextMessageCount,
          status,
        })
      }

      if (score.review.recommended && memory?.status !== 'review_recommended') {
        await postReply(
          accountId,
          conversationId,
          profile.buildPrivateTriageNote({ triage, score }),
          { private: true },
        )
      }

      request.log.info(
        `[AGENT] ${profile.publicName} respondeu conversa ${conversationId} score=${score.total}`,
      )
      return reply.status(200).send({
        ok: true,
        agent: profile.slug,
        score: score.total,
        handoffRecommended: score.handoff.recommended,
        reviewRecommended: score.review.recommended,
      })
      } catch (err) {
        request.log.error({ err }, '[AGENT] Falha ao gerar ou enviar resposta')
        return reply.status(500).send({ error: 'AGENT_ERROR' })
      }
    } finally {
      if (webhookEventKey && reply.statusCode >= 500) {
        await redis.del(webhookEventRedisKey(webhookEventKey))
      }
      releaseConversation()
      if (activeConversations.get(conversationKey) === queueTail) {
        activeConversations.delete(conversationKey)
      }
    }
  })
}

export default agentRoute
