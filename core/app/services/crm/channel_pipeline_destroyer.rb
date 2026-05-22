# frozen_string_literal: true

class Crm::ChannelPipelineDestroyer
  def initialize(inbox:)
    @inbox = inbox
    @account = inbox&.account
  end

  def perform
    return unless @inbox && @account

    pipeline = @account.crm_pipelines.find_by(inbox_id: @inbox.id)
    return unless pipeline

    ActiveRecord::Base.transaction do
      destroy_pipeline_deals!(pipeline)
      Crm::AuditLogger.log(
        account: @account,
        actor: Current.user,
        action: 'channel_pipeline_destroyed',
        target: pipeline,
        payload: { inbox_id: @inbox.id, inbox_name: @inbox.name, deals_removed: @removed_deals.to_i }
      )
      pipeline.destroy!
    end
  end

  private

  def destroy_pipeline_deals!(pipeline)
    @removed_deals = 0

    pipeline.crm_deals.find_each do |deal|
      Crm::AuditLogger.log(
        account: @account,
        actor: Current.user,
        action: 'deal_destroyed_with_channel_pipeline',
        target: deal,
        payload: { inbox_id: @inbox.id, pipeline_id: pipeline.id }
      )
      deal.destroy!
      @removed_deals += 1
    end
  end
end
