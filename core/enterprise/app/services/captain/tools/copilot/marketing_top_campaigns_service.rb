class Captain::Tools::Copilot::MarketingTopCampaignsService < Captain::Tools::BaseTool
  METRICS = %w[spend leads conversions clicks impressions].freeze

  def self.name
    'marketing_top_campaigns'
  end

  description 'List top ad campaigns by a metric (spend, leads, conversions, clicks, impressions).'
  param :metric, type: :string, desc: "One of: #{METRICS.join(', ')}. Default spend.", required: false
  param :limit, type: :number, desc: 'Max campaigns to return. Default 5.', required: false

  def execute(metric: 'spend', limit: 5)
    column = METRICS.include?(metric.to_s) ? metric.to_s : 'spend'
    totals = top_campaign_ids(column, limit)
    names = campaign_names(totals.map(&:first))

    totals.map do |campaign_id, total|
      row_for(names[campaign_id], column, total)
    end.to_json
  end

  def active?
    @assistant.account.feature_enabled?('marketing')
  end

  private

  def top_campaign_ids(column, limit)
    MarketingMetricSnapshot.where(account_id: @assistant.account_id)
                           .group(:marketing_campaign_id)
                           .sum(column)
                           .sort_by { |_, v| -v }
                           .first(limit.to_i.clamp(1, 20))
  end

  def campaign_names(ids)
    MarketingCampaign.where(account_id: @assistant.account_id, id: ids)
                     .pluck(:id, :name, :provider)
                     .to_h { |id, name, provider| [id, { name: name, provider: provider }] }
  end

  def row_for(meta, column, total)
    {
      campaign: meta&.dig(:name),
      provider: meta&.dig(:provider),
      metric: column,
      value: column == 'spend' ? total.to_f.round(2) : total.to_i
    }
  end
end
