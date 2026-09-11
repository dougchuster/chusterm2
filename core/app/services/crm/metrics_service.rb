class Crm::MetricsService
  attr_reader :account

  def initialize(account)
    @account = account
  end

  # Métricas gerais do período
  def overview(period_days: 30)
    since = period_days.days.ago
    deals = account.crm_deals.where('crm_deals.created_at >= ?', since)

    {
      total_deals: deals.count,
      open_deals: deals.where(status: 'open').count,
      won_deals: deals.where(status: 'won').count,
      lost_deals: deals.where(status: 'lost').count,
      win_rate: calc_win_rate(deals),
      avg_score: calc_avg_score(deals),
      total_value: calc_total_value(deals),
      won_value: calc_won_value(deals),
      avg_time_to_close: calc_avg_time_to_close(deals)
    }
  end

  # Funil de conversão por estágio
  def stage_funnel(pipeline_id: nil)
    scope = account.crm_deals.open_deals
    scope = scope.where(crm_pipeline_id: pipeline_id) if pipeline_id

    stages = account.crm_pipeline_stages.active.ordered
    stages = stages.where(crm_pipeline_id: pipeline_id) if pipeline_id

    stages.map do |stage|
      count = scope.where(crm_pipeline_stage_id: stage.id).count
      {
        stage_id: stage.id,
        stage_name: stage.name,
        stage_slug: stage.slug,
        deal_count: count,
        avg_score: scope.where(crm_pipeline_stage_id: stage.id).average(:score_total)&.round(1) || 0
      }
    end
  end

  # Tempo médio em cada estágio (baseado em audit events de stage_entered)
  def time_in_stage(pipeline_id: nil, period_days: 90)
    since = period_days.days.ago

    # Busca transições de estágio via audit events. O nome da ação precisa ser
    # o mesmo que Crm::DealMover#log_stage_change grava ('deal_stage_changed',
    # payload com from_stage_id/to_stage_id) — qualquer divergência aqui zera
    # a métrica silenciosamente.
    transitions = CrmAuditEvent
      .where(account: account, action: 'deal_stage_changed')
      .where('created_at >= ?', since)

    # Agrupa por estágio destino e calcula duração média
    stage_times = {}
    transitions.order(:target_type, :target_id, :created_at).group_by { |e| e.target_id }.each do |_deal_id, events|
      events.each_cons(2) do |prev, curr|
        stage_id = prev.payload&.dig('to_stage_id') || prev.payload&.[]('stage_id')
        next unless stage_id

        duration_hours = ((curr.created_at - prev.created_at) / 1.hour).round(1)
        stage_times[stage_id] ||= []
        stage_times[stage_id] << duration_hours
      end
    end

    stages = account.crm_pipeline_stages.active.ordered
    stages = stages.where(crm_pipeline_id: pipeline_id) if pipeline_id

    stages.map do |stage|
      times = stage_times[stage.id] || []
      {
        stage_id: stage.id,
        stage_name: stage.name,
        avg_hours: times.any? ? (times.sum / times.size).round(1) : 0,
        min_hours: times.any? ? times.min.round(1) : 0,
        max_hours: times.any? ? times.max.round(1) : 0,
        sample_size: times.size
      }
    end
  end

  # Deals ganhos vs perdidos por mês
  def win_loss_trend(months: 6)
    results = []
    months.downto(0) do |i|
      month_start = i.months.ago.beginning_of_month
      month_end = i.months.ago.end_of_month

      won = account.crm_deals.where(status: 'won', closed_at: month_start..month_end).count
      lost = account.crm_deals.where(status: 'lost', closed_at: month_start..month_end).count

      results << {
        month: month_start.strftime('%Y-%m'),
        month_label: month_start.strftime('%b/%Y'),
        won: won,
        lost: lost,
        total: won + lost,
        win_rate: (won + lost).positive? ? (won.to_f / (won + lost) * 100).round(1) : 0
      }
    end
    results
  end

  # Top motivos de perda
  def top_loss_reasons(limit: 10)
    account.crm_deals
      .where(status: 'lost')
      .where.not(crm_loss_reason_id: nil)
      .joins(:crm_loss_reason)
      .group('crm_loss_reasons.name')
      .order('count_all DESC')
      .limit(limit)
      .count
      .map { |name, count| { reason: name, count: count } }
  end

  # Score médio por estágio
  def score_by_stage(pipeline_id: nil)
    scope = account.crm_deals.open_deals
    scope = scope.where(crm_pipeline_id: pipeline_id) if pipeline_id

    stages = account.crm_pipeline_stages.active.ordered
    stages = stages.where(crm_pipeline_id: pipeline_id) if pipeline_id

    stages.map do |stage|
      deals_in_stage = scope.where(crm_pipeline_stage_id: stage.id)
      scores = deals_in_stage.pluck(:score_total).compact
      {
        stage_name: stage.name,
        avg_score: scores.any? ? (scores.sum.to_f / scores.size).round(1) : 0,
        min_score: scores.any? ? scores.min : 0,
        max_score: scores.any? ? scores.max : 0,
        count: scores.size
      }
    end
  end

  # Distribuição por área jurídica
  def area_distribution
    account.crm_deals.open_deals
      .where.not(legal_area: [nil, ''])
      .group(:legal_area)
      .order('count_all DESC')
      .count
      .map { |area, count| { area: area, count: count } }
  end

  # Top deals por score
  def top_deals(limit: 10)
    account.crm_deals.open_deals
      .includes(:crm_pipeline_stage, :contact)
      .order(score_total: :desc)
      .limit(limit)
      .map do |deal|
        {
          id: deal.id,
          title: deal.title,
          score: deal.score_total,
          stage: deal.crm_pipeline_stage&.name,
          contact: deal.contact&.name,
          value: deal.value_estimate_cents,
          urgency: deal.urgency_level,
          legal_area: deal.legal_area
        }
      end
  end

  # Deals stale (sem atividade há N dias)
  #
  # Um deal só é stale quando NENHUMA atividade é mais nova que o cutoff — a
  # query antiga bastava uma atividade velha para marcar o deal, mesmo com
  # atividade recente. O MAX por deal sai em uma única query agregada e o
  # carregamento dos deals em um único where(id:), sem query por deal.
  def stale_deals(days: 7, limit: 20)
    cutoff = days.days.ago

    max_activity_at = CrmActivity
      .where(account: account, crm_deal_id: account.crm_deals.open_deals.select(:id))
      .group(:crm_deal_id)
      .maximum(:created_at)

    recent_deal_ids = max_activity_at.select { |_deal_id, max_at| max_at >= cutoff }.keys

    deals = account.crm_deals.open_deals
      .where.not(id: recent_deal_ids)
      .includes(:crm_pipeline_stage, :contact)
      .order(updated_at: :asc)
      .limit(limit)

    deals.map do |deal|
      last_activity_at = max_activity_at[deal.id]
      {
        id: deal.id,
        title: deal.title,
        stage: deal.crm_pipeline_stage&.name,
        contact: deal.contact&.name,
        days_stale: last_activity_at ? ((Time.current - last_activity_at) / 1.day).to_i : nil,
        score: deal.score_total
      }
    end
  end

  private

  def calc_win_rate(deals_scope)
    closed = deals_scope.where(status: %w[won lost])
    return 0 if closed.count.zero?

    (deals_scope.where(status: 'won').count.to_f / closed.count * 100).round(1)
  end

  def calc_avg_score(deals_scope)
    deals_scope.average(:score_total)&.round(1) || 0
  end

  def calc_total_value(deals_scope)
    (deals_scope.sum(:value_estimate_cents) / 100.0).round(2)
  end

  def calc_won_value(deals_scope)
    (deals_scope.where(status: 'won').sum(:value_estimate_cents) / 100.0).round(2)
  end

  def calc_avg_time_to_close(deals_scope)
    closed = deals_scope.where(status: %w[won lost]).where.not(closed_at: nil)

    # Média em uma única query (PostgreSQL) em vez de carregar todos os deals
    # fechados. O FLOOR por deal reproduz o `.to_i` do cálculo anterior em
    # memória; o resultado continua em dias, arredondado a 1 casa.
    avg_days = closed.pick(
      Arel.sql('AVG(FLOOR(EXTRACT(EPOCH FROM (closed_at - created_at)) / 86400))')
    )
    avg_days ? avg_days.to_f.round(1) : 0
  end
end
