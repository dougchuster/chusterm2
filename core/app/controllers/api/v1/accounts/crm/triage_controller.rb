class Api::V1::Accounts::Crm::TriageController < Api::V1::Accounts::Crm::BaseController
  def from_conversation
    authorize CrmDeal, :create?

    conversation = Current.account.conversations.find(params[:conversation_id])
    deal = Crm::TriageFromConversation.new(
      conversation: conversation,
      account: Current.account,
      actor: Current.user
    ).perform
    render json: serialize_deal(deal), status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversation not found' }, status: :not_found
  rescue RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def serialize_deal(deal)
    {
      id: deal.id,
      title: deal.title,
      status: deal.status,
      legal_area: deal.legal_area,
      case_type: deal.case_type,
      urgency_level: deal.urgency_level,
      score_total: deal.score_total,
      score_classification: deal.score_classification,
      summary: deal.summary,
      next_best_action: deal.next_best_action,
      crm_pipeline_id: deal.crm_pipeline_id,
      crm_pipeline_stage_id: deal.crm_pipeline_stage_id,
      contact_id: deal.contact_id,
      conversation_id: deal.conversation_id
    }
  end
end
