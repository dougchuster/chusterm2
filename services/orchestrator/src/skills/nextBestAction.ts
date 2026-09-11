import { createChatCompletion, LLM_MODEL, isLlmConfigured } from '../llm/client.js'
import { UNTRUSTED_DATA_INSTRUCTION, wrapUntrustedInput } from './promptGuards.js'

export interface NextBestActionInput {
  contactId: string
  accountId: number
  dealStage: string
  daysSinceLastActivity: number
  score: number
  conversationSummary?: string
}

export interface NextBestActionOutput {
  action: string
  priority: 'high' | 'medium' | 'low'
  rationale: string
  dueInHours: number
}

const SYSTEM_PROMPT = `You are a CRM sales intelligence assistant. Based on the deal context provided, suggest the single best next action for the sales rep to take.

Respond in JSON only, with no markdown, no code fences, and no extra text.
Format: { "action": "<short imperative sentence describing what to do>", "priority": "<high|medium|low>", "rationale": "<1-2 sentence explanation>", "dueInHours": <integer, hours from now> }

${UNTRUSTED_DATA_INSTRUCTION}`

// ─── Deterministic fallback (no LLM) ─────────────────────────────────────────

function ruleBasedAction(input: NextBestActionInput): NextBestActionOutput {
  const { dealStage, daysSinceLastActivity, score } = input

  // High score + long inactivity → urgent follow-up
  if (score >= 75 && daysSinceLastActivity >= 3) {
    return {
      action: 'Send a personalized follow-up message referencing previous conversation',
      priority: 'high',
      rationale: `High-score lead (${score}) has been inactive for ${daysSinceLastActivity} days. Re-engagement is time-sensitive.`,
      dueInHours: 4,
    }
  }

  // New lead stage
  if (dealStage === 'new_lead' || dealStage === 'triage_started') {
    return {
      action: 'Complete lead qualification via WhatsApp or phone call',
      priority: score >= 60 ? 'high' : 'medium',
      rationale: 'Lead has not been fully qualified yet. Gathering key information will improve scoring accuracy.',
      dueInHours: 24,
    }
  }

  // Appointment pending
  if (dealStage === 'pending_appointment') {
    return {
      action: 'Schedule or confirm the consultation appointment',
      priority: 'high',
      rationale: 'Lead is ready for a consultation. Delay risks losing momentum.',
      dueInHours: 8,
    }
  }

  // Qualified stage
  if (dealStage === 'qualified') {
    return {
      action: 'Present a tailored proposal and request commitment',
      priority: 'medium',
      rationale: 'Lead is qualified. Presenting a concrete offer moves the deal forward.',
      dueInHours: 48,
    }
  }

  // Stale deal
  if (daysSinceLastActivity >= 7) {
    return {
      action: 'Re-engage with a value-added message or content piece',
      priority: 'medium',
      rationale: `No activity recorded for ${daysSinceLastActivity} days. A re-engagement touch can revive interest.`,
      dueInHours: 24,
    }
  }

  // Default
  return {
    action: 'Review deal details and plan the next outreach',
    priority: 'low',
    rationale: 'No urgent action detected. Review the deal context and align on next steps.',
    dueInHours: 72,
  }
}

// ─── Main export ──────────────────────────────────────────────────────────────

export async function runNextBestAction(
  input: NextBestActionInput,
): Promise<NextBestActionOutput> {
  if (!isLlmConfigured()) {
    return ruleBasedAction(input)
  }

  // ORC-H2: deal context includes free-form, unbounded user text
  // (conversationSummary) — delimit and cap it before interpolating.
  const contextText = wrapUntrustedInput(
    [
      `Contact ID: ${input.contactId}`,
      `Deal Stage: ${input.dealStage}`,
      `Days Since Last Activity: ${input.daysSinceLastActivity}`,
      `Lead Score: ${input.score}/100`,
      input.conversationSummary
        ? `Conversation Summary: ${input.conversationSummary}`
        : null,
    ]
      .filter(Boolean)
      .join('\n'),
  )

  try {
    const completion = await createChatCompletion({
      model: LLM_MODEL,
      max_tokens: 512,
      temperature: 0.3,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        {
          role: 'user',
          content: `Suggest the next best action for this deal:\n\n${contextText}`,
        },
      ],
    })

    const raw = completion.choices[0]?.message?.content ?? ''
    const parsed = JSON.parse(raw) as Record<string, unknown>

    const priority = String(parsed.priority ?? 'medium')
    const validPriority: NextBestActionOutput['priority'] =
      priority === 'high' || priority === 'low' ? priority : 'medium'

    return {
      action: String(parsed.action ?? ''),
      priority: validPriority,
      rationale: String(parsed.rationale ?? ''),
      dueInHours: Math.max(1, Math.round(Number(parsed.dueInHours ?? 24))),
    }
  } catch {
    // LLM failed — fall back to rule-based so the caller always gets a usable result.
    return ruleBasedAction(input)
  }
}
