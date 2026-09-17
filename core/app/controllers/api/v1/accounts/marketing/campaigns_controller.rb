class Api::V1::Accounts::Marketing::CampaignsController < Api::V1::Accounts::BaseController
  before_action :check_feature_flag

  def index
    campaigns = filtered_campaigns.includes(:metric_snapshots, :crm_external_connection)
    render json: { campaigns: campaigns.map { |c| serialize_campaign(c) } }
  end

  # Escrita governada: pausar/reativar campanha Meta exige ads_write_enabled
  # na conexão + vai por job (auditoria em marketing_events + crm_audit_events).
  def set_status
    campaign = Current.account.marketing_campaigns.find(params[:id])
    status = params[:status].to_s.upcase
    unless Marketing::CampaignStatusJob::ALLOWED_STATUSES.include?(status)
      return render json: { error: 'invalid_status' }, status: :unprocessable_entity
    end

    connection = campaign.crm_external_connection
    unless connection&.provider == 'meta_ads' && connection.metadata&.dig('ads_write_enabled').present?
      return render json: { error: 'write_not_enabled' }, status: :forbidden
    end

    Marketing::CampaignStatusJob.perform_later(campaign.id, status)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: current_user,
      action: 'marketing_campaign_status_requested',
      target: campaign,
      payload: { status: status, campaign_external_id: campaign.external_id }
    )
    head :accepted
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
      writable: writable_connection?(campaign.crm_external_connection),
      metrics: serialize_metrics(snapshots.totals)
    }
  end

  def writable_connection?(connection)
    connection&.provider == 'meta_ads' && connection.metadata&.dig('ads_write_enabled').present?
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
