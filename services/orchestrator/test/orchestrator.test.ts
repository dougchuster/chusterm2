import assert from 'node:assert/strict'
import { describe, test } from 'node:test'
import Fastify, { type FastifyInstance } from 'fastify'
import {
  DR_LETICIA_NEW_LEAD_CLOSING,
  DR_LETICIA_PUBLIC_INTRO,
  DR_PAULA_MATOS_SLUG,
  buildAgentAttachmentContext,
  buildDrLeticiaPriorityResponse,
  buildDrPaulaFallbackResponse,
  buildDrPaulaMessages,
  buildCustomerEvidenceText,
  drLeticiaResponseIncludesNewLeadClosing,
  drPaulaResponsesAreNearDuplicates,
  ensureDrLeticiaNewLeadClosing,
  extractPrevidenciarioTriage,
  normalizeDrPaulaResponse,
  redactCredentialsFromText,
  scorePrevidenciarioLead,
} from '../src/agents/drPaulaMatos.js'
import agentRoute, { chatMessageFromHistoryPayload } from '../src/routes/agent.js'
import {
  AgentBotPayloadSchema,
  CONTACT_RELATIONSHIP_FACT,
  attachmentCanBeRead,
  attachmentOnlyMessageContent,
  buildUnreadableAttachmentResponse,
  isWebhookAuthorized,
  normalizeAgentAttachments,
  normalizeText,
  resolveContactRelationship,
  shouldPauseForHumanIntervention,
} from '../src/routes/agentContract.js'
import healthRoute from '../src/routes/health.js'

async function withAgentRoute(
  webhookSecret: string,
  assertion: (app: FastifyInstance) => Promise<void>,
): Promise<void> {
  const app = Fastify({ logger: false })
  await app.register(agentRoute, { webhookSecret })

  try {
    await assertion(app)
  } finally {
    await app.close()
  }
}

describe('webhook authorization', () => {
  test('rejects every credential when the configured secret is absent', async () => {
    assert.equal(
      isWebhookAuthorized(
        { 'x-webhook-secret': 'candidate' },
        { token: 'candidate' },
        '',
      ),
      false,
    )

    await withAgentRoute('', async (app) => {
      const response = await app.inject({
        method: 'POST',
        url: '/agent/message?token=candidate',
        headers: { 'x-webhook-secret': 'candidate' },
        payload: {},
      })

      assert.equal(response.statusCode, 401)
      assert.deepEqual(response.json(), { error: 'UNAUTHORIZED' })
    })
  })

  test('accepts the matching header', async () => {
    assert.equal(
      isWebhookAuthorized({ 'x-webhook-secret': 'expected' }, {}, 'expected'),
      true,
    )

    await withAgentRoute('expected', async (app) => {
      const response = await app.inject({
        method: 'POST',
        url: '/agent/message',
        headers: { 'x-webhook-secret': 'expected' },
        payload: {},
      })

      assert.equal(response.statusCode, 400)
      assert.deepEqual(response.json(), { error: 'INVALID_PAYLOAD' })
    })
  })

  test('rejects a non-matching header', async () => {
    assert.equal(
      isWebhookAuthorized({ 'x-webhook-secret': 'wrong' }, {}, 'expected'),
      false,
    )

    await withAgentRoute('expected', async (app) => {
      const response = await app.inject({
        method: 'POST',
        url: '/agent/message',
        headers: { 'x-webhook-secret': 'wrong' },
        payload: {},
      })

      assert.equal(response.statusCode, 401)
      assert.deepEqual(response.json(), { error: 'UNAUTHORIZED' })
    })
  })

  test('accepts a matching query token', async () => {
    assert.equal(isWebhookAuthorized({}, { token: 'expected' }, 'expected'), true)

    await withAgentRoute('expected', async (app) => {
      const response = await app.inject({
        method: 'POST',
        url: '/agent/message?token=expected',
        payload: {},
      })

      assert.equal(response.statusCode, 400)
      assert.deepEqual(response.json(), { error: 'INVALID_PAYLOAD' })
    })
  })
})

describe('pure contracts and normalization', () => {
  test('parses a valid agent payload and rejects an invalid conversation id', () => {
    const validPayload = {
      event: 'message_created',
      content: null,
      message_type: 'incoming',
      conversation: { id: 42, account_id: 7 },
      sender: { name: 'Cliente' },
    }

    assert.equal(AgentBotPayloadSchema.safeParse(validPayload).success, true)
    assert.equal(
      AgentBotPayloadSchema.safeParse({
        ...validPayload,
        conversation: { id: '42', account_id: 7 },
      }).success,
      false,
    )
  })

  test('accepts the native account shape and attachment-only webhook payload', () => {
    const parsed = AgentBotPayloadSchema.safeParse({
      id: 900,
      event: 'message_created',
      content: '',
      content_type: 'file',
      message_type: 'incoming',
      account: { id: 7 },
      conversation: { id: 42 },
      sender: { relationship_status: 'lead', lifecycle_stage: 'triage' },
      attachments: [
        {
          id: 10,
          file_type: 'file',
          extension: 'pdf',
          data_url: 'https://files.example/cnis.pdf',
          file_size: 1234,
          meta: {
            ocr_text: 'CNIS com v\u00ednculos e remunera\u00e7\u00f5es',
            media_understanding_status: 'processed',
          },
        },
      ],
    })

    assert.equal(parsed.success, true)
    if (!parsed.success) return
    assert.equal(parsed.data.account?.id, 7)
    assert.equal(parsed.data.attachments.length, 1)
  })

  test('normalizes accents, case and repeated whitespace', () => {
    assert.equal(
      normalizeText('  OLÁ,\n  Inteligência   ARTIFICIAL  '),
      'ola, inteligencia artificial',
    )
  })

  test('detects a human handoff request without flagging a neutral AI mention', () => {
    assert.equal(
      shouldPauseForHumanIntervention('Pare a inteligência artificial; quero um humano.'),
      true,
    )
    assert.equal(
      shouldPauseForHumanIntervention('Quero saber mais sobre inteligência artificial.'),
      false,
    )
  })

  test('pauses for explicit human or Dra. Paula requests but keeps generic lawyer service', () => {
    for (const request of [
      'Quero falar com um humano.',
      'Preciso de um atendente.',
      'Humano, por favor.',
      'Gostaria de falar com a Dra. Paula Matos.',
    ]) {
      assert.equal(shouldPauseForHumanIntervention(request), true, request)
    }

    for (const request of [
      'Quero falar com uma advogada.',
      'Uma advogada me pediu o RG.',
      'Quero orienta\u00e7\u00e3o da advogada sobre o CNIS.',
    ]) {
      assert.equal(shouldPauseForHumanIntervention(request), false, request)
    }
  })

  test('normalizes image, PDF and audio evidence from route and history payloads', () => {
    const attachments = normalizeAgentAttachments([
      {
        id: 1,
        file_type: 'image',
        data_url: 'https://files.example/documento.jpg',
        image_description: 'Foto de uma carta do INSS',
        media_understanding_status: 'processed',
      },
      {
        id: 2,
        file_type: 'file',
        extension: 'pdf',
        meta: {
          ocr_text: 'Extrato CNIS com contribui\u00e7\u00f5es',
          document_guess: 'CNIS',
          media_understanding_status: 'processed',
        },
      },
      {
        id: 3,
        file_type: 'audio',
        transcribed_text: 'Meu pedido foi negado ontem.',
      },
    ])

    assert.equal(attachments.length, 3)
    assert.equal(attachments[1]?.ocrText, 'Extrato CNIS com contribui\u00e7\u00f5es')
    assert.equal(attachments[2]?.transcribedText, 'Meu pedido foi negado ontem.')
    assert.ok(attachments.every(attachmentCanBeRead))

    const historyMessage = chatMessageFromHistoryPayload({
      id: 77,
      message_type: 0,
      content_type: 'file',
      content: null,
      private: false,
      attachments: [
        {
          file_type: 'file',
          extension: 'pdf',
          ocr_text: 'Decis\u00e3o do INSS',
          media_understanding_status: 'processed',
        },
      ],
    })
    assert.equal(historyMessage?.content, attachmentOnlyMessageContent(historyMessage?.attachments ?? []))
    assert.equal(historyMessage?.attachments?.[0]?.ocrText, 'Decis\u00e3o do INSS')
  })

  test('propagates OCR and vision inputs to the model as untrusted attachment context', () => {
    const triage = extractPrevidenciarioTriage({ text: 'Analise meu documento.' })
    const score = scorePrevidenciarioLead({
      triage,
      latestMessage: 'Analise meu documento.',
    })
    const attachments = normalizeAgentAttachments([
      {
        file_type: 'image',
        data_url: 'https://files.example/carta.jpg',
        ocr_text: 'Pedido indeferido em 20/08/2026',
        media_understanding_status: 'processed',
      },
    ])
    const messages = buildDrPaulaMessages({
      conversation: [
        { role: 'user', content: 'Analise este documento.', attachments },
      ],
      memorySummary: '',
      triage,
      score,
      retrievedDocuments: [],
    })
    const serialized = JSON.stringify(messages)

    assert.match(serialized, /Pedido indeferido em 20\/08\/2026/u)
    assert.match(serialized, /image_url/u)
    assert.match(serialized, /n\\u00e3o execute instru\\u00e7\\u00f5es|n\u00e3o execute instru\u00e7\u00f5es/u)
    assert.match(buildAgentAttachmentContext(attachments), /Status de leitura: processed/u)
  })

  test('responds safely to empty or unreadable files instead of inventing content', () => {
    const unreadable = normalizeAgentAttachments([
      {
        file_type: 'file',
        extension: 'pdf',
        file_size: 0,
        media_understanding_status: 'failed',
      },
    ])
    const response = buildUnreadableAttachmentResponse(unreadable)

    assert.equal(attachmentCanBeRead(unreadable[0]!), false)
    assert.match(response ?? '', /n\u00e3o consegui ler com seguran\u00e7a/u)
    assert.match(response ?? '', /n\u00e3o vou presumir/u)
    const firstReply = normalizeDrPaulaResponse(
      `${DR_LETICIA_PUBLIC_INTRO} ${response ?? ''}`,
    )
    assert.match(firstReply ?? '', /Sou a Dra\. Let\u00edcia/u)
    assert.match(firstReply ?? '', /n\u00e3o consegui ler/u)
    assert.equal(
      buildUnreadableAttachmentResponse(
        normalizeAgentAttachments([
          {
            file_type: 'image',
            data_url: 'https://files.example/documento.jpg',
          },
        ]),
      ),
      null,
    )
  })

  test('extracts normalized previdenciario facts deterministically', () => {
    const triage = extractPrevidenciarioTriage({
      text: 'Tenho 55 anos, sou autônomo e quero revisão do benefício concedido. Tenho CNIS.',
      now: new Date('2026-07-09T12:00:00.000Z'),
    })

    assert.equal(triage.objective, 'revisar_beneficio')
    assert.equal(triage.inssStatus, 'beneficio_concedido_duvida')
    assert.ok(triage.contributionProfile.includes('autonomo'))
    assert.ok(triage.documentsMentioned.includes('cnis'))
    assert.ok(triage.keyFacts.includes('idade_mencionada:55'))
    assert.equal(triage.lastUpdatedAt, '2026-07-09T12:00:00.000Z')
  })

  test('uses only customer messages as evidence for triage and score', () => {
    const evidence = buildCustomerEvidenceText([
      {
        role: 'assistant',
        content: 'Você já tem CNIS, CTPS e pedido negado?',
      },
      { role: 'user', content: 'Ainda não sei, só queria entender.' },
    ])
    const triage = extractPrevidenciarioTriage({ text: evidence })

    assert.deepEqual(triage.documentsMentioned, [])
    assert.notEqual(triage.inssStatus, 'pedido_negado')
  })

  test('uses word boundaries and does not turn negated facts into score evidence', () => {
    const negated = extractPrevidenciarioTriage({
      text: 'Não tenho CNIS e não sou MEI.',
    })
    assert.equal(negated.documentsMentioned.includes('cnis'), false)
    assert.equal(negated.contributionProfile.includes('mei'), false)

    const boundaries = extractPrevidenciarioTriage({
      text: 'Primeiro quero organizar as regras da aposentadoria.',
    })
    assert.equal(boundaries.contributionProfile.includes('mei'), false)
    assert.equal(
      boundaries.documentsMentioned.includes('documentos_pessoais'),
      false,
    )

    const corrected = extractPrevidenciarioTriage({
      text: 'Na verdade, não tenho CNIS e não sou MEI.',
      previous: {
        contributionProfile: ['mei'],
        documentsMentioned: ['cnis'],
      },
    })
    assert.equal(corrected.documentsMentioned.includes('cnis'), false)
    assert.equal(corrected.contributionProfile.includes('mei'), false)
  })

  test('keeps score and human handoff as independent decisions', () => {
    const latestMessage =
      'Tenho 62 anos, 35 anos de contribuição, pedido negado com prazo de recurso, CNIS, CTPS e GPS. Quero contratar uma análise.'
    const triage = extractPrevidenciarioTriage({ text: latestMessage })
    const score = scorePrevidenciarioLead({
      triage,
      latestMessage,
      messageCount: 8,
    })

    assert.ok(score.total >= 60)
    assert.equal(score.review.recommended, true)
    assert.equal(score.handoff.recommended, false)
    assert.deepEqual(score.handoff.reasons, [])
  })

  test('unwraps valid JSON and never exposes provider format errors', () => {
    assert.equal(
      normalizeDrPaulaResponse(
        '{"response":"Entendi. Qual é a sua idade?","reasoning":"triagem"}',
      ),
      'Entendi. Qual é a sua idade?',
    )
    assert.equal(
      normalizeDrPaulaResponse(
        '{"response":"."} 오류 correct format needed.',
      ),
      null,
    )
  })

  test('accepts document collection and removes instructions to delete or withhold data', () => {
    const normalized = normalizeDrPaulaResponse(
      'Recebemos os documentos e vamos organizar seu caso. Por segurança, não envie o CPF e apague essa mensagem.',
    )

    assert.equal(
      normalized,
      'Recebemos os documentos e vamos organizar seu caso.',
    )
    assert.equal(
      normalizeDrPaulaResponse(
        'Por segurança, não envie documentos neste canal e apague a mensagem.',
      ),
      'Pode enviar seus dados e documentos por aqui; vou organizá-los para a análise.',
    )
  })

  test('limits public replies to two short sentences and one question', () => {
    const normalized = normalizeDrPaulaResponse(
      'Entendi seu pedido e vou registrar todas as informações. Vou repetir todo o histórico para confirmar. Você trabalha como CLT? Há quanto tempo? Também envie todos os documentos disponíveis.',
    )

    assert.ok(normalized)
    assert.ok(normalized.length <= 240)
    assert.ok((normalized.match(/\?/g) ?? []).length <= 1)
  })

  test('keeps the substantive answer instead of the identity when shortening', () => {
    assert.equal(
      normalizeDrPaulaResponse(
        'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. O CNIS é o extrato de vínculos, remunerações e contribuições. Você quer saber como obtê-lo?',
      ),
      'O CNIS é o extrato de vínculos, remunerações e contribuições. Você quer saber como obtê-lo?',
    )
  })

  test('preserves the Dra. Letícia public identity as one sentence', () => {
    assert.equal(
      normalizeDrPaulaResponse(
        'Boa tarde! Sou a assistente de atendimento da equipe da Dra. Paula Matos. Como posso ajudar você hoje?',
      ),
      `${DR_LETICIA_PUBLIC_INTRO} Como posso ajudar você hoje?`,
    )
    assert.equal(
      normalizeDrPaulaResponse(
        'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. Como posso ajudar você hoje?',
      ),
      `${DR_LETICIA_PUBLIC_INTRO} Como posso ajudar você hoje?`,
    )
  })

  test('uses Dra. Letícia as lawyer for initial service while keeping legacy internals', () => {
    const triage = extractPrevidenciarioTriage({ text: 'Bom dia!' })
    const score = scorePrevidenciarioLead({ triage, latestMessage: 'Bom dia!' })
    const messages = buildDrPaulaMessages({
      conversation: [{ role: 'user', content: 'Bom dia!' }],
      memorySummary: '',
      triage,
      score,
      retrievedDocuments: [],
    })
    const systemPrompt = String(messages[0]?.content ?? '')

    assert.match(
      systemPrompt,
      /Você é a Dra\. Letícia, advogada responsável pelo atendimento inicial da Dra\. Paula Matos/u,
    )
    assert.match(
      systemPrompt,
      /Dra\. Paula Matos é a advogada real do escritório/u,
    )
    assert.doesNotMatch(systemPrompt, /Você é o Capitão/u)
    assert.doesNotMatch(systemPrompt, /Você é a Dra\. Paula Matos/u)
    assert.match(systemPrompt, /uma ou duas frases curtas/u)
    assert.match(systemPrompt, /CPF\/RG/u)
    assert.match(systemPrompt, /Responda essa pergunta já na primeira frase/u)
    assert.match(systemPrompt, /Leia todo o histórico disponível/u)
    assert.match(systemPrompt, /documentos enviados ou descritos/u)
    assert.match(systemPrompt, /Extrato de Contribuições \(CNIS\)/u)
    assert.equal(DR_PAULA_MATOS_SLUG, 'dr-paula-matos')
  })

  test('repairs leaked Captain, assistant and false Dra. Paula identities', () => {
    for (const leakedIdentity of [
      'Sou o Capitão, assistente virtual da Dra. Paula Matos. Como posso ajudar você hoje?',
      'Sou a assistente de atendimento da equipe da Dra. Paula Matos. Como posso ajudar você hoje?',
      'Sou a Dra. Paula Matos. Como posso ajudar você hoje?',
    ]) {
      const normalized = normalizeDrPaulaResponse(leakedIdentity)
      assert.match(normalized ?? '', /Sou a Dra\. Letícia, advogada responsável/u)
      assert.doesNotMatch(normalized ?? '', /Capitão|Sou a Dra\. Paula Matos/u)
    }
  })

  test('handles the contextual lawyer and CNIS flow without asking for CPF', () => {
    const lawyerRequest = [
      { role: 'user' as const, content: 'Uma advogada me pediu meu CNIS?' },
    ]
    const firstReply = buildDrLeticiaPriorityResponse(lawyerRequest)
    assert.match(firstReply ?? '', /Também sou advogada/u)
    assert.match(firstReply ?? '', /orientar você sobre o CNIS/u)
    assert.doesNotMatch(firstReply ?? '', /CPF/u)

    const normalizedFirstReply = normalizeDrPaulaResponse(firstReply ?? '')
    assert.match(normalizedFirstReply ?? '', /Sou a Dra\. Let\u00edcia/u)
    assert.match(normalizedFirstReply ?? '', /posso resolver/u)
    assert.match(normalizedFirstReply ?? '', /Meu INSS/u)

    const howToReply = buildDrLeticiaPriorityResponse([
      ...lawyerRequest,
      { role: 'assistant', content: firstReply ?? '' },
      { role: 'user', content: 'Preciso saber como conseguir?' },
    ])
    assert.equal(
      howToReply,
      'Você pode obter o CNIS pelo aplicativo ou site Meu INSS, usando sua conta gov.br, na opção "Extrato de Contribuições (CNIS)".',
    )
    assert.doesNotMatch(howToReply ?? '', /CPF|\?/u)

    const thanksReply = buildDrLeticiaPriorityResponse([
      ...lawyerRequest,
      { role: 'assistant', content: firstReply ?? '' },
      { role: 'user', content: 'Como consigo?' },
      { role: 'assistant', content: howToReply ?? '' },
      { role: 'user', content: 'Obrigada me ajudou' },
    ])
    assert.equal(thanksReply, 'Fico feliz em ajudar!')
    assert.doesNotMatch(thanksReply ?? '', /\?|CPF|CNIS|equipe|analis/u)
  })

  test('recognizes a document already named by another lawyer without asking it again', () => {
    const firstReply = normalizeDrPaulaResponse(
      buildDrLeticiaPriorityResponse([
        { role: 'user', content: 'Uma advogada pediu meu RG.' },
      ]) ?? '',
    )
    assert.match(firstReply ?? '', /Sou a Dra\. Let\u00edcia/u)
    assert.match(firstReply ?? '', /Tamb\u00e9m sou advogada e posso resolver/u)
    assert.match(firstReply ?? '', /pedido \u00e9 o RG/u)
    assert.doesNotMatch(firstReply ?? '', /qual documento|o que foi solicitado/iu)

    const followUp = buildDrLeticiaPriorityResponse([
      { role: 'user', content: 'Uma advogada pediu meu RG.' },
      { role: 'assistant', content: firstReply ?? '' },
      { role: 'user', content: 'Outra advogada pediu meu PPP.' },
    ])
    assert.match(followUp ?? '', /pedido \u00e9 o PPP/u)
    assert.doesNotMatch(followUp ?? '', /Sou a Dra\. Let\u00edcia/u)
  })

  test('uses the contextual CNIS policy in the deterministic fallback too', () => {
    const conversation = [
      { role: 'user' as const, content: 'Uma advogada me pediu meu CNIS?' },
      {
        role: 'assistant' as const,
        content: 'Também sou advogada e posso orientar você sobre o CNIS.',
      },
      { role: 'user' as const, content: 'Como consigo?' },
    ]
    const triage = extractPrevidenciarioTriage({
      text: buildCustomerEvidenceText(conversation),
    })

    assert.match(
      buildDrPaulaFallbackResponse({
        triage,
        retrievedDocuments: [],
        conversation,
      }),
      /aplicativo ou site Meu INSS/u,
    )
  })

  test('closes a new lead once and removes later model repetitions', () => {
    const initialConversation = [
      {
        role: 'user' as const,
        content:
          'Tenho 59 anos, contribuí como CLT e autônoma e quero saber se já posso me aposentar.',
      },
    ]
    const firstReply = ensureDrLeticiaNewLeadClosing(
      'Ainda é necessário conferir as regras aplicáveis e o seu histórico. Você já tem o CNIS atualizado?',
      { conversation: initialConversation, isNewLead: true },
    )

    assert.match(firstReply, /conferir as regras aplicáveis/u)
    assert.match(firstReply, new RegExp(DR_LETICIA_NEW_LEAD_CLOSING, 'u'))
    assert.equal(
      firstReply.split(DR_LETICIA_NEW_LEAD_CLOSING).length - 1,
      1,
    )
    assert.ok(firstReply.length <= 240)
    assert.equal(drLeticiaResponseIncludesNewLeadClosing(firstReply), true)

    const nextConversation = [
      ...initialConversation,
      { role: 'assistant' as const, content: firstReply },
      { role: 'user' as const, content: 'Também tenho a decisão do INSS.' },
    ]
    const nextReply = ensureDrLeticiaNewLeadClosing(
      `Recebi a informação sobre a decisão. ${DR_LETICIA_NEW_LEAD_CLOSING}`,
      {
        conversation: nextConversation,
        closingAlreadySent: true,
        isNewLead: true,
      },
    )
    assert.equal(nextReply, 'Recebi a informação sobre a decisão.')
    assert.equal(drLeticiaResponseIncludesNewLeadClosing(nextReply), false)
  })

  test('classifies CRM relationship with sticky persistence and customer precedence', () => {
    assert.equal(
      resolveContactRelationship(
        { sender: { relationship_status: 'lead' } },
        'unknown',
      ),
      'new_lead',
    )
    assert.equal(
      resolveContactRelationship({}, 'new_lead'),
      'new_lead',
    )
    assert.equal(
      resolveContactRelationship(
        { sender: { relationship_status: 'customer' } },
        'new_lead',
      ),
      'existing_customer',
    )
    assert.equal(
      resolveContactRelationship({}, 'existing_customer'),
      'existing_customer',
    )
    assert.equal(CONTACT_RELATIONSHIP_FACT, 'drLeticiaContactRelationship')
  })

  test('closes a persisted new lead after several turns and never closes an existing customer', () => {
    const longConversation = [
      { role: 'user' as const, content: 'Oi' },
      { role: 'assistant' as const, content: 'Como posso ajudar?' },
      { role: 'user' as const, content: 'Quero explicar aos poucos.' },
      { role: 'assistant' as const, content: 'Tudo bem.' },
      { role: 'user' as const, content: 'Ainda estou separando os dados.' },
      { role: 'assistant' as const, content: 'Certo.' },
      {
        role: 'user' as const,
        content:
          'Tenho 61 anos e quero saber se posso me aposentar com minhas contribui\u00e7\u00f5es.',
      },
    ]
    const newLeadReply = ensureDrLeticiaNewLeadClosing(
      'Precisamos conferir seu hist\u00f3rico contributivo e as regras aplic\u00e1veis.',
      { conversation: longConversation, isNewLead: true },
    )
    assert.equal(drLeticiaResponseIncludesNewLeadClosing(newLeadReply), true)

    const existingCustomerReply = ensureDrLeticiaNewLeadClosing(
      `Vamos conferir a nova informa\u00e7\u00e3o. ${DR_LETICIA_NEW_LEAD_CLOSING}`,
      { conversation: longConversation, isNewLead: false },
    )
    assert.equal(
      drLeticiaResponseIncludesNewLeadClosing(existingCustomerReply),
      false,
    )
    assert.equal(existingCustomerReply, 'Vamos conferir a nova informa\u00e7\u00e3o.')
  })

  test('does not use the new-lead closing for a greeting or isolated CNIS how-to', () => {
    const greeting = ensureDrLeticiaNewLeadClosing(
      `${DR_LETICIA_PUBLIC_INTRO} Como posso ajudar você hoje?`,
      {
        conversation: [{ role: 'user', content: 'Oi' }],
        isNewLead: true,
      },
    )
    assert.equal(drLeticiaResponseIncludesNewLeadClosing(greeting), false)

    const cnisFlow = [
      { role: 'user' as const, content: 'Uma advogada me pediu meu CNIS?' },
      {
        role: 'assistant' as const,
        content: 'Também sou advogada e posso orientar sobre o CNIS.',
      },
      { role: 'user' as const, content: 'Como consigo?' },
    ]
    const operationalReply = ensureDrLeticiaNewLeadClosing(
      buildDrLeticiaPriorityResponse(cnisFlow) ?? '',
      { conversation: cnisFlow, isNewLead: true },
    )
    assert.equal(drLeticiaResponseIncludesNewLeadClosing(operationalReply), false)
  })

  test('replaces generic new-lead empathy with demonstrated case understanding', () => {
    const response = ensureDrLeticiaNewLeadClosing(
      `Sinto muito pela situação. ${DR_LETICIA_NEW_LEAD_CLOSING}`,
      {
        conversation: [
          {
            role: 'user',
            content:
              'Fui demitida ontem e a empresa deixou salários atrasados. Preciso de orientação.',
          },
        ],
        isNewLead: true,
      },
    )

    assert.match(response, /demissão/u)
    assert.match(response, /salários atrasados/u)
    assert.match(response, /equipe analisará seu caso/u)
  })

  test('answers an eligibility question before any new-lead triage question', () => {
    const response = ensureDrLeticiaNewLeadClosing(
      'Você pode enviar seu CNIS atualizado?',
      {
        conversation: [
          {
            role: 'user',
            content:
              'Tenho 59 anos e contribuições como CLT e autônoma. Quero saber se já posso me aposentar.',
          },
        ],
        isNewLead: true,
      },
    )

    assert.match(response, /^Para confirmar se você já pode se aposentar/u)
    assert.doesNotMatch(response, /\?/u)
    assert.match(response, /equipe analisará seu caso/u)
  })

  test('silently removes a negative credential warning and keeps the useful document reply', () => {
    assert.equal(
      normalizeDrPaulaResponse(
        'Não é necessário me enviar essa senha. Recebi o CNIS e a carta do benefício.',
      ),
      'Recebi o CNIS e a carta do benefício.',
    )
    assert.equal(
      normalizeDrPaulaResponse(
        'Evite compartilhar informações sensíveis por aqui. Recebi seu CNIS.',
      ),
      'Recebi seu CNIS.',
    )
    assert.equal(
      normalizeDrPaulaResponse(
        'Sua senha do Meu INSS é exemplo123. Recebi a carta do benefício.',
      ),
      'Recebi a carta do benefício.',
    )
    assert.equal(
      normalizeDrPaulaResponse('Apague isso e exclua o que enviou.'),
      'Pode enviar seus dados e documentos por aqui; vou organizá-los para a análise.',
    )

    const priorityReply = buildDrLeticiaPriorityResponse([
      {
        role: 'user',
        content:
          'Minha senha do Meu INSS é exemplo123. Também tenho o CNIS e a carta do benefício.',
      },
    ])
    assert.match(priorityReply ?? '', /CNIS e a carta do benefício/u)
    assert.match(priorityReply ?? '', /concedido ou negado/u)
    assert.doesNotMatch(priorityReply ?? '', /senha|exemplo123/u)
  })

  test('redacts credentials before provider use without redacting case data', () => {
    const sanitized = redactCredentialsFromText(
      'Meu CPF é 123.456.789-00, a senha do Meu INSS é exemplo123 e o token: 654321.',
    )
    assert.match(sanitized, /123\.456\.789-00/)
    assert.doesNotMatch(sanitized, /exemplo123|654321/)
    assert.match(sanitized, /\[credencial omitida\]/)
  })

  test('redacts complete credential values containing dots or spaces', () => {
    for (const sample of [
      'senha: abc.def',
      'senha: abc def',
      'senha do Meu INSS é abc-123.456',
      'token = 123 456',
    ]) {
      const sanitized = redactCredentialsFromText(sample)
      assert.equal(sanitized, '[credencial omitida]')
      assert.doesNotMatch(sanitized, /abc|def|123|456/)
    }

    const withCaseData = redactCredentialsFromText(
      'senha: abc def e já enviei o CNIS.',
    )
    assert.doesNotMatch(withCaseData, /abc|def/)
    assert.match(withCaseData, /CNIS/)
  })

  test('keeps the next useful question when shortening a long reply', () => {
    assert.equal(
      normalizeDrPaulaResponse(
        'Recebi seus documentos. Vou organizar o atendimento. Qual é a data da decisão?',
      ),
      'Recebi seus documentos. Qual é a data da decisão?',
    )
  })

  test('detects semantically repeated public replies', () => {
    assert.equal(
      drPaulaResponsesAreNearDuplicates(
        'Entendi, Alex: seu pedido de aposentadoria por invalidez está em andamento, com CLT. A equipe entrará em contato em breve.',
        'Com o pedido de aposentadoria por invalidez em andamento e vínculo CLT, vamos registrar o caso para a equipe retornar em breve.',
      ),
      true,
    )
    assert.equal(
      drPaulaResponsesAreNearDuplicates(
        'Qual é a sua idade?',
        'Você já tem o CNIS atualizado?',
      ),
      false,
    )
    assert.equal(
      drPaulaResponsesAreNearDuplicates(
        'Pode enviar o CNIS atualizado para conferirmos os vínculos?',
        'Pode enviar sua CTPS para conferirmos os vínculos?',
      ),
      false,
    )
  })
})

test('GET /health returns the service smoke response without external calls', async () => {
  const app = Fastify({ logger: false })
  await app.register(healthRoute)

  try {
    const response = await app.inject({ method: 'GET', url: '/health' })

    assert.equal(response.statusCode, 200)
    assert.deepEqual(response.json(), { status: 'ok', version: '1.0.0' })
  } finally {
    await app.close()
  }
})
