class Crm::DealCreator
  def initialize(account:, params:, actor: nil)
    @account = account
    @params = params
    @actor = actor
  end

  def perform
    ActiveRecord::Base.transaction do
      deal = @account.crm_deals.create!(@params.slice(:title, :contact_id, :conversation_id, :inbox_id,
                                                        :team_id, :owner_id, :assignee_id,
                                                        :crm_pipeline_id, :crm_pipeline_stage_id,
                                                        :legal_area, :case_type, :urgency_level,
                                                        :source, :value_estimate_cents, :lgpd_basis,
                                                        :consent_status, :consent_channel,
                                                        :consent_collected_at, :data_retention_until,
                                                        :custom_fields, :attribution))
      Crm::AuditLogger.log(account: @account, actor: @actor, action: 'deal_created', target: deal)
      Crm::ApplyChecklistTemplate.new(deal: deal, actor: @actor).perform if deal.case_type.present?
      deal
    end
  end
end
