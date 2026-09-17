class Captain::Tools::Copilot::MarketingSpendSummaryService < Captain::Tools::BaseTool
  def self.name
    'marketing_spend_summary'
  end

  description 'Summarize ads spend, leads, CPL and ROAS per provider (Meta Ads, Google Ads, GA4) for a period.'
  param :period_days, type: :number, desc: 'Lookback window in days (7, 14, 30 or 90). Default 30.', required: false

  def execute(period_days: 30)
    days = [7, 14, 30, 90].include?(period_days.to_i) ? period_days.to_i : 30
    grouped = snapshots_since(days)

    providers = grouped.sum(:spend).map do |provider, spend|
      provider_row(grouped, provider, spend.to_f)
    end

    { period_days: days, providers: providers }.to_json
  end

  def active?
    @assistant.account.feature_enabled?('marketing')
  end

  private

  def snapshots_since(days)
    MarketingMetricSnapshot.where(account_id: @assistant.account_id, date: days.days.ago.to_date..Date.current)
                           .joins(:marketing_campaign)
                           .group('marketing_campaigns.provider')
  end

  def provider_row(grouped, provider, spend)
    lead_count = grouped.sum(:leads)[provider].to_i
    {
      provider: provider,
      spend: spend.round(2),
      leads: lead_count,
      conversions: grouped.sum(:conversions)[provider].to_i,
      cpl: lead_count.positive? ? (spend / lead_count).round(2) : nil,
      roas: spend.positive? ? (grouped.sum(:conversion_value)[provider].to_f / spend).round(2) : nil
    }
  end
end
