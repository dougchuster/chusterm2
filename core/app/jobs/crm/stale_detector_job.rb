class Crm::StaleDetectorJob < ApplicationJob
  queue_as :default

  STALE_ACTIVITY_KIND = 'follow_up'.freeze

  # Executado pelo sidekiq-cron (ver config/sidekiq_cron.yml)
  # Padrão: diariamente às 08:00
  def perform(account_id: nil, stale_days: nil)
    scope = account_id ? Account.where(id: account_id) : Account.all

    scope.find_each do |account|
      detect_stale_deals(account, stale_days)
    end
  end

  private

  def detect_stale_deals(account, override_days)
    # Apenas deals abertos
    open_deals = account.crm_deals.where(status: 'open')

    open_deals.find_each do |deal|
      threshold = stale_threshold_for(deal, override_days)
      next unless stale?(deal, threshold)
      next if pending_stale_activity?(deal)

      create_stale_activity(deal, threshold)
    end
  end

  # Limiar de inatividade por etapa (em dias)
  STAGE_THRESHOLDS = {
    'novo-atendimento'      => 2,
    'triagem-ia'            => 1,
    'qualificado'           => 3,
    'consulta-reuniao'      => 5,
    'documentos-solicitados' => 7,
    'em-analise-juridica'   => 7,
    'proposta-enviada'      => 3,
    'contrato-fechado'      => 14,
  }.freeze

  DEFAULT_STALE_DAYS = 5

  def stale_threshold_for(deal, override_days)
    return override_days.to_i if override_days.present?

    slug = deal.crm_pipeline_stage&.slug
    STAGE_THRESHOLDS.fetch(slug, DEFAULT_STALE_DAYS)
  end

  def stale?(deal, threshold_days)
    last_event = deal.crm_audit_events.order(created_at: :desc).first
    last_activity_at = last_event&.created_at || deal.created_at
    last_activity_at < threshold_days.days.ago
  end

  def pending_stale_activity?(deal)
    deal.crm_activities
        .where(completed_at: nil, kind: STALE_ACTIVITY_KIND)
        .where('created_at > ?', 24.hours.ago)
        .exists?
  end

  def create_stale_activity(deal, threshold_days)
    stage_name = deal.crm_pipeline_stage&.name || 'etapa desconhecida'

    activity = deal.crm_activities.create!(
      account: deal.account,
      contact_id: deal.contact_id,
      conversation_id: deal.conversation_id,
      kind: STALE_ACTIVITY_KIND,
      title: "Retomar deal parado em \"#{stage_name}\"",
      description: "Este deal está sem movimentação há #{threshold_days}+ dias. " \
                   "Revise o status, entre em contato com o cliente ou arquive o caso.",
      priority: deal.urgency_level.in?(%w[alta critica]) ? 'alta' : 'normal',
      due_at: Time.current + 24.hours,
      created_by_type: 'system',
      created_by_id: nil
    )

    Crm::AuditLogger.log(
      account: deal.account,
      actor: nil,
      action: 'stale_detected',
      target: deal,
      payload: {
        threshold_days: threshold_days,
        stage_slug: deal.crm_pipeline_stage&.slug,
        activity_id: activity.id
      }
    )

    Rails.logger.info(
      "[CRM StaleDetector] Deal ##{deal.id} (#{deal.title}) marcado como parado " \
      "em #{stage_name} após #{threshold_days}d — atividade ##{activity.id} criada."
    )
  end
end
