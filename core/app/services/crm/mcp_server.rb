# 5.4 do PLANO_17_09.md — MCP server do CRM.
#
# JSON-RPC 2.0 stateless (streamable HTTP): um POST por chamada, sem sessão.
# Os métodos implementados são os do protocolo MCP (`initialize`, `ping`,
# `tools/list`, `tools/call`); qualquer cliente MCP consegue descobrir e chamar
# as tools. O catálogo e os handlers moram em Crm::McpTools; tudo passa por
# serviços já existentes — o MCP é só a porta, não uma segunda implementação
# de regra de negócio.
class Crm::McpServer
  PROTOCOL_VERSION = '2025-06-18'.freeze
  SERVER_INFO = { name: 'chusterm-crm', version: '1.0.0' }.freeze
  MAX_LIMIT = 50

  PARSE_ERROR = -32_700
  METHOD_NOT_FOUND = -32_601
  INVALID_PARAMS = -32_602
  INTERNAL_ERROR = -32_603

  PROTOCOL_METHODS = {
    'initialize' => lambda do
      {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: { tools: {} },
        serverInfo: SERVER_INFO
      }
    end,
    'ping' => -> { {} },
    'tools/list' => -> { { tools: Crm::McpTools::TOOLS } }
  }.freeze
  private_constant :PROTOCOL_METHODS

  def initialize(account:, actor: nil)
    @account = account
    @actor = actor
  end

  # Devolve o objeto de resposta JSON-RPC, ou nil para notifications
  # (MCP manda `notifications/initialized` sem id — notificação não responde).
  def handle(request)
    id = request['id']
    method = request['method'].to_s
    return result(id, call_tool(request['params'] || {})) if method == 'tools/call'

    handler = PROTOCOL_METHODS[method]
    return result(id, instance_exec(&handler)) if handler
    return nil if id.nil? # notifications/* não produzem resposta

    error(id, METHOD_NOT_FOUND, 'Method not found')
  rescue Crm::McpTools::ToolError => e
    error(id, INVALID_PARAMS, e.message)
  rescue StandardError => e
    Rails.logger.error("[Crm::McpServer] #{e.class}: #{e.message}")
    error(id, INTERNAL_ERROR, 'Internal error')
  end

  private

  def result(id, content)
    { jsonrpc: '2.0', id: id, result: content }
  end

  def error(id, code, message)
    { jsonrpc: '2.0', id: id, error: { code: code, message: message } }
  end

  # MCP devolve tool output como content blocks de texto — serializo o payload
  # em JSON dentro do texto, como os servers de referência fazem.
  def call_tool(params)
    name = params['name'].to_s
    args = (params['arguments'] || {}).with_indifferent_access
    handler = Crm::McpHandlers::HANDLERS[name]
    raise Crm::McpTools::ToolError, "Unknown tool: #{name}" unless handler

    data = instance_exec(args, &handler)
    { content: [{ type: 'text', text: JSON.generate(data) }] }
  end

  def limit_param(args)
    [args[:limit].to_i, MAX_LIMIT].min.then { |n| n.positive? ? n : 20 }
  end

  def serialize_deal(deal)
    {
      id: deal.id,
      title: deal.title,
      status: deal.status,
      score: deal.score_total,
      stage_id: deal.crm_pipeline_stage_id,
      pipeline_id: deal.crm_pipeline_id,
      contact_id: deal.contact_id,
      owner_id: deal.owner_id,
      value_estimate_cents: deal.value_estimate_cents
    }
  end
end
