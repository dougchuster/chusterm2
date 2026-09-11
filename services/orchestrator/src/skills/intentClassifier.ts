import { createChatCompletion, LLM_MODEL, isLlmConfigured } from '../llm/client.js'
import { UNTRUSTED_DATA_INSTRUCTION, wrapUntrustedInput } from './promptGuards.js'

export interface IntentClassifierInput {
  conversationId: string
  messages: Array<{ role: 'user' | 'assistant'; content: string }>
  accountId: number
}

export interface IntentClassifierOutput {
  intent:
    | 'purchase'
    | 'support'
    | 'churn'
    | 'upsell'
    | 'complaint'
    | 'appointment'
    | 'faq'
    | 'unknown'
  confidence: number
  reasoning: string
}

const VALID_INTENTS = new Set([
  'purchase',
  'support',
  'churn',
  'upsell',
  'complaint',
  'appointment',
  'faq',
  'unknown',
])

const SYSTEM_PROMPT = `You are an intent classifier for a CRM. Classify the user's intent from the conversation.

Valid intents:
- purchase: user wants to buy, enroll, or start a contract
- support: user needs technical or operational help
- churn: user wants to cancel or is expressing dissatisfaction suggesting churn
- upsell: user might be receptive to an upgrade or add-on offer
- complaint: user is complaining about a product, service, or experience
- appointment: user wants to schedule or reschedule a meeting
- faq: user is asking a common informational question
- unknown: intent cannot be determined from the conversation

Respond in JSON only, with no markdown, no code fences, and no extra text.
Format: { "intent": "<one of the valid intents>", "confidence": <0.0 to 1.0>, "reasoning": "<brief explanation>" }

${UNTRUSTED_DATA_INSTRUCTION}`

export async function runIntentClassifier(
  input: IntentClassifierInput,
): Promise<IntentClassifierOutput> {
  if (!isLlmConfigured()) {
    return {
      intent: 'unknown',
      confidence: 0,
      reasoning: 'LLM not configured',
    }
  }

  // ORC-H2: conversation text is untrusted — delimit and cap it before
  // interpolating into the prompt.
  const userContent = wrapUntrustedInput(
    input.messages.map((m) => `${m.role.toUpperCase()}: ${m.content}`).join('\n'),
  )

  try {
    const completion = await createChatCompletion({
      model: LLM_MODEL,
      max_tokens: 256,
      temperature: 0.1,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        {
          role: 'user',
          content: `Classify the intent of the following conversation (conversationId: ${input.conversationId}):\n\n${userContent}`,
        },
      ],
    })

    const raw = completion.choices[0]?.message?.content ?? ''
    const parsed = JSON.parse(raw) as Record<string, unknown>

    const intent = String(parsed.intent ?? 'unknown')
    const confidence = Number(parsed.confidence ?? 0)
    const reasoning = String(parsed.reasoning ?? '')

    return {
      intent: VALID_INTENTS.has(intent)
        ? (intent as IntentClassifierOutput['intent'])
        : 'unknown',
      confidence: Math.min(1, Math.max(0, confidence)),
      reasoning,
    }
  } catch {
    return {
      intent: 'unknown',
      confidence: 0,
      reasoning: 'LLM call failed or returned unparseable response',
    }
  }
}
