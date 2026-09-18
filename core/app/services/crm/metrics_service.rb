class Crm::MetricsService
  attr_reader :account

  def initialize(account)
    @account = account
  end

  # Métricas gerais do período.
  #
  # Dois coortes diferentes, de propósito: volume (total/open/valor em
  # aberto/score) mede deals CRIADOS no período; resultado (won/lost/win_rate/
  # valor ganho/tempo de fechamento) mede deals FECHADOS no período por
  # closed_at — medir win_rate por coorte de criação mistura deals que ainda
  # não tiveram chance de fechar e produzia percentuais incoerentes.
  def overview(period_days: 30)
    since = period_days.days.ago
    created = account.crm_deals.where('crm_deals.created_at >= ?', since)
    closed = account.crm_deals.where(closed_at: since..Time.current, status: %w[won lost])

    {
      total_deals: created.count,
      open_deals: created.where(status: 'open').count,
      won_deals: closed.where(status: 'won').count,
      lost_deals: closed.where(status: 'lost').count,
      win_rate: calc_win_rate(closed),
      avg_score: calc_avg_score(created),
      total_value: calc_total_value(created),
      won_value: calc_won_value(closed),
      avg_time_to_close: calc_avg_time_to_close(closed)
    }
  end

  # Funil de conversão por estágio.
  #
  # Sem pipeline_id, cai no funil default da conta — somar etapas de funis
  # diferentes num único funil produzia um gráfico que não correspondia a
  # nenhum funil real. Contagem e média saem em UM GROUP BY (antes eram
  # 2 queries por etapa).
  def stage_funnel(pipeline_id: nil)
    pipeline = resolve_pipeline(pipeline_id)
    scope = account.crm_deals.open_deals.where(crm_pipeline: pipeline)

    aggregates = scope.group(:crm_pipeline_stage_id).pluck(
      :crm_pipeline_stage_id,
      Arel.sql('COUNT(*)'),
      Arel.sql('AVG(score_total)')
    ).to_h { |stage_id, count, avg| [stage_id, { count: count, avg: avg }] }

    pipeline_stages(pipeline).map do |stage|
      agg = aggregates[stage.id] || { count: 0, avg: nil }
      {
        stage_id: stage.id,
        stage_name: stage.name,
        stage_slug: stage.slug,
        deal_count: agg[:count],
        avg_score: agg[:avg]&.round(1) || 0
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

    pipeline = resolve_pipeline(pipeline_id)

    pipeline_stages(pipeline).map do |stage|
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

  # Score médio por estágio — um GROUP BY com avg/min/max/count (antes eram
  # 2 queries por etapa). COUNT(score_total) ignora NULLs como o `.compact`
  # anterior.
  def score_by_stage(pipeline_id: nil)
    pipeline = resolve_pipeline(pipeline_id)
    scope = account.crm_deals.open_deals.where(crm_pipeline: pipeline)

    aggregates = scope.group(:crm_pipeline_stage_id).pluck(
      :crm_pipeline_stage_id,
      Arel.sql('COUNT(score_total)'),
      Arel.sql('AVG(score_total)'),
      Arel.sql('MIN(score_total)'),
      Arel.sql('MAX(score_total)')
    ).to_h do |stage_id, count, avg, min, max|
      [stage_id, { count: count, avg: avg, min: min, max: max }]
    end

    pipeline_stages(pipeline).map do |stage|
      agg = aggregates[stage.id] || { count: 0, avg: nil, min: nil, max: nil }
      {
        stage_name: stage.name,
        avg_score: agg[:avg]&.round(1) || 0,
        min_score: agg[:min] || 0,
        max_score: agg[:max] || 0,
        count: agg[:count]
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

  # 6.2 — Tempo até a 1ª resposta humana.
  #
  # Coorte: deals criados no período que já têm conversa principal. O relógio
  # começa na 1ª mensagem do cliente (fallback: criação da conversa, depois do
  # deal) e para na 1ª mensagem humana (outgoing/template com sender User).
  # Respostas anteriores ao 1º incoming são fluxo outbound — entram como
  # respondidos, não como tempo de resposta. Deals sem resposta humana e com
  # espera acima do limiar saem na lista `unanswered`.
  def first_response_metrics(period_days: 30, sla_minutes: 15, unattended_hours: 1)
    since = period_days.days.ago
    deals = account.crm_deals
      .where('crm_deals.created_at >= ?', since)
      .where.not(conversation_id: nil)
      .pluck(:id, :conversation_id, :created_at, :title)

    conversation_ids = deals.pluck(1).uniq
    starts = first_incoming_at(conversation_ids)
    replies = first_human_reply_at(conversation_ids)
    convo_created = Conversation.where(id: conversation_ids).pluck(:id, :created_at).to_h

    durations = []
    unanswered = []
    cutoff = unattended_hours.hours.ago

    deals.each do |deal_id, conversation_id, deal_created_at, title|
      started_at = starts[conversation_id] || convo_created[conversation_id] || deal_created_at
      replied_at = replies[conversation_id]

      if replied_at && started_at && replied_at >= started_at
        durations << ((replied_at - started_at) / 60.0)
      elsif replied_at.nil? && started_at && started_at < cutoff
        unanswered << {
          id: deal_id,
          title: title,
          waiting_minutes: ((Time.current - started_at) / 60.0).round
        }
      end
    end

    {
      deals_with_conversation: deals.size,
      answered: durations.size,
      avg_first_response_minutes: durations.any? ? (durations.sum / durations.size).round(1) : 0,
      within_sla_pct: durations.any? ? (durations.count { |m| m <= sla_minutes }.to_f / durations.size * 100).round(1) : 0,
      sla_minutes: sla_minutes,
      unattended_hours: unattended_hours,
      unanswered: unanswered.sort_by { |entry| -entry[:waiting_minutes] }
    }
  end

  # 6.3 — Previsão ponderada por etapa do funil.
  #
  # Peso = probability_pct do deal; quando 0 (não informado), cai na
  # probability_pct da etapa. Um único GROUP BY emite count/valor bruto/valor
  # ponderado — sem query por etapa.
  def weighted_forecast(pipeline_id: nil)
    pipeline = resolve_pipeline(pipeline_id)
    stages = pipeline_stages(pipeline)

    aggregates = account.crm_deals.open_deals
      .where(crm_pipeline: pipeline)
      .joins(:crm_pipeline_stage)
      .group(:crm_pipeline_stage_id)
      .pluck(
        :crm_pipeline_stage_id,
        Arel.sql('COUNT(*)'),
        Arel.sql('COALESCE(SUM(value_estimate_cents), 0)'),
        Arel.sql(
          'COALESCE(SUM(value_estimate_cents * ' \
          'COALESCE(NULLIF(crm_deals.probability_pct, 0), crm_pipeline_stages.probability_pct) / 100.0), 0)'
        )
      ).to_h do |stage_id, count, total, weighted|
        [stage_id, { count: count, total: total, weighted: weighted }]
      end

    per_stage = stages.map do |stage|
      agg = aggregates[stage.id] || { count: 0, total: 0, weighted: 0 }
      {
        stage_id: stage.id,
        stage_name: stage.name,
        probability_pct: stage.probability_pct,
        deal_count: agg[:count],
        total_value: (agg[:total] / 100.0).round(2),
        weighted_value: (agg[:weighted] / 100.0).round(2)
      }
    end

    {
      pipeline_id: pipeline&.id,
      pipeline_name: pipeline&.name,
      total_value: per_stage.sum { |s| s[:total_value] }.round(2),
      weighted_value: per_stage.sum { |s| s[:weighted_value] }.round(2),
      stages: per_stage
    }
  end

  private

  def first_incoming_at(conversation_ids)
    return {} if conversation_ids.empty?

    Message.where(account_id: account.id, conversation_id: conversation_ids, message_type: :incoming)
      .unscope(:order)
      .group(:conversation_id)
      .minimum(:created_at)
  end

  def first_human_reply_at(conversation_ids)
    return {} if conversation_ids.empty?

    Message.where(account_id: account.id, conversation_id: conversation_ids)
      .where(message_type: %i[outgoing template], sender_type: 'User')
      .unscope(:order)
      .group(:conversation_id)
      .minimum(:created_at)
  end

  # Sem pipeline_id explícito, as métricas por etapa medem o funil default —
  # nunca uma mistura de todos os funis da conta.
  def resolve_pipeline(pipeline_id)
    pipelines = account.crm_pipelines.active.default_first
    return pipelines.find_by(id: pipeline_id) if pipeline_id.present?

    pipelines.first
  end

  def pipeline_stages(pipeline)
    return CrmPipelineStage.none if pipeline.nil?

    pipeline.crm_pipeline_stages.active.ordered
  end

  def calc_win_rate(closed_scope)
    total = closed_scope.count
    return 0 if total.zero?

    (closed_scope.where(status: 'won').count.to_f / total * 100).round(1)
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
