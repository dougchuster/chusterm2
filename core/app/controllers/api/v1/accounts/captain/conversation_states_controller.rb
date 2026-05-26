class Api::V1::Accounts::Captain::ConversationStatesController < Api::V1::Accounts::BaseController
  before_action :set_conversation
  before_action :set_state

  def show
    render json: serialize_state(@state)
  end

  def update
    @state.assign_attributes(state_params)
    apply_handoff_metadata if @state.ai_mode_changed?
    @state.save!

    render json: serialize_state(@state)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def set_conversation
    @conversation = Current.account.conversations.find_by(id: params[:conversation_id]) ||
                    Current.account.conversations.find_by!(display_id: params[:conversation_id])
    authorize @conversation, :show?
  end

  def set_state
    @state = Current.account.captain_conversation_states.find_or_create_by!(conversation: @conversation) do |state|
      state.contact = @conversation.contact
    end
  end

  def state_params
    permitted = params.require(:conversation_state).permit(
      :ai_mode, :handoff_reason, :captain_assistant_id, :crm_deal_id,
      :score_total, :score_classification, :context_summary, :current_node_id,
      :last_ai_message_at, score_payload: {}
    )

    permitted[:captain_assistant_id] = nil if permitted.key?(:captain_assistant_id) && permitted[:captain_assistant_id].blank?
    permitted[:crm_deal_id] = nil if permitted.key?(:crm_deal_id) && permitted[:crm_deal_id].blank?
    permitted
  end

  def apply_handoff_metadata
    if CaptainConversationState::HUMAN_MODES.include?(@state.ai_mode)
      @state.handoff_at ||= Time.current
      @state.handoff_by ||= Current.user
    else
      @state.handoff_at = nil
      @state.handoff_by = nil
      @state.handoff_reason = 'IA retomada manualmente'
    end
  end

  def serialize_state(state)
    deal = linked_deal(state)

    {
      id: state.id,
      account_id: state.account_id,
      conversation_id: state.conversation_id,
      contact_id: state.contact_id,
      captain_assistant_id: state.captain_assistant_id,
      crm_deal_id: state.crm_deal_id,
      ai_mode: state.ai_mode,
      handoff_reason: state.handoff_reason,
      handoff_at: state.handoff_at,
      handoff_by_id: state.handoff_by_id,
      score_total: state.score_total,
      score_classification: state.score_classification,
      score_payload: state.score_payload,
      score_factors: state.score_payload&.dig('components') || state.score_payload&.dig(:components),
      context_summary: state.context_summary,
      captain_flow_id: state.captain_flow_id,
      captain_flow_name: state.captain_flow&.name,
      current_node_id: state.current_node_id,
      last_ai_message_at: state.last_ai_message_at,
      handoff_by_name: state.handoff_by&.name,
      handoff_by_avatar: state.handoff_by&.avatar_url,
      crm_deal_title: deal&.title,
      crm_deal_next_best_action: deal&.next_best_action,
      crm_deal_legal_area: deal&.legal_area,
      crm_deal_documents_status: deal&.documents_status,
      crm_deal_owner_name: deal_owner_name(deal),
      updated_at: state.updated_at
    }
  end

  def linked_deal(state)
    state.crm_deal || Current.account.crm_deals.open_deals.find_by(conversation: @conversation)
  end

  def deal_owner_name(deal)
    return if deal&.owner_id.blank?

    Current.account.users.find_by(id: deal.owner_id)&.name
  end
end
