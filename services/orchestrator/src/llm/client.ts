import OpenAI from 'openai'

export const llm = new OpenAI({
  apiKey: process.env.LLM_API_KEY ?? '',
  baseURL: process.env.LLM_BASE_URL ?? 'https://openrouter.ai/api/v1',
  timeout: Number(process.env.LLM_TIMEOUT_MS ?? 60000),
})

export const LLM_MODEL = process.env.LLM_MODEL ?? 'qwen/qwen3-coder-plus'

export const LLM_MAX_TOKENS = Number(process.env.LLM_MAX_TOKENS_PER_SESSION ?? 4096)

/**
 * Returns true when the LLM is configured with a real API key.
 * Skills use this to decide whether to call the LLM or return a deterministic fallback.
 */
export function isLlmConfigured(): boolean {
  const key = process.env.LLM_API_KEY ?? ''
  return key.trim().length > 0
}
