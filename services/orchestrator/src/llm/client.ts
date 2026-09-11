import OpenAI from 'openai'

export const LLM_BASE_URL =
  process.env.LLM_BASE_URL ?? 'https://openrouter.ai/api/v1'

// ORC-L1: require the unified OpenRouter gateway over HTTPS (no plaintext).
const llmBaseUrl = new URL(LLM_BASE_URL)
if (llmBaseUrl.hostname !== 'openrouter.ai' || llmBaseUrl.protocol !== 'https:') {
  throw new Error('LLM_BASE_URL must use the unified OpenRouter gateway over HTTPS')
}

const LLM_TIMEOUT_MS = Number(process.env.LLM_TIMEOUT_MS ?? 30_000)

export const llm = new OpenAI({
  apiKey: process.env.LLM_API_KEY ?? '',
  baseURL: LLM_BASE_URL,
  timeout: LLM_TIMEOUT_MS,
  // Bounded retries: the SDK retries 429/5xx with exponential backoff + jitter.
  maxRetries: 2,
})

/**
 * Typed error thrown when an LLM upstream call fails after all retries.
 * Routes translate this to a 502 response.
 */
export class LlmUpstreamError extends Error {
  readonly statusCode = 502

  constructor(
    message: string,
    readonly cause?: unknown,
  ) {
    super(message)
    this.name = 'LlmUpstreamError'
  }
}

/**
 * Executes a chat completion with a hard timeout (AbortSignal) and bounded
 * retries (SDK-level, for 429/5xx). Throws LlmUpstreamError on final failure.
 */
export async function createChatCompletion(
  params: OpenAI.Chat.Completions.ChatCompletionCreateParamsNonStreaming,
): Promise<OpenAI.Chat.Completions.ChatCompletion> {
  try {
    return await llm.chat.completions.create(params, {
      signal: AbortSignal.timeout(LLM_TIMEOUT_MS),
    })
  } catch (err) {
    throw new LlmUpstreamError('LLM upstream request failed', err)
  }
}

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
