import OpenAI from 'openai'

export const LLM_BASE_URL =
  process.env.LLM_BASE_URL ?? 'https://openrouter.ai/api/v1'

if (new URL(LLM_BASE_URL).hostname !== 'openrouter.ai') {
  throw new Error('LLM_BASE_URL must use the unified OpenRouter gateway')
}

export const llm = new OpenAI({
  apiKey: process.env.LLM_API_KEY ?? '',
  baseURL: LLM_BASE_URL,
  timeout: Number(process.env.LLM_TIMEOUT_MS ?? 60000),
})

export const LLM_MODEL = process.env.LLM_MODEL ?? 'google/gemini-3.7-flash'

export const DR_PAULA_MATOS_LLM_MODEL =
  process.env.ORCHESTRATOR_DRA_LETICIA_LLM_MODEL ??
  process.env.ORCHESTRATOR_DR_PAULA_LLM_MODEL ??
  'anthropic/claude-sonnet-5'

export const LLM_ATTENDANCE_TEST_MODEL =
  process.env.LLM_ATTENDANCE_TEST_MODEL ?? 'deepseek/deepseek-v4-flash'

export const LLM_CODING_TEST_MODEL =
  process.env.LLM_CODING_TEST_MODEL ?? 'z-ai/glm-5.2'

export const LLM_MAX_TOKENS = Number(process.env.LLM_MAX_TOKENS_PER_SESSION ?? 4096)

/**
 * Returns true when the LLM is configured with a real API key.
 * Skills use this to decide whether to call the LLM or return a deterministic fallback.
 */
export function isLlmConfigured(): boolean {
  const key = process.env.LLM_API_KEY ?? ''
  return key.trim().length > 0
}
