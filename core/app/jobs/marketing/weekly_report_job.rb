# Relatório semanal de marketing: toda segunda consolida KPIs dos últimos 7d
# por conta e registra em crm_audit_events (visível na trilha de auditoria).
# Contas sem flag marketing ou sem conexão ativa são puladas.
class Marketing::WeeklyReportJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    accounts_with_connections.find_each do |account|
      next unless account.feature_enabled?('marketing')

      Crm::AuditLogger.log(
        account: account,
        action: 'marketing_weekly_report',
        target: account,
        payload: weekly_payload(account)
      )
    rescue StandardError => e
      Rails.logger.error("[Marketing WeeklyReport] account #{account.id}: #{e.class}: #{e.message}")
    end
  end

  private

  def accounts_with_connections
    Account.joins(:crm_external_connections)
           .where(crm_external_connections: { provider: %w[meta_ads google_ads ga4], status: 'active' })
           .distinct
  end

  def weekly_payload(account)
    alerts = Marketing::InsightsService.new(account: account).perform[:alerts]
    weekly_metrics(account).merge(
      alerts_count: alerts.size,
      alerts: alerts.pluck(:type)
    )
  end

  def weekly_metrics(account)
    totals = account.marketing_metric_snapshots.where(date: 7.days.ago.to_date..Date.current).totals
    impressions, clicks, spend, leads, conversions, conversion_value = totals
    {
      period: { from: 7.days.ago.to_date, to: Date.current },
      impressions: impressions.to_i,
      clicks: clicks.to_i,
      spend: spend.to_f.round(2),
      leads: leads.to_i,
      conversions: conversions.to_i,
      conversion_value: conversion_value.to_f.round(2)
    }
  end
end
