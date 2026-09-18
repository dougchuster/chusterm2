# frozen_string_literal: true

# 3.1b do PLANO_17_09.md — expõe Crm::Tools ao orchestrator via token de
# AgentBot. Herda do BaseController de contas (e nao do Crm::BaseController)
# porque bots nao tem account_user: a autorizacao e feita por
# validate_bot_access_token! + whitelist BOT_ACCESSIBLE_ENDPOINTS.
class Api::V1::Accounts::Crm::AgentToolsController < Api::V1::Accounts::BaseController
  TOOL_METHODS = {
    'get_deal_context' => { method: :deal_context, positional: [], kwargs: [] },
    'set_category' => { method: :set_category, positional: %w[value], kwargs: %w[subcategory reason] },
    'set_urgency' => { method: :set_urgency, positional: %w[level], kwargs: %w[reason] },
    'set_field' => { method: :set_field, positional: %w[key value], kwargs: %w[reason] },
    'move_stage' => { method: :move_stage, positional: %w[slug], kwargs: %w[reason] },
    'create_activity' => { method: :create_activity, positional: [], kwargs: %w[kind title due_at description] },
    'schedule_appointment' => { method: :schedule_appointment, positional: [], kwargs: %w[at title note] },
    'request_info' => { method: :request_info, positional: %w[message], kwargs: [] },
    'mark_qualified' => { method: :mark_qualified, positional: [], kwargs: %w[reason] }
  }.freeze

  # GET — lista as tools e os argumentos que cada uma aceita, para o
  # orchestrator registrar no perfil do pack.
  def index
    render json: {
      tools: TOOL_METHODS.map do |name, spec|
        { name: name, positional: spec[:positional], arguments: spec[:kwargs] }
      end
    }
  end

  # POST — executa uma tool contra o deal informado (ou resolvido pela
  # conversa). O payload nunca toca parametros fora da whitelist da tool.
  def execute
    spec = TOOL_METHODS[params[:tool].to_s]
    return render json: { error: 'Unknown tool' }, status: :bad_request unless spec

    target_deal = find_deal
    return render json: { error: 'Deal not found' }, status: :not_found unless target_deal

    tools = Crm::Tools.new(deal: target_deal, conversation: target_conversation(target_deal))
    args = permitted_args(spec[:positional] + spec[:kwargs])
    positional = spec[:positional].map { |key| args.delete(key.to_sym) }
    result = tools.public_send(spec[:method], *positional, **args)

    if result.ok?
      render json: { ok: true, data: result.data }
    else
      render json: { ok: false, error: result.error }, status: :unprocessable_entity
    end
  end

  private

  # Sem Current.account_user (bot): Current.account ja foi resolvido por
  # EnsureCurrentAccountHelper, que valida o acesso do bot a conta.
  def find_deal
    scope = Current.account.crm_deals.where(status: %w[open won lost])

    if params[:deal_id].present?
      scope.find_by(id: params[:deal_id])
    elsif params[:conversation_id].present?
      conversation = Current.account.conversations.find_by(id: params[:conversation_id])
      return nil unless conversation

      scope.left_joins(:crm_deal_conversations)
           .where(crm_deal_conversations: { conversation_id: conversation.id })
           .or(scope.where(conversation_id: conversation.id))
           .order(status: :asc)
           .first
    end
  end

  def target_conversation(deal)
    if params[:conversation_id].present?
      Current.account.conversations.find_by(id: params[:conversation_id])
    else
      deal.conversation
    end
  end

  def permitted_args(keys)
    raw = params[:args].is_a?(ActionController::Parameters) ? params[:args] : ActionController::Parameters.new(params[:args] || {})
    raw.permit(*keys).to_h.symbolize_keys
  end
end
