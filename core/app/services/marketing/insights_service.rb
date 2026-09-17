# Alertas deterministicos sobre os snapshots locais — sem chamada de IA.
# O Captain complementa com analise ad-hoc via tools/MCPs.
class Marketing::InsightsService
  CPL_SPIKE_FACTOR = 1.5

  def initialize(account:)
    @account = account
  end

  def perform
    alerts = [
      cpl_spike_alert,
      zero_impressions_alert,
      failed_events_alert
    ].compact
    { alerts: alerts, generated_at: Time.current }
  end

  private

  def cpl_spike_alert
    current = cpl_for(7.days.ago.to_date..Date.current)
    previous = cpl_for(14.days.ago.to_date..8.days.ago.to_date)
    return if previous.nil? || current.nil?
    return if current < (previous * CPL_SPIKE_FACTOR)

    pct = (((current / previous) - 1) * 100).round
    {
      kind: 'cpl_spike', severity: 'warning',
      message: "CPL subiu #{pct}% vs semana anterior " \
               "(R$ #{current.round(2)} → R$ #{previous.round(2)})"
    }
  end

  def cpl_for(range)
    totals = spend_and_leads(range)
    return if totals[:leads].zero?

    totals[:spend] / totals[:leads]
  end

  def zero_impressions_alert
    campaign_ids = @account.marketing_campaigns.active.pluck(:id)
    silent = @account.marketing_metric_snapshots
                     .where(marketing_campaign_id: campaign_ids, date: 3.days.ago.to_date..Date.current)
                     .group(:marketing_campaign_id)
                     .having('SUM(impressions) = 0 AND SUM(spend) > 0')
                     .pluck(:marketing_campaign_id)
    return if silent.empty?

    names = @account.marketing_campaigns.where(id: silent).pluck(:name)
    {
      kind: 'zero_impressions', severity: 'critical',
      message: "Campanhas sem impressões nos últimos 3 dias: #{names.join(', ')}"
    }
  end

  def failed_events_alert
    count = @account.marketing_events.where(status: 'failed', created_at: 24.hours.ago..).count
    return if count.zero?

    {
      kind: 'failed_events', severity: 'warning',
      message: "#{count} evento(s) de conversão falharam nas últimas 24h — verificar Conversions API"
    }
  end

  def spend_and_leads(range)
    @account.marketing_metric_snapshots
            .where(date: range)
            .pick(Arel.sql('COALESCE(SUM(spend),0)'), Arel.sql('COALESCE(SUM(leads),0)'))
            .then { |spend, leads| { spend: spend.to_f, leads: leads.to_i } }
  end
end
