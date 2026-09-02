import { z } from 'zod'

const NullableString = z.string().nullish()

export const AgentAttachmentSchema = z
  .object({
    id: z.union([z.number(), z.string()]).optional(),
    message_id: z.union([z.number(), z.string()]).optional(),
    file_type: NullableString,
    type: NullableString,
    mime_type: NullableString,
    extension: NullableString,
    data_url: NullableString,
    url: NullableString,
    file_url: NullableString,
    thumb_url: NullableString,
    file_size: z.number().nonnegative().nullish(),
    width: z.number().nullish(),
    height: z.number().nullish(),
    image_description: NullableString,
    ocr_text: NullableString,
    document_guess: NullableString,
    media_understanding_status: NullableString,
    status: NullableString,
    transcribed_text: NullableString,
    meta: z.record(z.unknown()).nullish(),
  })
  .passthrough()

const ContactContextSchema = z
  .object({
    name: NullableString,
    type: NullableString,
    relationship_status: NullableString,
    lifecycle_stage: NullableString,
    contact_type: z.union([z.string(), z.number()]).nullish(),
    custom_attributes: z.record(z.unknown()).optional(),
  })
  .passthrough()

export const AgentBotPayloadSchema = z
  .object({
    id: z.number().optional(),
    event: z.string(),
    content: z.string().nullish(),
    message_type: z.string().optional(),
    content_type: z.string().optional(),
    attachments: z.array(AgentAttachmentSchema).optional().default([]),
    account: z.object({ id: z.number() }).passthrough().optional(),
    // Backwards-compatible enrichment for callers that can provide the CRM
    // dossier. Native Chatwoot webhooks use sender/conversation fields.
    crm_context: z.record(z.unknown()).optional(),
    conversation: z
      .object({
        id: z.number(),
        account_id: z.number().optional(),
        custom_attributes: z.record(z.unknown()).optional(),
        labels: z
          .array(
            z.union([
              z.string(),
              z.object({ title: z.string() }).passthrough(),
            ]),
          )
          .optional(),
        meta: z
          .object({ sender: ContactContextSchema.optional() })
          .passthrough()
          .optional(),
      })
      .passthrough(),
    sender: ContactContextSchema.optional(),
  })
  .passthrough()
  .superRefine((payload, context) => {
    if (payload.conversation.account_id === undefined && payload.account?.id === undefined) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'account id is required in conversation.account_id or account.id',
      })
    }
  })

export type AgentAttachmentPayload = z.infer<typeof AgentAttachmentSchema>

export interface NormalizedAgentAttachment {
  id?: number | string
  fileType: string
  extension?: string
  dataUrl?: string
  fileSize?: number
  width?: number
  height?: number
  imageDescription?: string
  ocrText?: string
  documentGuess?: string
  mediaUnderstandingStatus?: string
  transcribedText?: string
}

export type ContactRelationship =
  | 'new_lead'
  | 'existing_customer'
  | 'unknown'

export const CONTACT_RELATIONSHIP_FACT = 'drLeticiaContactRelationship'

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {}
}

function nonEmptyString(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) return value.trim()
  }
  return undefined
}

export function normalizeAgentAttachments(
  value: unknown,
): NormalizedAgentAttachment[] {
  if (!Array.isArray(value)) return []

  return value.flatMap((candidate) => {
    const parsed = AgentAttachmentSchema.safeParse(candidate)
    if (!parsed.success) return []

    const attachment = parsed.data
    const meta = asRecord(attachment.meta)
    const fileType =
      nonEmptyString(
        attachment.file_type,
        attachment.type,
        attachment.mime_type,
        meta.file_type,
        meta.mime_type,
      ) ?? 'arquivo'

    return [
      {
        id: attachment.id,
        fileType,
        extension: nonEmptyString(attachment.extension, meta.extension),
        dataUrl: nonEmptyString(
          attachment.data_url,
          attachment.file_url,
          attachment.url,
          meta.data_url,
          meta.file_url,
          meta.url,
        ),
        fileSize:
          typeof attachment.file_size === 'number'
            ? attachment.file_size
            : typeof meta.file_size === 'number'
              ? meta.file_size
              : undefined,
        width:
          typeof attachment.width === 'number'
            ? attachment.width
            : typeof meta.width === 'number'
              ? meta.width
              : undefined,
        height:
          typeof attachment.height === 'number'
            ? attachment.height
            : typeof meta.height === 'number'
              ? meta.height
              : undefined,
        imageDescription: nonEmptyString(
          attachment.image_description,
          meta.image_description,
        ),
        ocrText: nonEmptyString(attachment.ocr_text, meta.ocr_text),
        documentGuess: nonEmptyString(
          attachment.document_guess,
          meta.document_guess,
        ),
        mediaUnderstandingStatus: nonEmptyString(
          attachment.media_understanding_status,
          attachment.status,
          meta.media_understanding_status,
          meta.status,
        ),
        transcribedText: nonEmptyString(
          attachment.transcribed_text,
          meta.transcribed_text,
        ),
      },
    ]
  })
}

function attachmentType(attachment: NormalizedAgentAttachment): string {
  return normalizeText(
    attachment.fileType + ' ' + (attachment.extension ?? ''),
  )
}

export function attachmentCanBeRead(
  attachment: NormalizedAgentAttachment,
): boolean {
  if (
    attachment.ocrText ||
    attachment.imageDescription ||
    attachment.transcribedText
  ) {
    return true
  }
  if (attachment.fileSize === 0) return false

  const status = normalizeText(attachment.mediaUnderstandingStatus ?? '')
  if (/(?:failed|error|skipped|timeout|unreadable|ilegivel|vazio)/u.test(status)) {
    return false
  }

  // Images can be supplied to the configured vision model. PDF/file/audio
  // require OCR or transcription before the agent can claim a reading.
  return (
    /(?:^|\s)(?:image|imagem|png|jpe?g|webp|heic)(?:\s|$)/u.test(
      attachmentType(attachment),
    ) && Boolean(attachment.dataUrl)
  )
}

export function buildUnreadableAttachmentResponse(
  attachments: NormalizedAgentAttachment[],
): string | null {
  if (attachments.length === 0 || attachments.every(attachmentCanBeRead)) {
    return null
  }

  if (attachments.some(attachmentCanBeRead)) {
    return 'Recebi os anexos, mas um arquivo est\u00e1 sem conte\u00fado leg\u00edvel; reenvie-o em PDF, foto n\u00edtida ou \u00e1udio claro para eu n\u00e3o presumir informa\u00e7\u00f5es.'
  }

  return 'Recebi o arquivo, mas n\u00e3o consegui ler com seguran\u00e7a; reenvie em PDF, foto n\u00edtida ou \u00e1udio claro, pois n\u00e3o vou presumir o conte\u00fado.'
}

export function attachmentOnlyMessageContent(
  attachments: NormalizedAgentAttachment[],
): string {
  const noun = attachments.length === 1 ? 'anexo' : 'anexos'
  return 'Enviei ' + attachments.length + ' ' + noun + ' para an\u00e1lise.'
}

function nestedValue(record: Record<string, unknown>, path: string[]): unknown {
  let current: unknown = record
  for (const key of path) current = asRecord(current)[key]
  return current
}

function relationshipFromValue(value: unknown): ContactRelationship {
  if (value === 2) return 'existing_customer'
  if (value === 1) return 'new_lead'
  if (typeof value !== 'string') return 'unknown'

  const normalized = normalizeText(value).replace(/[\s-]+/g, '_')
  if (
    /^(?:customer|cliente|existing_customer|active_customer|recurring_customer|ex_customer|won)$/u.test(
      normalized,
    )
  ) {
    return 'existing_customer'
  }
  if (
    /^(?:lead|new_lead|novo_lead|prospect|qualified_lead|lead_qualified|triage|in_triage)$/u.test(
      normalized,
    )
  ) {
    return 'new_lead'
  }
  return 'unknown'
}

/**
 * Current CRM fields win and the stored fact is a fallback. A confirmed
 * customer is sticky, so a later sparse webhook never regresses it to lead.
 */
export function resolveContactRelationship(
  payload: unknown,
  previous: unknown = 'unknown',
): ContactRelationship {
  const root = asRecord(payload)
  const candidates = [
    nestedValue(root, ['sender', 'relationship_status']),
    nestedValue(root, ['sender', 'lifecycle_stage']),
    nestedValue(root, ['sender', 'contact_type']),
    nestedValue(root, ['sender', 'custom_attributes', 'relationship_status']),
    nestedValue(root, ['sender', 'custom_attributes', 'lifecycle_stage']),
    nestedValue(root, ['conversation', 'meta', 'sender', 'relationship_status']),
    nestedValue(root, ['conversation', 'meta', 'sender', 'lifecycle_stage']),
    nestedValue(root, ['conversation', 'meta', 'sender', 'contact_type']),
    nestedValue(root, ['crm_context', 'contact', 'relationship_assessment', 'status']),
    nestedValue(root, ['crm_context', 'contact', 'relationship_status']),
    nestedValue(root, ['crm_context', 'contact', 'lifecycle_stage']),
    nestedValue(root, ['crm_context', 'contact', 'contact_type']),
    nestedValue(root, ['crm_context', 'deal', 'status']),
    nestedValue(root, ['conversation', 'custom_attributes', 'relationship_status']),
    nestedValue(root, ['conversation', 'custom_attributes', 'lifecycle_stage']),
  ].map(relationshipFromValue)

  if (candidates.includes('existing_customer')) return 'existing_customer'

  const previousRelationship = relationshipFromValue(previous)
  if (previousRelationship === 'existing_customer') return 'existing_customer'
  if (candidates.includes('new_lead')) return 'new_lead'
  if (previousRelationship === 'new_lead') return 'new_lead'
  return 'unknown'
}

export function isWebhookAuthorized(
  headers: Record<string, unknown>,
  query: unknown,
  webhookSecret: string,
): boolean {
  if (!webhookSecret) return false

  const headerSecret = headers['x-webhook-secret']
  if (typeof headerSecret === 'string' && headerSecret === webhookSecret) return true

  const queryToken =
    query && typeof query === 'object' ? (query as Record<string, unknown>).token : undefined
  return typeof queryToken === 'string' && queryToken === webhookSecret
}

export function normalizeText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim()
}

export function shouldPauseForHumanIntervention(text: string): boolean {
  const normalized = normalizeText(text)
  const mentionsAutomation =
    /\b(ia|inteligencia artificial|robo|bot|automat[a-z]*)\b/u.test(normalized)
  const asksToStop =
    /\b(para|pare|parar|pause|pausa|pausar|assumir|humano|atendente|respondi|digitando)\b/u.test(
      normalized,
    ) ||
    normalized.includes('sem ia') ||
    normalized.includes('ao mesmo tempo')

  const requestsHuman =
    /\b(?:quero|gostaria|preciso|prefiro|pode|posso|poderia|desejo)\b.{0,45}\b(?:humano|atendente|pessoa)\b/u.test(
      normalized,
    ) ||
    /\b(?:falar|conversar|atendimento)\b.{0,35}\b(?:com (?:um|uma) )?(?:humano|atendente|pessoa)\b/u.test(
      normalized,
    ) ||
    /^(?:um|uma)?\s*(?:humano|atendente|pessoa)(?:,?\s+por favor|\s+agora)?[.!?]*$/u.test(
      normalized,
    )
  const requestsDraPaula =
    /\b(?:falar|conversar|atendimento|quero|preciso|gostaria)\b.{0,55}\bdra\.? paula(?: matos)?\b/u.test(
      normalized,
    )

  // "Quero falar com uma advogada" intentionally does not match: Dra. Leticia
  // is the lawyer responsible for the initial service.
  return requestsHuman || requestsDraPaula || (mentionsAutomation && asksToStop)
}
