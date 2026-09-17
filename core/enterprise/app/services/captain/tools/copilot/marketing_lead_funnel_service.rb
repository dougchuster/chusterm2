class Captain::Tools::Copilot::MarketingLeadFunnelService < Captain::Tools::BaseTool
  def self.name
    'marketing_lead_funnel'
  end

  description 'Show how ads leads flow through the CRM funnel: counts per pipeline stage and conversion rate.'
  param :pipeline_id, type: :number, desc: 'CRM pipeline id. Defaults to the account default pipeline.', required: false

  def execute(pipeline_id: nil)
    account = @assistant.account
    pipeline = pipeline_id.present? ? account.crm_pipelines.find_by(id: pipeline_id) : account.crm_pipelines.default_first.first
    return 'No pipeline found' if pipeline.nil?

    {
      pipeline: pipeline.name,
      stages: stage_stats(account, pipeline),
      total_ads_leads: account.marketing_leads.count,
      converted_to_crm: account.marketing_leads.where(status: 'converted').count,
      conversion_rate: conversion_rate(account)
    }.to_json
  end

  def active?
    @assistant.account.feature_enabled?('marketing')
  end

  private

  def stage_stats(account, pipeline)
    deals = account.crm_deals.where(crm_pipeline_id: pipeline.id)
    ads_deal_ids = account.marketing_leads.where.not(crm_deal_id: nil).pluck(:crm_deal_id)

    pipeline.crm_pipeline_stages.ordered.pluck(:id, :name).map do |id, name|
      {
        stage: name,
        deals: deals.where(crm_pipeline_stage_id: id).count,
        from_ads: deals.where(crm_pipeline_stage_id: id, id: ads_deal_ids).count
      }
    end
  end

  def conversion_rate(account)
    total = account.marketing_leads.count
    return if total.zero?

    (account.marketing_leads.where(status: 'converted').count.to_f / total * 100).round(1)
  end
end
