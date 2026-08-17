import OpenAI from 'openai'
import {
  buildDrPaulaMessages,
  buildCustomerEvidenceText,
  buildMemorySummary,
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

const models = (
  process.env.DR_PAULA_EVAL_MODELS ??
  [
    process.env.ORCHESTRATOR_DR_PAULA_LLM_MODEL ?? 'google/gemini-3.7-flash',
    process.env.LLM_MODEL ?? 'google/gemini-3.7-flash',
    process.env.LLM_ATTENDANCE_TEST_MODEL ?? 'deepseek/deepseek-v4-flash',
  ].join(',')
)
  .split(',')
  .map((model) => model.trim())
  .filter(Boolean)

const allScenarios = [
  {
    id: 'saudacao',
    conversation: [{ role: 'user', content: 'Boa tarde' }],
  },
  {
    id: 'invalidez_contexto_curto',
    conversation: [
      {
        role: 'user',
        content:
          'Tenho um pedido de aposentadoria por invalidez em andamento e uma doença grave.',
      },
      { role: 'assistant', content: 'Você trabalha ou trabalhou como CLT?' },
      { role: 'user', content: 'CLT' },
      { role: 'assistant', content: 'Há quanto tempo você contribui?' },
      { role: 'user', content: 'Tenho alguns anos.' },
    ],
  },
  {
    id: 'documentos_e_cpf',
    conversation: [
      {
        role: 'assistant',
        content: 'Pode enviar os documentos que você já tem.',
      },
      {
        role: 'user',
        content:
          'Estou enviando meu CNIS, RG, CPF 123.456.789-00 e os laudos como você orientou.',
      },
    ],
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
  },
  {
    id: 'resposta_ok_sem_repetir',
    conversation: [
      {
        role: 'assistant',
        content:
          'Entendi seu pedido em andamento e o vínculo CLT. Você já tem o CNIS atualizado?',
      },
      { role: 'user', content: 'Ok' },
    ],
  },
  {
    id: 'prazo_urgente',
    conversation: [
      {
        role: 'user',
        content:
          'Meu benefício foi negado e faltam cinco dias para o prazo. Tenho a decisão e o CNIS.',
      },
    ],
  },
]
const requestedScenarioIds = (process.env.DR_PAULA_EVAL_SCENARIOS ?? '')
  .split(',')
  .map((scenario) => scenario.trim())
  .filter(Boolean)
const scenarios =
  requestedScenarioIds.length > 0
    ? allScenarios.filter((scenario) => requestedScenarioIds.includes(scenario.id))
    : allScenarios

const forbiddenPattern =
  /(?:\bapag\w*|\bexclu\w*|\b(?:senha|pin|token|c[oó]digo\s+de\s+autentica[cç][aã]o)\b|\b(?:n[aã]o|nunca|jamais|evite)\b.{0,90}\b(?:envi\w*|mand\w*|pass\w*|compartilh\w*|registr\w*)|canal\s+(?:in)?seguro|correct\s+format\s+needed|오류|\{\s*"response")/iu

function metrics(response) {
  return {
    characters: response?.length ?? 0,
    questions: (response?.match(/\?/g) ?? []).length,
    withinLimit: Boolean(response && response.length <= 240),
    forbidden: forbiddenPattern.test(response ?? ''),
    valid: Boolean(response),
  }
}

async function runScenario(model, scenario) {
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
    max_tokens: 700,
    ...sampling,
  })
  const raw = completion.choices[0]?.message?.content ?? ''
  const response = normalizeDrPaulaResponse(raw)

  return {
    scenario: scenario.id,
    response,
    metrics: metrics(response),
    finishReason: completion.choices[0]?.finish_reason,
  }
}

if (!process.env.LLM_API_KEY) {
  throw new Error('LLM_API_KEY is required')
}

const report = []
for (const model of models) {
  const modelReport = await Promise.all(
    scenarios.map(async (scenario) => {
      try {
        return {
          model,
          ...(await runScenario(model, scenario)),
        }
      } catch (error) {
        return {
          model,
          scenario: scenario.id,
          error: error instanceof Error ? error.message : String(error),
        }
      }
    }),
  )
  report.push(...modelReport)
}

console.log(JSON.stringify(report, null, 2))
