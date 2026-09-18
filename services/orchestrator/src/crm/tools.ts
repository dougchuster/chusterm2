// 3.1b do PLANO_17_09.md — cliente das tools de CRM expostas pelo core em
// POST /api/v1/accounts/:id/crm/agent_tools/execute. O orchestrator chama
// com o mesmo token de AgentBot usado para histórico/respostas; toda ação
// é auditada no core com actor_type 'ai'.

const CHATWOOT_BASE_URL = (process.env.CHATWOOT_BASE_URL ?? 'http://core:3000').replace(/\/$/, '')
const CHATWOOT_BOT_TOKEN = process.env.CHATWOOT_BOT_TOKEN ?? ''

export type CrmToolName =
  | 'get_deal_context'
  | 'set_category'
  | 'set_urgency'
  | 'set_field'
  | 'move_stage'
  | 'create_activity'
  | 'schedule_appointment'
  | 'request_info'
  | 'mark_qualified'

export interface CrmToolCall {
  tool: CrmToolName
  dealId?: number
  conversationId?: number
  args?: Record<string, unknown>
}

export interface CrmToolResult<T = unknown> {
  ok: boolean
  data?: T
  error?: string
}

export class CrmToolUnavailableError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'CrmToolUnavailableError'
  }
}

export async function callCrmTool<T = unknown>(
  accountId: number,
  call: CrmToolCall,
): Promise<CrmToolResult<T>> {
  if (!CHATWOOT_BOT_TOKEN) {
    throw new CrmToolUnavailableError('CHATWOOT_BOT_TOKEN is not configured')
  }

  const url = `${CHATWOOT_BASE_URL}/api/v1/accounts/${accountId}/crm/agent_tools/execute`
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      api_access_token: CHATWOOT_BOT_TOKEN,
    },
    body: JSON.stringify({
      tool: call.tool,
      deal_id: call.dealId,
      conversation_id: call.conversationId,
      args: call.args ?? {},
    }),
    signal: AbortSignal.timeout(10_000),
  })

  if (!response.ok) {
    const body = (await response.json().catch(() => ({}))) as { error?: string }
    return { ok: false, error: body.error ?? `HTTP ${response.status}` }
  }

  const body = (await response.json()) as { ok: boolean; data?: T; error?: string }
  return { ok: body.ok, data: body.data, error: body.error }
}
