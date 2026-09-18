# 5.4 do PLANO_17_09.md — endpoint MCP do CRM.
#
# Um POST JSON-RPC 2.0 por chamada. A autenticação é a mesma da API privada
# (sessão, token de usuário via api_access_token ou AgentBot na whitelist) —
# não existe um segundo esquema de credencial para o MCP.
#
# Herda de Api::V1::Accounts::BaseController (não do Crm::BaseController)
# porque AgentBot não tem account_user: a autorização do bot sai por
# validate_bot_access_token! + BOT_ACCESSIBLE_ENDPOINTS, e a do usuário por
# Current.account_user.
class Api::V1::Accounts::Crm::McpController < Api::V1::Accounts::BaseController
  before_action :check_mcp_authorization

  def create
    response = mcp_server.handle(request_payload)
    return head :accepted if response.nil?

    render json: response
  end

  private

  def mcp_server
    Crm::McpServer.new(account: Current.account, actor: Current.user)
  end

  # Bots entram pela whitelist; usuários precisam pertencer à conta.
  def check_mcp_authorization
    return if @resource.is_a?(AgentBot)
    return if Current.account_user

    access_denied
  end

  def request_payload
    params.except(:controller, :action, :account_id, :mcp).to_unsafe_h
  end
end
