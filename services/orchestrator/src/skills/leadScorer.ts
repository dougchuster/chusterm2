export interface LeadScorerInput {
  contactId: string
  accountId: number
  fitAttributes: Record<string, unknown> // job title, company size, segment
  engagementEvents: Array<{ type: string; count: number; lastAt: string }>
  intentSignals: string[]
}

export interface LeadScorerOutput {
  fitScore: number
  engagementScore: number
  intentScore: number
  total: number
  factors: Array<{ name: string; contribution: number }>
}

// ─── Fit scoring (0–40) ───────────────────────────────────────────────────────
// Deterministic heuristics based on fitAttributes keys and values.

const HIGH_VALUE_TITLES = new Set([
  'ceo',
  'cto',
  'coo',
  'cfo',
  'director',
  'head',
  'vp',
  'president',
  'owner',
  'founder',
  'partner',
])

const SMALL_SIZE_LABELS = new Set(['1-10', 'micro', 'solo', 'individual'])
const MEDIUM_SIZE_LABELS = new Set(['11-50', '51-200', 'small', 'medium'])
const LARGE_SIZE_LABELS = new Set(['201-500', '501-1000', '1001+', 'large', 'enterprise', 'corporation'])

function scoreFit(attrs: Record<string, unknown>): {
  score: number
  factors: Array<{ name: string; contribution: number }>
} {
  const factors: Array<{ name: string; contribution: number }> = []
  let score = 0

  // Job title (up to 20 pts)
  const title = String(attrs.jobTitle ?? attrs.job_title ?? attrs.role ?? '').toLowerCase()
  if (title) {
    const words = title.split(/\s+/)
    const isSenior = words.some((w) => HIGH_VALUE_TITLES.has(w))
    const titleScore = isSenior ? 20 : 10
    score += titleScore
    factors.push({ name: 'job_title', contribution: titleScore })
  }

  // Company size (up to 12 pts)
  const size = String(attrs.companySize ?? attrs.company_size ?? attrs.size ?? '').toLowerCase()
  if (size) {
    let sizeScore = 0
    if (LARGE_SIZE_LABELS.has(size)) sizeScore = 12
    else if (MEDIUM_SIZE_LABELS.has(size)) sizeScore = 8
    else if (SMALL_SIZE_LABELS.has(size)) sizeScore = 4
    else sizeScore = 6 // unknown size gets a neutral score
    score += sizeScore
    factors.push({ name: 'company_size', contribution: sizeScore })
  }

  // Segment match (up to 8 pts) — any non-empty segment counts
  const segment = String(attrs.segment ?? attrs.industry ?? '').toLowerCase()
  if (segment) {
    const segmentScore = 8
    score += segmentScore
    factors.push({ name: 'segment', contribution: segmentScore })
  }

  return { score: Math.min(40, score), factors }
}

// ─── Engagement scoring (0–35) ────────────────────────────────────────────────

const EVENT_WEIGHTS: Record<string, number> = {
  email_open: 1,
  email_click: 3,
  page_view: 1,
  form_submit: 8,
  demo_request: 10,
  chat_message: 2,
  whatsapp_message: 2,
  call: 5,
  meeting: 8,
  document_view: 3,
}

function scoreEngagement(events: Array<{ type: string; count: number; lastAt: string }>): {
  score: number
  factors: Array<{ name: string; contribution: number }>
} {
  const factors: Array<{ name: string; contribution: number }> = []
  let rawScore = 0

  for (const event of events) {
    const weight = EVENT_WEIGHTS[event.type] ?? 1
    const contribution = Math.min(weight * event.count, weight * 5) // cap per event type at 5x base
    rawScore += contribution
    factors.push({ name: `event_${event.type}`, contribution: contribution })
  }

  // Recency bonus: if any event occurred in the last 7 days, add 5 pts
  const now = Date.now()
  const sevenDaysMs = 7 * 24 * 60 * 60 * 1000
  const hasRecentEvent = events.some((e) => {
    const ts = new Date(e.lastAt).getTime()
    return !isNaN(ts) && now - ts <= sevenDaysMs
  })
  if (hasRecentEvent) {
    rawScore += 5
    factors.push({ name: 'recency_bonus', contribution: 5 })
  }

  return { score: Math.min(35, rawScore), factors }
}

// ─── Intent scoring (0–25) ────────────────────────────────────────────────────

const HIGH_INTENT_KEYWORDS = new Set([
  'buy',
  'purchase',
  'enroll',
  'register',
  'matricular',
  'comprar',
  'contratar',
  'assinar',
  'quero',
  'interesse',
  'demo',
  'trial',
  'price',
  'preço',
  'proposta',
  'quote',
  'urgent',
  'urgente',
  'agora',
  'now',
])

const MEDIUM_INTENT_KEYWORDS = new Set([
  'learn',
  'aprender',
  'conhecer',
  'saber',
  'informação',
  'information',
  'how',
  'como',
  'compare',
  'versus',
  'opção',
  'option',
  'consider',
  'considerar',
])

function scoreIntent(signals: string[]): {
  score: number
  factors: Array<{ name: string; contribution: number }>
} {
  const factors: Array<{ name: string; contribution: number }> = []
  let score = 0

  for (const signal of signals) {
    const lower = signal.toLowerCase()
    if (HIGH_INTENT_KEYWORDS.has(lower)) {
      score += 8
      factors.push({ name: `high_intent_signal_${lower}`, contribution: 8 })
    } else if (MEDIUM_INTENT_KEYWORDS.has(lower)) {
      score += 4
      factors.push({ name: `medium_intent_signal_${lower}`, contribution: 4 })
    } else {
      score += 2
      factors.push({ name: `intent_signal_${lower}`, contribution: 2 })
    }
  }

  return { score: Math.min(25, score), factors }
}

// ─── Main export ──────────────────────────────────────────────────────────────

export async function runLeadScorer(input: LeadScorerInput): Promise<LeadScorerOutput> {
  const fit = scoreFit(input.fitAttributes)
  const engagement = scoreEngagement(input.engagementEvents)
  const intent = scoreIntent(input.intentSignals)

  const allFactors = [...fit.factors, ...engagement.factors, ...intent.factors]

  return {
    fitScore: fit.score,
    engagementScore: engagement.score,
    intentScore: intent.score,
    total: fit.score + engagement.score + intent.score,
    factors: allFactors,
  }
}
