class Api::V1::Accounts::Crm::Triage::FromConversationController < Api::V1::Accounts::Crm::BaseController
  def create
    authorize CrmDeal, :create?

    conversation = Current.account.conversations.find(params[:conversation_id])
    deal = Crm::TriageFromConversation.new(
      conversation: conversation,
      account: Current.account,
      actor: Current.user
    ).perform
    render json: { id: deal.id, title: deal.title, status: deal.status,
                   crm_pipeline_id: deal.crm_pipeline_id,
                   crm_pipeline_stage_id: deal.crm_pipeline_stage_id,
                   contact_id: deal.contact_id,
                   conversation_id: deal.conversation_id,
                   score_total: deal.score_total,
                   score_classification: deal.score_classification,
                   created_at: deal.created_at }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Conversation not found' }, status: :not_found
  rescue RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
