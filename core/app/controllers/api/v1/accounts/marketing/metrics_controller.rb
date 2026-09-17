# KPIs agregados + serie temporal para a pagina Marketing > Overview.
class Api::V1::Accounts::Marketing::MetricsController < Api::V1::Accounts::BaseController
  before_action :check_feature_flag

  def overview
    snapshots = scoped_snapshots

    render json: {
      period: { from: date_range.begin, to: date_range.end },
      totals: totals_payload(snapshots.totals),
      by_provider: provider_breakdown(snapshots),
      series: daily_series(snapshots)
    }
  end

  private

  def check_feature_flag
    render json: { error: 'feature_disabled' }, status: :forbidden unless Current.account.feature_enabled?('marketing')
  end

  def date_range
    from = params[:date_from].presence&.to_date || 30.days.ago.to_date
    to = params[:date_to].presence&.to_date || Date.current
    from..to
  end

  def totals_payload(totals)
    impressions, clicks, spend, leads, conversions, conversion_value = totals
    {
      impressions: impressions.to_i,
      clicks: clicks.to_i,
      spend: spend.to_f.round(2),
      leads: leads.to_i,
      conversions: conversions.to_i,
      conversion_value: conversion_value.to_f.round(2),
      ctr: impressions.to_i.positive? ? ((clicks.to_f / impressions) * 100).round(2) : 0,
      cpl: leads.to_i.positive? ? (spend.to_f / leads).round(2) : 0,
      roas: spend.to_f.positive? ? (conversion_value / spend).to_f.round(2) : 0
    }
  end

  def scoped_snapshots
    Current.account.marketing_metric_snapshots
           .between(date_range.begin, date_range.end)
           .joins(:marketing_campaign)
           .where(marketing_campaigns: { level: 'campaign' })
  end

  def daily_series(snapshots)
    snapshots.group(:date)
             .order(:date)
             .pluck(:date,
                    Arel.sql('SUM(spend)'),
                    Arel.sql('SUM(leads)'),
                    Arel.sql('SUM(clicks)'),
                    Arel.sql('SUM(impressions)'))
             .map do |date, spend, leads, clicks, impressions|
      { date: date, spend: spend.to_f.round(2), leads: leads.to_i,
        clicks: clicks.to_i, impressions: impressions.to_i }
    end
  end

  def provider_breakdown(snapshots)
    snapshots.group('marketing_campaigns.provider')
             .pluck('marketing_campaigns.provider',
                    Arel.sql('SUM(spend)'),
                    Arel.sql('SUM(leads)'),
                    Arel.sql('SUM(conversions)'))
             .map do |provider, spend, leads, conversions|
      { provider: provider, spend: spend.to_f.round(2),
        leads: leads.to_i, conversions: conversions.to_i }
    end
  end
end
