import OpenAI from 'openai'
import {
  DR_LETICIA_NEW_LEAD_CLOSING,
  buildCustomerEvidenceText,
  buildDrLeticiaPriorityResponse,
  buildDrPaulaMessages,
  buildMemorySummary,
  drLeticiaResponseIncludesNewLeadClosing,
  ensureDrLeticiaNewLeadClosing,
  extractPrevidenciarioTriage,
  normalizeDrPaulaResponse,
  retrieveDrPaulaKnowledge,
  scorePrevidenciarioLead,
} from '../dist/agents/drPaulaMatos.js'

const client = new OpenAI({
  apiKey: process.env.LLM_API_KEY ?? '',
  baseURL: process.env.LLM_BASE_URL ?? 'https://openrouter.ai/api/v1',
  timeout: Number(process.env.LLM_TIMEOUT_MS ?? 60_000),
})

const models = Array.from(
  new Set(
    (
      process.env.DR_PAULA_EVAL_MODELS ??
      [
        process.env.ORCHESTRATOR_DRA_LETICIA_LLM_MODEL ??
          process.env.ORCHESTRATOR_DR_PAULA_LLM_MODEL ??
          'anthropic/claude-sonnet-5',
        process.env.LLM_MODEL ?? 'google/gemini-3.7-flash',
        process.env.LLM_ATTENDANCE_TEST_MODEL ??
          'deepseek/deepseek-v4-flash',
      ].join(',')
    )
      .split(',')
      .map((model) => model.trim())
      .filter(Boolean),
  ),
)

const runsPerScenario = Number(process.env.DR_PAULA_EVAL_RUNS ?? 3)
if (!Number.isInteger(runsPerScenario) || runsPerScenario < 2) {
  throw new Error('DR_PAULA_EVAL_RUNS must be an integer greater than or equal to 2')
}

function normalized(value) {
  return (value ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim()
}

function semanticNoticeCount(response) {
  const canonical = normalized(DR_LETICIA_NEW_LEAD_CLOSING)
  const text = normalized(response)
  let count = 0
  let offset = 0
  while ((offset = text.indexOf(canonical, offset)) >= 0) {
    count += 1
    offset += canonical.length
  }
  return count
}

const scenarios = [
  {
    id: 'saudacao_identidade',
    conversation: [{ role: 'user', content: 'Boa tarde' }],
    isNewLead: true,
    semanticChecks(response) {
      const text = normalized(response)
      return [
        {
          name: 'identidade_dra_leticia_advogada',
          pass:
            text.includes('dra. leticia') &&
            text.includes('advogada') &&
            text.includes('atendimento inicial') &&
            text.includes('dra. paula matos'),
        },
        {
          name: 'pergunta_como_ajudar',
          pass: /como posso (?:te )?ajudar/.test(text),
        },
        { name: 'sem_encerramento_de_lead', pass: semanticNoticeCount(response) === 0 },
      ]
    },
  },
  {
    id: 'pergunta_direta_o_que_e_cnis',
    conversation: [{ role: 'user', content: 'O que é o CNIS?' }],
    isNewLead: true,
    semanticChecks(response) {
      const text = normalized(response)
      return [
        {
          name: 'responde_definicao',
          pass:
            /\bextrato\b/.test(text) &&
            /\b(?:vinculo|remuneracao|contribuicao|trabalho)\w*\b/.test(text),
        },
        {
          name: 'nao_troca_resposta_por_triagem',
          pass: !/\b(?:qual e sua idade|envie seu cpf|voce e clt)\b/.test(text),
        },
      ]
    },
  },
  {
    id: 'cnis_advogada_pediu',
    conversation: [
      { role: 'user', content: 'Uma advogada me pediu meu CNIS?' },
    ],
    isNewLead: true,
    semanticChecks(response) {
      const text = normalized(response)
      return [
        {
          name: 'tambem_e_advogada',
          pass: text.includes('tambem sou advogada'),
        },
        {
          name: 'oferece_orientacao_cnis',
          pass:
            text.includes('cnis') &&
            /\b(?:orientar|ajudar|resolver)\b/.test(text),
        },
        { name: 'nao_pede_cpf', pass: !/\bcpf\b/.test(text) },
        { name: 'sem_triagem_automatica', pass: semanticNoticeCount(response) === 0 },
      ]
    },
  },
  {
    id: 'cnis_como_conseguir_contextual',
    conversation: [
      { role: 'user', content: 'Uma advogada me pediu meu CNIS?' },
      {
        role: 'assistant',
        content:
          'Também sou advogada e posso orientar você sobre o CNIS. Posso ajudar a obter e organizar esse documento.',
      },
      { role: 'user', content: 'Preciso saber como conseguir?' },
    ],
    isNewLead: true,
    semanticChecks(response) {
      const text = normalized(response)
      return [
        { name: 'indica_meu_inss', pass: text.includes('meu inss') },
        {
          name: 'indica_app_ou_site',
          pass: /\baplicativo\b/.test(text) && /\bsite\b/.test(text),
        },
        { name: 'indica_gov_br', pass: text.includes('gov.br') },
        {
          name: 'indica_extrato_cnis',
          pass: text.includes('extrato de contribuicoes') && text.includes('cnis'),
        },
        { name: 'nao_pede_cpf_ou_triagem', pass: !/\bcpf\b|\?/.test(text) },
      ]
    },
  },
  {
    id: 'cnis_agradecimento_encerra',
    conversation: [
      { role: 'user', content: 'Uma advogada me pediu meu CNIS?' },
      {
        role: 'assistant',
        content:
          'Também sou advogada e posso orientar você sobre o CNIS. Posso ajudar a obter e organizar esse documento.',
      },
      { role: 'user', content: 'Como consigo?' },
      {
        role: 'assistant',
        content:
          'Você pode obter o CNIS pelo aplicativo ou site Meu INSS, usando sua conta gov.br, na opção "Extrato de Contribuições (CNIS)".',
      },
      { role: 'user', content: 'Obrigada me ajudou' },
    ],
    isNewLead: true,
    semanticChecks(response) {
      const text = normalized(response)
      return [
        {
          name: 'despedida_gentil',
          pass: /\b(?:feliz|disponha|ajudar|ajudado)\b/.test(text),
        },
        {
          name: 'sem_retomada_de_triagem',
          pass:
            !/\?|\b(?:cpf|idade|documento|equipe|analise|contato|cnis)\b/.test(
              text,
            ),
        },
      ]
    },
  },
  {
    id: 'novo_lead_previdenciario',
    conversation: [
      {
        role: 'user',
        content:
          'Tenho 59 anos, trabalhei como CLT e contribuí também como autônoma. Quero saber se já posso me aposentar.',
      },
    ],
    isNewLead: true,
    semanticChecks(response) {
      const text = normalized(response)
        .replace(normalized(DR_LETICIA_NEW_LEAD_CLOSING), '')
        .replace(
          'sou a dra. leticia, advogada responsavel pelo atendimento inicial da dra. paula matos.',
          '',
        )
        .trim()
      return [
        {
          name: 'responde_antes_do_encerramento',
          pass:
            text.length >= 20 &&
            /\b(?:aposent|cnis|analis|avali|confer|checar|regra|historico|contribui|tempo|possivel|confirm)\w*\b/.test(
              text,
            ),
        },
        {
          name: 'informa_analise_e_contato',
          pass: drLeticiaResponseIncludesNewLeadClosing(response),
        },
        {
          name: 'encerramento_exatamente_uma_vez',
          pass: semanticNoticeCount(response) === 1,
        },
      ]
    },
  },
  {
    id: 'novo_lead_outra_area',
    conversation: [
      {
        role: 'user',
        content:
          'Fui demitida ontem e a empresa deixou salários atrasados. Preciso de orientação sobre meu caso.',
      },
    ],
    isNewLead: true,
    semanticChecks(response) {
      const text = normalized(response)
        .replace(normalized(DR_LETICIA_NEW_LEAD_CLOSING), '')
        .replace(
          'sou a dra. leticia, advogada responsavel pelo atendimento inicial da dra. paula matos.',
          '',
        )
        .trim()
      return [
        {
          name: 'acolhe_sem_forcar_previdenciario',
          pass:
            !/\b(?:cnis|aposentadoria|meu inss)\b/.test(text) &&
            /\b(?:demiss|trabalh|empresa|salario|verba|caso|orient)\w*\b/.test(
              text,
            ),
        },
        {
          name: 'informa_analise_e_contato_uma_vez',
          pass:
            drLeticiaResponseIncludesNewLeadClosing(response) &&
            semanticNoticeCount(response) === 1,
        },
      ]
    },
  },
  {
    id: 'documentos_ja_enviados',
    conversation: [
      {
        role: 'assistant',
        content: 'Pode enviar os documentos que você já tem.',
      },
      {
        role: 'user',
        content:
          'Estou enviando meu CNIS, RG e os laudos como você orientou.',
      },
    ],
    isNewLead: false,
    semanticChecks(response) {
      const text = normalized(response)
      return [
        {
          name: 'reconhece_documentos_disponiveis',
          pass:
            /\b(?:receb\w*|agradeco (?:o|pelo) envio)\b/.test(text) ||
            (text.includes('cnis') && /\b(?:laudo|documento)\w*\b/.test(text)),
        },
        {
          name: 'nao_pede_novamente_o_que_foi_enviado',
          pass: !/\b(?:envie|mandar|pode enviar)\b.{0,45}\b(?:cnis|laudo)\b/.test(
            text,
          ),
        },
      ]
    },
  },
  {
    id: 'credencial_espontanea',
    conversation: [
      {
        role: 'user',
        content:
          'Minha senha do Meu INSS é exemplo123. Também tenho o CNIS e a carta do benefício.',
      },
    ],
    isNewLead: false,
    semanticChecks(response) {
      const text = normalized(response)
      return [
        {
          name: 'aproveita_documentos_sem_repetir_credencial',
          pass:
            (text.includes('documentos') ||
              (text.includes('cnis') && text.includes('carta'))) &&
            !/\b(?:senha|exemplo123|token|pin)\b/.test(text),
        },
      ]
    },
  },
  {
    id: 'encerramento_ja_enviado_nao_repete',
    conversation: [
      {
        role: 'user',
        content: 'Tenho um pedido de aposentadoria negado e quero uma análise.',
      },
      {
        role: 'assistant',
        content:
          'Entendi a negativa. A equipe analisará seu caso e entrará em contato em breve.',
      },
      { role: 'user', content: 'Também tenho a decisão e meu CNIS.' },
    ],
    isNewLead: true,
    closingAlreadySent: true,
    semanticChecks(response) {
      return [
        {
          name: 'nao_repete_analise_e_contato',
          pass:
            semanticNoticeCount(response) === 0 &&
            !drLeticiaResponseIncludesNewLeadClosing(response),
        },
      ]
    },
  },
]

const requestedScenarioIds = (process.env.DR_PAULA_EVAL_SCENARIOS ?? '')
  .split(',')
  .map((scenario) => scenario.trim())
  .filter(Boolean)
const selectedScenarios =
  requestedScenarioIds.length > 0
    ? scenarios.filter((scenario) => requestedScenarioIds.includes(scenario.id))
    : scenarios

if (
  requestedScenarioIds.length > 0 &&
  selectedScenarios.length !== new Set(requestedScenarioIds).size
) {
  const known = new Set(selectedScenarios.map((scenario) => scenario.id))
  const unknown = requestedScenarioIds.filter((id) => !known.has(id))
  throw new Error(`Unknown DR_PAULA_EVAL_SCENARIOS: ${unknown.join(', ')}`)
}

const forbiddenPattern =
  /(?:\bapag\w*|\bexclu\w*|\b(?:senha|pin|token|c[oó]digo\s+de\s+autentica[cç][aã]o)\b|\b(?:n[aã]o|nunca|jamais|evite)\b.{0,90}\b(?:envi\w*|mand\w*|pass\w*|compartilh\w*|registr\w*)|canal\s+(?:in)?seguro|correct\s+format\s+needed|오류|\{\s*"response")/iu

function globalChecks(response) {
  const text = normalized(response)
  return [
    { name: 'resposta_valida', pass: Boolean(response) },
    {
      name: 'limite_240_caracteres',
      pass: Boolean(response && response.length <= 240),
    },
    {
      name: 'no_maximo_uma_pergunta',
      pass: (response?.match(/\?/g) ?? []).length <= 1,
    },
    {
      name: 'sem_conteudo_proibido',
      pass: !forbiddenPattern.test(response ?? ''),
    },
    { name: 'sem_capitao_publico', pass: !/\bcapitao\b/.test(text) },
    {
      name: 'nunca_se_apresenta_como_dra_paula',
      pass: !/\b(?:sou|aqui e)\s+(?:a\s+)?dra\.?\s+paula matos\b/.test(
        text,
      ),
    },
    {
      name: 'sem_identidade_antiga_de_assistente',
      pass: !/\bassistente\s+(?:virtual|automatizada|de atendimento)\b/.test(
        text,
      ),
    },
  ]
}

async function runScenario(model, scenario, run) {
  const fullText = buildCustomerEvidenceText(scenario.conversation)
  const triage = extractPrevidenciarioTriage({ text: fullText })
  const latestMessage = [...scenario.conversation]
    .reverse()
    .find((message) => message.role === 'user')?.content
  const score = scorePrevidenciarioLead({
    triage,
    latestMessage,
    messageCount: scenario.conversation.length,
  })
  const memorySummary = buildMemorySummary(triage, score)
  const retrievedDocuments = retrieveDrPaulaKnowledge(
    `${latestMessage ?? ''}\n${memorySummary}`,
  )

  let raw = buildDrLeticiaPriorityResponse(scenario.conversation)
  let finishReason = 'deterministic_policy'
  let source = 'deterministic_policy'

  if (!raw) {
    const messages = buildDrPaulaMessages({
      conversation: scenario.conversation,
      memorySummary,
      triage,
      score,
      retrievedDocuments,
    })
    const sampling = model.includes('claude-sonnet-5')
      ? {}
      : { temperature: 0.35 }
    const completion = await client.chat.completions.create({
      model,
      messages,
      max_tokens: 2048,
      ...sampling,
    })
    raw = completion.choices[0]?.message?.content ?? ''
    finishReason = completion.choices[0]?.finish_reason ?? 'unknown'
    source = 'llm'
  }

  const normalizedResponse = normalizeDrPaulaResponse(raw)
  const response = normalizedResponse
    ? ensureDrLeticiaNewLeadClosing(normalizedResponse, {
        conversation: scenario.conversation,
        closingAlreadySent: scenario.closingAlreadySent,
        isNewLead: scenario.isNewLead,
      })
    : null
  const checks = [
    ...globalChecks(response),
    ...scenario.semanticChecks(response ?? ''),
  ]

  return {
    model,
    scenario: scenario.id,
    run,
    source,
    response,
    passed: checks.every((check) => check.pass),
    checks,
    finishReason,
  }
}

if (!process.env.LLM_API_KEY) {
  throw new Error('LLM_API_KEY is required')
}
if (models.length === 0) {
  throw new Error('At least one evaluation model is required')
}

const report = []
for (const model of models) {
  for (let run = 1; run <= runsPerScenario; run += 1) {
    const runReport = await Promise.all(
      selectedScenarios.map(async (scenario) => {
        try {
          return await runScenario(model, scenario, run)
        } catch (error) {
          return {
            model,
            scenario: scenario.id,
            run,
            passed: false,
            error: error instanceof Error ? error.message : String(error),
          }
        }
      }),
    )
    report.push(...runReport)
  }
}

const failed = report.filter((result) => result.passed !== true)
const summary = {
  models,
  scenarios: selectedScenarios.map((scenario) => scenario.id),
  runsPerScenario,
  executions: report.length,
  passed: report.length - failed.length,
  failed: failed.length,
  passRate: report.length === 0 ? 0 : (report.length - failed.length) / report.length,
  gate: failed.length === 0 ? 'passed' : 'failed',
}

console.log(JSON.stringify({ summary, report }, null, 2))
if (failed.length > 0) process.exitCode = 1
