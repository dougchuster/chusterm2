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
    # B10: 3 queries batcheadas em vez de N+1 por deal (último audit event,
    # última atividade da conversa e atividade de stale pendente).
    open_deals = account.crm_deals
                        .where(status: 'open')
                        .includes(:crm_pipeline_stage, :conversation)
                        .to_a
    return if open_deals.empty?

    deal_ids = open_deals.map(&:id)
    last_audit_at = CrmAuditEvent.where(account: account, target_type: 'CrmDeal', target_id: deal_ids)
                                 .group(:target_id).maximum(:created_at)
    last_conversation_at = last_conversation_activity(open_deals)
    pending_stale_ids = pending_stale_deal_ids(account, deal_ids)

    universal = account.feature_enabled?('crm_universal')
    open_deals.each do |deal|
      threshold = stale_threshold_for(deal, override_days, universal)
      next unless stale?(deal, threshold, last_audit_at[deal.id], last_conversation_at[deal.id])
      next if pending_stale_ids.include?(deal.id)

      create_stale_activity(deal, threshold)
    end
  end

  def pending_stale_deal_ids(account, deal_ids)
    account.crm_activities
           .pending
           .where(crm_deal_id: deal_ids, kind: STALE_ACTIVITY_KIND, created_by_type: 'system')
           .where('title LIKE ?', 'Retomar deal parado em "%')
           .distinct
           .pluck(:crm_deal_id)
           .to_set
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

  def stale_threshold_for(deal, override_days, universal)
    return override_days.to_i if override_days.present?

    # Fase 2: conta universal usa o SLA declarado na própria etapa
    # (expected_duration_hours); conta legada mantém o mapa por slug.
    if universal
      hours = deal.crm_pipeline_stage&.expected_duration_hours
      return (hours / 24.0).ceil if hours.to_i.positive?

      return DEFAULT_STALE_DAYS
    end

    slug = deal.crm_pipeline_stage&.slug
    STAGE_THRESHOLDS.fetch(slug, DEFAULT_STALE_DAYS)
  end

  # B10: "parado" considera também a última atividade das conversas do deal
  # (principal + N:N) — uma mensagem nova do cliente reabre o relógio mesmo
  # sem audit event.
  def last_conversation_activity(deals)
    deal_ids = deals.map(&:id)
    linked = CrmDealConversation.where(crm_deal_id: deal_ids)
                                .joins(:conversation)
                                .group(:crm_deal_id)
                                .maximum('conversations.last_activity_at')

    deals.each_with_object({}) do |deal, map|
      map[deal.id] = [deal.conversation&.last_activity_at, linked[deal.id]].compact.max
    end
  end

  def stale?(deal, threshold_days, last_audit_at, last_conversation_at)
    last_activity_at = [
      last_audit_at,
      last_conversation_at,
      deal.created_at
    ].compact.max

    last_activity_at < threshold_days.days.ago
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
