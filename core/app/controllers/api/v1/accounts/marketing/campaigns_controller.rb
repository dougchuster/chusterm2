class Api::V1::Accounts::Marketing::CampaignsController < Api::V1::Accounts::BaseController
  before_action :check_feature_flag

  def index
    campaigns = filtered_campaigns.includes(:metric_snapshots)
    render json: { campaigns: campaigns.map { |c| serialize_campaign(c) } }
  end

  private

  def check_feature_flag
    render json: { error: 'feature_disabled' }, status: :forbidden unless Current.account.feature_enabled?('marketing')
  end

  def filtered_campaigns
    scope = Current.account.marketing_campaigns.campaigns_only
    scope = scope.for_provider(params[:provider]) if params[:provider].present?
    scope = scope.where(status: params[:status].upcase) if params[:status].present?
    scope.order(provider: :asc, name: :asc)
  end

  def date_range
    from = params[:date_from].presence&.to_date || 30.days.ago.to_date
    to = params[:date_to].presence&.to_date || Date.current
    from..to
  end

  def serialize_campaign(campaign)
    snapshots = campaign.metric_snapshots.between(date_range.begin, date_range.end)

    {
      id: campaign.id,
      provider: campaign.provider,
      external_id: campaign.external_id,
      name: campaign.name,
      status: campaign.status,
      objective: campaign.objective,
      currency: campaign.currency,
      daily_budget: campaign.daily_budget,
      metrics: serialize_metrics(snapshots.totals)
    }
  end

  def serialize_metrics(totals)
    impressions, clicks, spend, leads, conversions, conversion_value = totals
    {
      impressions: impressions.to_i,
      clicks: clicks.to_i,
      spend: spend.to_f.round(2),
      leads: leads.to_i,
      conversions: conversions.to_i,
      conversion_value: conversion_value.to_f.round(2),
      ctr: impressions.to_i.positive? ? ((clicks.to_f / impressions) * 100).round(2) : 0,
      cpc: clicks.to_i.positive? ? (spend.to_f / clicks).round(2) : 0,
      cpl: leads.to_i.positive? ? (spend.to_f / leads).round(2) : 0
    }
  end
end
