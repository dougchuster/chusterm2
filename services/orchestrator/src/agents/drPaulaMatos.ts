export const DR_PAULA_MATOS_SLUG = 'dr-paula-matos'
export const DR_PAULA_MATOS_CAMPAIGN = 'planejamento-previdenciario'
export const DR_PAULA_MATOS_SCORE_MODEL = 'previdenciario-planejamento-v1'

export interface AgentMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

export interface KnowledgeDocument {
  id: string
  title: string
  source: string
  sourceUrl: string
  type: 'rag' | 'faq' | 'guardrail'
  tags: string[]
  content: string
  priority: number
}

export interface PrevidenciarioTriageSnapshot {
  objective:
    | 'pedir_agora'
    | 'planejar_antecedencia'
    | 'corrigir_cnis'
    | 'avaliar_contribuicoes'
    | 'comparar_regras'
    | 'revisar_beneficio'
    | 'pedido_negado'
    | 'nao_identificado'
  contributionProfile: string[]
  inssStatus:
    | 'sem_pedido'
    | 'pedido_em_analise'
    | 'pedido_negado'
    | 'beneficio_concedido_duvida'
    | 'simulacao_meu_inss'
    | 'nao_informado'
  concerns: string[]
  documentsMentioned: string[]
  urgencyFlags: string[]
  keyFacts: string[]
  missingFields: string[]
  suggestedQuestions: string[]
  lastUpdatedAt: string
}

export interface PrevidenciarioScoreOutput {
  model: {
    key: string
    agentSlug: string
    campaignSlug: string
    sector: string
    version: string
  }
  fitScore: number
  riskScore: number
  documentScore: number
  intentScore: number
  engagementScore: number
  total: number
  classification: 'prioridade_maxima' | 'qualificado' | 'nutrir' | 'baixa_informacao'
  factors: Array<{ name: string; contribution: number; evidence?: string }>
  handoff: {
    recommended: boolean
    reasons: string[]
  }
  nextBestAction: string
}

const SIMPLE_DOCUMENT_REQUEST =
  'Para adiantar a análise pela equipe responsável, se você tiver fácil, já pode separar ou enviar apenas o que for simples e seguro pelo canal atual: CNIS atualizado, simulação do Meu INSS, CTPS ou comprovantes GPS/DAS/carnê, e, se houver, carta de exigência, indeferimento ou concessão. Não envie CPF completo nem documentos sensíveis por canal inseguro; se necessário, a equipe indicará o canal adequado.'

const COIMBRA_PAGE_URL = 'https://planejamento.coimbraeruas.com.br/'
const INSS_PRE_REQUEST_URL =
  'https://www.gov.br/inss/pt-br/noticias/aposentadoria-o-que-pode-ser-conferido-no-meu-inss-antes-de-fazer-o-pedido'
const INSS_SIMULATION_URL =
  'https://www.gov.br/inss/pt-br/noticias/nao-perca-as-contas-inss-oferece-calculadora-para-simulacao-de-aposentadoria'
const INSS_CNIS_URL =
  'https://www.gov.br/inss/pt-br/noticias/saiba-como-consultar-extratos-de-contribuicoes-pelo-site-ou-aplicativo-meu-inss'
const INSS_CONTRIBUTION_URL =
  'https://www.gov.br/inss/pt-br/direitos-e-deveres/inscricao-e-contribuicao/contribuicao-dos-segurados-facultativo-e-contribuinte-individual'

export const DR_PAULA_MATOS_KNOWLEDGE: KnowledgeDocument[] = [
  {
    id: 'campanha-posicionamento',
    title: 'Planejamento previdenciário antes do protocolo',
    source: 'Coimbra & Ruas',
    sourceUrl: COIMBRA_PAGE_URL,
    type: 'rag',
    tags: ['planejamento', 'diagnóstico', 'protocolo', 'aposentadoria'],
    priority: 10,
    content:
      'A campanha posiciona a consultoria como diagnóstico antes da decisão: analisar CNIS, regra escolhida e forma de contribuir antes de protocolar, esperar ou pagar nova guia. O foco é decidir com documentos, não com achismo. O atendimento deve ser humanizado, sem mencionar IA ou automação, e pode informar que vamos analisar o caso com atenção e entraremos com retorno em breve.',
  },
  {
    id: 'campanha-riscos',
    title: 'Riscos que a triagem deve mapear',
    source: 'Coimbra & Ruas',
    sourceUrl: COIMBRA_PAGE_URL,
    type: 'rag',
    tags: ['risco', 'cnis', 'negativa', 'exigencia', 'valor'],
    priority: 10,
    content:
      'A decisão previdenciária pode perder valor mesmo quando o benefício é aprovado. A triagem deve observar base de cálculo incompleta, regra escolhida sem comparação, contribuição sem função, pedido antes da hora, espera sem data e protocolo fraco.',
  },
  {
    id: 'campanha-metodo',
    title: 'Método de atendimento da campanha',
    source: 'Coimbra & Ruas',
    sourceUrl: COIMBRA_PAGE_URL,
    type: 'rag',
    tags: ['triagem', 'cnis', 'cenário', 'rota', 'documentos'],
    priority: 9,
    content:
      'O processo esperado é: triagem do objetivo, leitura dos dados, mapa de decisões e próximo passo claro. A resposta deve levar a uma decisão prática: pedir agora, corrigir dados, contribuir melhor, aguardar com motivo ou preparar documentos.',
  },
  {
    id: 'campanha-publico-prioritario',
    title: 'Quem mais se beneficia',
    source: 'Coimbra & Ruas',
    sourceUrl: COIMBRA_PAGE_URL,
    type: 'rag',
    tags: ['mei', 'autônomo', 'professor', 'especial', 'simulação', 'cnis'],
    priority: 8,
    content:
      'A consultoria é especialmente relevante para quem está a poucos anos da aposentadoria, contribui por conta própria, tem CNIS confuso, tem tempo especial ou de professor, recebeu simulação baixa ou quer se organizar com antecedência.',
  },
  {
    id: 'inss-conferir-cnis',
    title: 'Conferir CNIS e simulação antes do pedido',
    source: 'INSS',
    sourceUrl: INSS_PRE_REQUEST_URL,
    type: 'rag',
    tags: ['inss', 'cnis', 'meu inss', 'simulação', 'documentos'],
    priority: 9,
    content:
      'O INSS orienta que o trabalhador confira o Extrato de Contribuições (CNIS) e faça simulação no Meu INSS antes de pedir aposentadoria. Devem ser observadas datas de entrada e saída, contribuições abaixo do salário mínimo desde 2019, vínculos pendentes, períodos de regime próprio e informações divergentes ou incompletas.',
  },
  {
    id: 'inss-simulacao-nao-garante',
    title: 'Simulação do Meu INSS não garante direito',
    source: 'INSS',
    sourceUrl: INSS_SIMULATION_URL,
    type: 'guardrail',
    tags: ['simulação', 'meu inss', 'garantia', 'documentos'],
    priority: 10,
    content:
      'A calculadora do Meu INSS é um demonstrativo para consulta e não garante direito ao benefício. Quando a simulação indica requisitos, o segurado ainda precisa fazer o pedido para o INSS analisar de fato, podendo ser solicitados documentos.',
  },
  {
    id: 'inss-extrato-cnis',
    title: 'O que consta no CNIS',
    source: 'INSS',
    sourceUrl: INSS_CNIS_URL,
    type: 'rag',
    tags: ['cnis', 'vínculos', 'remunerações', 'contribuições'],
    priority: 9,
    content:
      'O extrato CNIS informa vínculos, remunerações e contribuições previdenciárias. Há extrato de relações previdenciárias, relações e remunerações, e ano civil com contribuições ano a ano a partir de 11/2019.',
  },
  {
    id: 'inss-mei-facultativo-autonomo',
    title: 'Contribuições MEI, facultativo e individual',
    source: 'INSS',
    sourceUrl: INSS_CONTRIBUTION_URL,
    type: 'rag',
    tags: ['mei', 'autônomo', 'facultativo', 'gps', 'das', 'alíquota'],
    priority: 8,
    content:
      'Contribuinte individual e facultativo recolhem via GPS, enquanto MEI recolhe pelo DAS-MEI. O INSS alerta que segurado facultativo em alíquota reduzida, contribuinte individual com alíquota reduzida e MEI não tem direito a aposentadoria por tempo de contribuição, apenas por idade, além de não ter direito a CTC nesses casos.',
  },
  {
    id: 'faq-planejamento',
    title: 'FAQ - O que é planejamento previdenciário?',
    source: 'Coimbra & Ruas',
    sourceUrl: COIMBRA_PAGE_URL,
    type: 'faq',
    tags: ['faq', 'planejamento', 'aposentadoria'],
    priority: 7,
    content:
      'Planejamento previdenciário é uma análise técnica do histórico de contribuições, CNIS, regras de aposentadoria e cenários possíveis para orientar a melhor estratégia antes de pedir o benefício ou definir contribuições futuras.',
  },
  {
    id: 'faq-documentos',
    title: 'FAQ - Documentos normalmente importantes',
    source: 'Coimbra & Ruas',
    sourceUrl: COIMBRA_PAGE_URL,
    type: 'faq',
    tags: ['faq', 'documentos', 'cnis', 'ctps', 'ppp'],
    priority: 7,
    content:
      'Os documentos dependem do caso, mas normalmente CNIS, documentos pessoais, carteira de trabalho, comprovantes de contribuição, documentos de atividade especial e registros de vínculo podem ser importantes. Para adiantar o atendimento, podem ser solicitados documentos simples: CNIS atualizado, simulação do Meu INSS, CTPS, comprovantes GPS/DAS/carnê e carta de exigência, indeferimento ou concessão quando houver. CPF completo e documentos sensíveis devem aguardar canal seguro indicado pela equipe.',
  },
]

function normalize(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
}

function unique(values: string[]): string[] {
  return Array.from(new Set(values.filter(Boolean)))
}

function hasAny(normalizedText: string, terms: string[]): boolean {
  return terms.some((term) => normalizedText.includes(normalize(term)))
}

function detectObjective(normalizedText: string): PrevidenciarioTriageSnapshot['objective'] | undefined {
  if (hasAny(normalizedText, ['indeferido', 'negado', 'negativa', 'pedido negado'])) {
    return 'pedido_negado'
  }
  if (hasAny(normalizedText, ['revisar beneficio', 'revisao', 'valor baixo', 'beneficio concedido'])) {
    return 'revisar_beneficio'
  }
  if (hasAny(normalizedText, ['cnis', 'vinculo', 'salario errado', 'indicador', 'lacuna'])) {
    return 'corrigir_cnis'
  }
  if (hasAny(normalizedText, ['mei', 'autonomo', 'facultativo', 'gps', 'das', 'codigo', 'contribuir'])) {
    return 'avaliar_contribuicoes'
  }
  if (hasAny(normalizedText, ['regra', 'comparar', 'simulacao', 'meu inss', 'quando posso'])) {
    return 'comparar_regras'
  }
  if (hasAny(normalizedText, ['dar entrada', 'protocolar', 'pedir aposentadoria', 'ja posso aposentar'])) {
    return 'pedir_agora'
  }
  if (hasAny(normalizedText, ['planejar', 'organizar', 'falta tempo', 'antecedencia'])) {
    return 'planejar_antecedencia'
  }
  return undefined
}

function detectInssStatus(
  normalizedText: string,
): PrevidenciarioTriageSnapshot['inssStatus'] | undefined {
  if (hasAny(normalizedText, ['indeferido', 'negado', 'negativa', 'pedido negado'])) {
    return 'pedido_negado'
  }
  if (hasAny(normalizedText, ['concedido', 'ja aposentei', 'recebo beneficio', 'valor do beneficio'])) {
    return 'beneficio_concedido_duvida'
  }
  if (hasAny(normalizedText, ['em analise', 'em andamento', 'aguardando analise'])) {
    return 'pedido_em_analise'
  }
  if (hasAny(normalizedText, ['simulacao', 'simulador', 'meu inss mostrou', 'data no meu inss'])) {
    return 'simulacao_meu_inss'
  }
  if (hasAny(normalizedText, ['ainda nao fiz pedido', 'nao dei entrada', 'sem pedido'])) {
    return 'sem_pedido'
  }
  return undefined
}

function detectContributionProfiles(normalizedText: string): string[] {
  const profiles: string[] = []
  const checks: Array<[string, string[]]> = [
    ['clt', ['clt', 'carteira assinada', 'empregado']],
    ['mei', ['mei', 'microempreendedor', 'das']],
    ['autonomo', ['autonomo', 'contribuinte individual']],
    ['facultativo', ['facultativo']],
    ['servidor', ['servidor', 'rpps', 'regime proprio']],
    ['professor', ['professor', 'magisterio']],
    ['atividade_especial', ['insalubre', 'perigoso', 'atividade especial', 'ppp', 'ltcat']],
    ['rural', ['rural', 'segurado especial']],
  ]

  for (const [profile, terms] of checks) {
    if (hasAny(normalizedText, terms)) profiles.push(profile)
  }

  return profiles
}

function detectDocuments(normalizedText: string): string[] {
  const documents: string[] = []
  const checks: Array<[string, string[]]> = [
    ['cnis', ['cnis', 'extrato de contribuicao']],
    ['ctps', ['ctps', 'carteira de trabalho']],
    ['gps_das_carne', ['gps', 'das', 'carne', 'guia']],
    ['simulacao_meu_inss', ['simulacao', 'simulador', 'meu inss']],
    ['carta_concessao', ['carta de concessao', 'concessao']],
    ['ppp_ltcat', ['ppp', 'ltcat', 'atividade especial']],
    ['documentos_pessoais', ['rg', 'cpf', 'documentos pessoais']],
    ['processo_inss', ['processo', 'exigencia', 'indeferimento', 'recurso']],
  ]

  for (const [document, terms] of checks) {
    if (hasAny(normalizedText, terms)) documents.push(document)
  }

  return documents
}

function detectConcerns(normalizedText: string): string[] {
  const concerns: string[] = []
  const checks: Array<[string, string[]]> = [
    ['cnis_incompleto', ['cnis incompleto', 'vinculo faltando', 'salario errado', 'indicador', 'lacuna']],
    ['simulacao_baixa', ['simulacao baixa', 'valor baixo', 'renda menor']],
    ['pedido_antes_da_hora', ['pedir antes da hora', 'dar entrada agora', 'protocolar agora']],
    ['contribuir_sem_retorno', ['contribuir sem retorno', 'pagar inss', 'codigo errado', 'aliquota']],
    ['regra_desconhecida', ['nao sei minha regra', 'qual regra', 'regra']],
    ['exigencia_negativa_atraso', ['exigencia', 'negativa', 'indeferido', 'atraso']],
    ['atividade_especial_complexa', ['atividade especial', 'insalubre', 'ppp', 'ltcat']],
    ['professor_servidor_rpps', ['professor', 'servidor', 'rpps', 'regime proprio']],
  ]

  for (const [concern, terms] of checks) {
    if (hasAny(normalizedText, terms)) concerns.push(concern)
  }

  return concerns
}

function detectUrgencyFlags(normalizedText: string): string[] {
  const flags: string[] = []
  const checks: Array<[string, string[]]> = [
    ['pedido_negado', ['indeferido', 'pedido negado', 'negativa']],
    ['exigencia_inss', ['exigencia', 'cumprir exigencia']],
    ['prazo_recurso', ['prazo', 'recurso', '30 dias', 'urgente']],
    ['pedido_em_analise', ['em analise', 'em andamento']],
    ['beneficio_suspenso', ['suspenso', 'bloqueado', 'cessado']],
    ['beneficio_concedido_com_duvida', ['concedido', 'valor baixo', 'revisar beneficio']],
  ]

  for (const [flag, terms] of checks) {
    if (hasAny(normalizedText, terms)) flags.push(flag)
  }

  return flags
}

function extractKeyFacts(text: string, previousFacts: string[] = []): string[] {
  const facts = [...previousFacts]
  const ageMatch = text.match(/\b(\d{2})\s*anos\b/i)
  if (ageMatch) facts.push(`idade_mencionada:${ageMatch[1]}`)

  const contributionYearsMatch = text.match(/\b(\d{1,2})\s*anos?(?:\s+de)?\s+contrib/i)
  if (contributionYearsMatch) facts.push(`anos_contribuicao:${contributionYearsMatch[1]}`)

  const monthsMatch = text.match(/\b(faltam?|falta)\s+(\d{1,2})\s+mes/i)
  if (monthsMatch) facts.push(`prazo_mencionado:${monthsMatch[2]} meses`)

  return unique(facts).slice(-12)
}

function buildMissingFields(triage: Omit<PrevidenciarioTriageSnapshot, 'missingFields' | 'suggestedQuestions'>): string[] {
  const missing: string[] = []
  if (triage.objective === 'nao_identificado') missing.push('objetivo')
  if (triage.contributionProfile.length === 0) missing.push('forma_contribuicao')
  if (triage.inssStatus === 'nao_informado') missing.push('situacao_inss')
  if (triage.documentsMentioned.length === 0) missing.push('documentos')
  if (triage.concerns.length === 0) missing.push('maior_preocupacao')
  return missing
}

function buildSuggestedQuestions(missingFields: string[]): string[] {
  const questions: Record<string, string> = {
    objetivo: 'Você quer pedir aposentadoria agora, planejar com antecedência, revisar CNIS ou avaliar contribuições futuras?',
    forma_contribuicao: 'Como você contribuiu ou contribui hoje: CLT, MEI, autônomo, facultativo, servidor, professor ou atividade especial?',
    situacao_inss: 'No INSS, você ainda não fez pedido, tem pedido em análise, recebeu negativa ou apenas viu uma simulação no Meu INSS?',
    documentos: 'Você já tem CNIS atualizado, CTPS, carnês/GPS/DAS ou simulação do Meu INSS para a análise?',
    maior_preocupacao: 'O que mais preocupa agora: pedir antes da hora, valor baixo, CNIS incompleto, contribuição sem retorno ou risco de exigência/negativa?',
  }

  return missingFields.map((field) => questions[field]).filter(Boolean).slice(0, 3)
}

export function extractPrevidenciarioTriage(input: {
  text: string
  previous?: Partial<PrevidenciarioTriageSnapshot> | null
  now?: Date
}): PrevidenciarioTriageSnapshot {
  const previous = input.previous ?? {}
  const normalizedText = normalize(input.text)

  const base = {
    objective: detectObjective(normalizedText) ?? previous.objective ?? 'nao_identificado',
    contributionProfile: unique([
      ...(previous.contributionProfile ?? []),
      ...detectContributionProfiles(normalizedText),
    ]),
    inssStatus: detectInssStatus(normalizedText) ?? previous.inssStatus ?? 'nao_informado',
    concerns: unique([...(previous.concerns ?? []), ...detectConcerns(normalizedText)]),
    documentsMentioned: unique([
      ...(previous.documentsMentioned ?? []),
      ...detectDocuments(normalizedText),
    ]),
    urgencyFlags: unique([...(previous.urgencyFlags ?? []), ...detectUrgencyFlags(normalizedText)]),
    keyFacts: extractKeyFacts(input.text, previous.keyFacts),
    lastUpdatedAt: (input.now ?? new Date()).toISOString(),
  }

  const missingFields = buildMissingFields(base)

  return {
    ...base,
    missingFields,
    suggestedQuestions: buildSuggestedQuestions(missingFields),
  }
}

function addFactor(
  factors: PrevidenciarioScoreOutput['factors'],
  name: string,
  contribution: number,
  evidence?: string,
): number {
  if (contribution <= 0) return 0
  factors.push({ name, contribution, evidence })
  return contribution
}

function clamp(value: number, max: number): number {
  return Math.max(0, Math.min(max, value))
}

export function scorePrevidenciarioLead(input: {
  triage: PrevidenciarioTriageSnapshot
  latestMessage?: string
  messageCount?: number
}): PrevidenciarioScoreOutput {
  const factors: PrevidenciarioScoreOutput['factors'] = []
  const { triage } = input

  let fitScore = 0
  if (triage.objective !== 'nao_identificado') {
    fitScore += addFactor(factors, 'objetivo_identificado', 8, triage.objective)
  }
  if (
    [
      'pedir_agora',
      'corrigir_cnis',
      'avaliar_contribuicoes',
      'comparar_regras',
      'pedido_negado',
      'revisar_beneficio',
    ].includes(triage.objective)
  ) {
    fitScore += addFactor(factors, 'objetivo_alinhado_planejamento', 8, triage.objective)
  }
  if (triage.contributionProfile.length > 0) {
    fitScore += addFactor(factors, 'perfil_contribuicao_identificado', 6, triage.contributionProfile.join(', '))
  }
  if (triage.contributionProfile.some((p) => ['mei', 'autonomo', 'facultativo'].includes(p))) {
    fitScore += addFactor(factors, 'contribuicao_propria_requer_estrategia', 5)
  }
  if (triage.keyFacts.some((fact) => fact.startsWith('idade_mencionada') || fact.startsWith('anos_contribuicao'))) {
    fitScore += addFactor(factors, 'tempo_ou_idade_mencionado', 3)
  }
  fitScore = clamp(fitScore, 30)

  let riskScore = 0
  if (triage.urgencyFlags.length > 0) {
    riskScore += addFactor(factors, 'flags_urgencia', Math.min(12, triage.urgencyFlags.length * 12), triage.urgencyFlags.join(', '))
  }
  if (triage.inssStatus === 'pedido_negado' || triage.objective === 'pedido_negado') {
    riskScore += addFactor(factors, 'pedido_negado_requer_revisao', 10)
  }
  if (triage.inssStatus === 'beneficio_concedido_duvida' || triage.objective === 'revisar_beneficio') {
    riskScore += addFactor(factors, 'beneficio_concedido_com_duvida', 5)
  }
  if (triage.concerns.includes('cnis_incompleto')) {
    riskScore += addFactor(factors, 'risco_cnis', 6)
  }
  if (triage.concerns.includes('contribuir_sem_retorno')) {
    riskScore += addFactor(factors, 'risco_contribuicao_sem_funcao', 4)
  }
  if (triage.concerns.includes('simulacao_baixa')) {
    riskScore += addFactor(factors, 'risco_valor_baixo', 3)
  }
  if (triage.contributionProfile.some((p) => ['atividade_especial', 'professor', 'servidor'].includes(p))) {
    riskScore += addFactor(factors, 'regra_especial_ou_rpps', 5)
  }
  riskScore = clamp(riskScore, 25)

  let documentScore = 0
  if (triage.documentsMentioned.includes('cnis')) {
    documentScore += addFactor(factors, 'cnis_mencionado', 8)
  }
  if (triage.documentsMentioned.includes('ctps')) {
    documentScore += addFactor(factors, 'ctps_mencionada', 4)
  }
  if (triage.documentsMentioned.includes('gps_das_carne')) {
    documentScore += addFactor(factors, 'comprovantes_contribuicao', 4)
  }
  if (triage.documentsMentioned.includes('simulacao_meu_inss')) {
    documentScore += addFactor(factors, 'simulacao_meu_inss', 2)
  }
  if (triage.documentsMentioned.includes('ppp_ltcat')) {
    documentScore += addFactor(factors, 'documento_atividade_especial', 4)
  }
  if (triage.documentsMentioned.includes('processo_inss')) {
    documentScore += addFactor(factors, 'processo_inss_mencionado', 4)
  }
  documentScore = clamp(documentScore, 20)

  let intentScore = 0
  const normalizedMessage = normalize(input.latestMessage ?? '')
  if (hasAny(normalizedMessage, ['quero', 'preciso', 'analisar', 'diagnostico', 'consultoria'])) {
    intentScore += addFactor(factors, 'intencao_de_analise', 6)
  }
  if (hasAny(normalizedMessage, ['falar', 'advogada', 'consulta', 'reuniao', 'atendimento'])) {
    intentScore += addFactor(factors, 'pedido_de_atendimento_humano', 5)
  }
  if (hasAny(normalizedMessage, ['valor', 'preco', 'quanto custa', 'contratar'])) {
    intentScore += addFactor(factors, 'sinal_comercial', 2)
  }
  if (triage.missingFields.length <= 2) {
    intentScore += addFactor(factors, 'triagem_quase_completa', 2)
  }
  intentScore = clamp(intentScore, 15)

  let engagementScore = 0
  const messageCount = input.messageCount ?? 1
  engagementScore += addFactor(factors, 'mensagens_na_conversa', Math.min(6, messageCount * 2), `${messageCount}`)
  if (triage.keyFacts.length > 0) {
    engagementScore += addFactor(factors, 'fatos_objetivos_informados', Math.min(4, triage.keyFacts.length * 2), triage.keyFacts.join(', '))
  }
  engagementScore = clamp(engagementScore, 10)

  const total = clamp(fitScore + riskScore + documentScore + intentScore + engagementScore, 100)
  const classification =
    total >= 80
      ? 'prioridade_maxima'
      : total >= 60
        ? 'qualificado'
        : total >= 40
          ? 'nutrir'
          : 'baixa_informacao'

  const handoffReasons = unique([
    ...(total >= 80 ? ['score_prioridade_maxima'] : []),
    ...triage.urgencyFlags,
    ...(triage.contributionProfile.some((p) => ['atividade_especial', 'professor', 'servidor'].includes(p))
      ? ['regra_especial_ou_rpps']
      : []),
    ...(triage.concerns.includes('cnis_incompleto') ? ['cnis_requer_leitura_documental'] : []),
  ])

  return {
    model: {
      key: DR_PAULA_MATOS_SCORE_MODEL,
      agentSlug: DR_PAULA_MATOS_SLUG,
      campaignSlug: DR_PAULA_MATOS_CAMPAIGN,
      sector: 'previdenciario',
      version: '1.0.0',
    },
    fitScore,
    riskScore,
    documentScore,
    intentScore,
    engagementScore,
    total,
    classification,
    factors,
    handoff: {
      recommended: handoffReasons.length > 0 && (total >= 60 || triage.urgencyFlags.length > 0),
      reasons: handoffReasons,
    },
    nextBestAction: buildNextBestAction(triage, classification, handoffReasons),
  }
}

function buildNextBestAction(
  triage: PrevidenciarioTriageSnapshot,
  classification: PrevidenciarioScoreOutput['classification'],
  handoffReasons: string[],
): string {
  if (handoffReasons.includes('pedido_negado') || handoffReasons.includes('prazo_recurso')) {
    return 'Encaminhar imediatamente para revisão da equipe jurídica responsável, com prazo, documentos e possibilidade de recurso.'
  }
  if (handoffReasons.includes('exigencia_inss')) {
    return 'Solicitar documentos simples da exigência e encaminhar para análise da equipe jurídica antes de qualquer resposta definitiva.'
  }
  if (triage.missingFields.length > 0) {
    return `Completar triagem perguntando: ${buildSuggestedQuestions(triage.missingFields).join(' ')}`
  }
  if (classification === 'prioridade_maxima' || classification === 'qualificado') {
    return 'Encaminhar para diagnóstico previdenciário com CNIS, simulação do Meu INSS e documentos simples de contribuição.'
  }
  return 'Responder à dúvida principal e coletar objetivo, forma de contribuição, situação no INSS e documentos simples existentes.'
}

function tokenSet(query: string): Set<string> {
  return new Set(
    normalize(query)
      .split(/[^a-z0-9]+/)
      .filter((token) => token.length >= 4),
  )
}

export function retrieveDrPaulaKnowledge(query: string, limit = 5): KnowledgeDocument[] {
  const tokens = tokenSet(query)
  if (tokens.size === 0) {
    return [...DR_PAULA_MATOS_KNOWLEDGE]
      .sort((a, b) => b.priority - a.priority)
      .slice(0, limit)
  }

  return DR_PAULA_MATOS_KNOWLEDGE.map((doc) => {
    const haystack = normalize(`${doc.title} ${doc.tags.join(' ')} ${doc.content}`)
    let score = doc.priority
    for (const token of tokens) {
      if (haystack.includes(token)) score += 4
      if (doc.tags.some((tag) => normalize(tag).includes(token))) score += 3
    }
    return { doc, score }
  })
    .filter(({ score }) => score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map(({ doc }) => doc)
}

export function buildMemorySummary(triage: PrevidenciarioTriageSnapshot, score: PrevidenciarioScoreOutput): string {
  return [
    `Objetivo: ${triage.objective}`,
    `Forma de contribuição: ${triage.contributionProfile.join(', ') || 'não informada'}`,
    `Situação no INSS: ${triage.inssStatus}`,
    `Documentos: ${triage.documentsMentioned.join(', ') || 'não informados'}`,
    `Preocupações: ${triage.concerns.join(', ') || 'não informadas'}`,
    `Urgência: ${triage.urgencyFlags.join(', ') || 'sem flag urgente'}`,
    `Score: ${score.total}/100 (${score.classification})`,
    `Próxima ação: ${score.nextBestAction}`,
  ].join('\n')
}

export function buildDrPaulaMessages(input: {
  conversation: AgentMessage[]
  memorySummary: string
  triage: PrevidenciarioTriageSnapshot
  score: PrevidenciarioScoreOutput
  retrievedDocuments: KnowledgeDocument[]
}): AgentMessage[] {
  const ragBlock = input.retrievedDocuments
    .map(
      (doc) =>
        `[${doc.id}] ${doc.title}\nFonte: ${doc.source} - ${doc.sourceUrl}\nConteúdo: ${doc.content}`,
    )
    .join('\n\n')

  const systemPrompt = `Você é a Dra. Paula Matos, advogada previdenciária do Coimbra & Ruas.
Sua função é fazer triagem inicial para planejamento previdenciário antes da aposentadoria.

Tom e postura:
- Seja cordial, humana, segura e objetiva.
- Conduza a conversa como atendimento humanizado do escritório. Nunca diga que é IA, robô, automação, assistente virtual ou atendimento automatizado.
- Fale sempre em português brasileiro correto, natural, com acentuação completa e gramática revisada.
- Nunca responda sem acentos, com palavras abreviadas ou com português digitado de forma incorreta.
- Evite juridiquês desnecessário.
- Faça no máximo 3 perguntas por resposta.
- Mostre critério técnico sem pressionar a pessoa.
- Quando houver medo, confusão ou urgência, acolha primeiro e organize o próximo passo.
- Quando o caso precisar de revisão, diga que vamos analisar o caso com atenção e entraremos com retorno em breve.

Limites obrigatórios:
- Não prometa aposentadoria, valor, prazo ou resultado.
- Não dê parecer jurídico definitivo sem CNIS e documentos.
- Não calcule benefício final ou regra final com base em poucas mensagens.
- Se a pessoa enviar dado sensível, oriente que documentos completos sejam enviados apenas pelo canal seguro indicado pela equipe.
- Não revele o score interno ao cliente.
- Não use expressões como "vou transferir para um humano", "sou IA", "como assistente virtual" ou similares.

Objetivo da triagem:
1. Entender se a pessoa quer pedir agora, planejar, corrigir CNIS, avaliar contribuições, comparar regras, revisar simulação, negativa ou benefício concedido.
2. Identificar forma de contribuição: CLT, MEI, autônomo, facultativo, servidor, professor, rural ou atividade especial.
3. Identificar situação no INSS: sem pedido, pedido em análise, negativa, benefício concedido com dúvida ou simulação Meu INSS.
4. Mapear documentos: CNIS, CTPS, comprovantes GPS/DAS/carnê, simulação, carta de concessão, PPP/LTCAT e documentos de vínculo.
5. Solicitar documentos simples para adiantar a análise: CNIS atualizado, simulação do Meu INSS, CTPS, comprovantes GPS/DAS/carnê e carta de exigência, indeferimento ou concessão quando houver.
6. Encaminhar para a equipe jurídica responsável quando houver prazo, exigência, negativa, CNIS crítico, atividade especial/professor/RPPS ou contribuição sem estratégia.

Documentos simples que podem ser solicitados:
${SIMPLE_DOCUMENT_REQUEST}

Memória interna da conversa:
${input.memorySummary}

Campos ainda pendentes:
${input.triage.missingFields.length > 0 ? input.triage.missingFields.join(', ') : 'triagem essencial completa'}

Score interno:
${input.score.total}/100 (${input.score.classification}). Handoff recomendado: ${input.score.handoff.recommended ? 'sim' : 'não'}.

Base de conhecimento recuperada:
${ragBlock}

Responda ao cliente com base nessa memória e na base recuperada. Antes de finalizar, revise acentuação, concordância e ortografia. Quando usar uma informação do INSS, explique em linguagem simples e sem citar longos trechos.`

  return [{ role: 'system', content: systemPrompt }, ...input.conversation]
}

export function buildDrPaulaFallbackResponse(input: {
  triage: PrevidenciarioTriageSnapshot
  retrievedDocuments: KnowledgeDocument[]
}): string {
  const intro =
    input.triage.objective === 'nao_identificado'
      ? 'Oi, eu sou a Dra. Paula Matos. Posso te ajudar a organizar essa análise previdenciária com calma.'
      : 'Entendi. Antes de qualquer protocolo ou nova contribuição, o ideal é organizar seu histórico e conferir os pontos que podem mudar prazo, regra e valor.'

  const sourceHint = input.retrievedDocuments.some((doc) => doc.id === 'inss-simulacao-nao-garante')
    ? 'A simulação do Meu INSS ajuda como ponto de partida, mas não garante o direito nem substitui a leitura dos documentos.'
    : 'O CNIS costuma ser o ponto de partida, porque mostra vínculos, remunerações e contribuições que podem alterar a decisão.'

  const questions = input.triage.suggestedQuestions
  if (questions.length === 0) {
    return `${intro}\n\n${sourceHint}\n\nPelo que você já contou, vamos analisar seu caso com atenção e entraremos com retorno em breve. ${SIMPLE_DOCUMENT_REQUEST}`
  }

  return `${intro}\n\n${sourceHint}\n\nPara eu fazer a triagem inicial, me diga por favor:\n${questions
    .map((question, index) => `${index + 1}. ${question}`)
    .join('\n')}\n\n${SIMPLE_DOCUMENT_REQUEST}`
}

export function buildPrivateTriageNote(input: {
  triage: PrevidenciarioTriageSnapshot
  score: PrevidenciarioScoreOutput
}): string {
  return [
    '[Dra. Paula Matos] Handoff recomendado',
    `Score: ${input.score.total}/100 (${input.score.classification})`,
    `Motivos: ${input.score.handoff.reasons.join(', ') || 'score/triagem'}`,
    `Objetivo: ${input.triage.objective}`,
    `Contribuição: ${input.triage.contributionProfile.join(', ') || 'não informada'}`,
    `Situação INSS: ${input.triage.inssStatus}`,
    `Documentos: ${input.triage.documentsMentioned.join(', ') || 'não informados'}`,
    `Pendências: ${input.triage.missingFields.join(', ') || 'sem pendências essenciais'}`,
    `Próxima ação: ${input.score.nextBestAction}`,
    `Documentos simples a adiantar: CNIS atualizado; simulação do Meu INSS; CTPS; comprovantes GPS/DAS/carnê; carta de exigência, indeferimento ou concessão, se houver.`,
  ].join('\n')
}
