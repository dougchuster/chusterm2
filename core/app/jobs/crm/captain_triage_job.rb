class Crm::CaptainTriageJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(conversation_id, account_id)
    account = Account.find_by(id: account_id)
    return unless account
    return unless crm_pipeline_ready?(account)

    conversation = account.conversations.find_by(id: conversation_id)
    return unless conversation

    Crm::TriageFromConversation.new(
      conversation: conversation,
      account: account,
      actor: nil
    ).perform
  end

  private

  def crm_pipeline_ready?(account)
    account.crm_pipelines.active
           .joins(:crm_pipeline_stages)
           .merge(CrmPipelineStage.active)
           .exists?
  end
end
