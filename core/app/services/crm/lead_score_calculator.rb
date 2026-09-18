class Crm::LeadScoreCalculator
  CLASSIFICATION_THRESHOLDS = CrmScoreClassification::DEFAULT_THRESHOLDS

  DEFAULT_WEIGHTS = {
    'fit' => 20,
    'urgency' => 15,
    'economic' => 15,
    'documents' => 15,
    'clarity' => 10,
    'engagement' => 10,
    'payment_capacity' => 10,
    'conflict' => 5
  }.freeze

  DEFAULT_STAGE_MAPPING = {
    'baixo_potencial' => 'novo-atendimento',
    'medio_potencial' => 'triagem-ia',
    'qualificado' => 'qualificado',
    'prioridade_alta' => 'consulta-reuniao'
  }.freeze

  COMPONENT_KEYS = {
    fit_score: 'fit',
    urgency_score: 'urgency',
    economic_score: 'economic',
    documents_score: 'documents',
    clarity_score: 'clarity',
    engagement_score: 'engagement',
    payment_capacity_score: 'payment_capacity',
    conflict_score: 'conflict'
  }.freeze

  COMPONENT_LABELS = {
    'fit' => 'Fit jurídico',
    'urgency' => 'Urgência',
    'economic' => 'Potencial econômico',
    'documents' => 'Documentos',
    'clarity' => 'Clareza',
    'engagement' => 'Engajamento',
    'payment_capacity' => 'Capacidade de pagamento',
    'conflict' => 'Conflito'
  }.freeze

  CLASSIFICATION_LABELS = {
    'prioridade_alta' => 'prioridade alta',
    'qualificado' => 'qualificado',
    'medio_potencial' => 'potencial médio',
    'baixo_potencial' => 'potencial baixo'
  }.freeze

  def initialize(deal, actor: nil, move_deal: true, sync_conversation_state: true)
    @deal = deal
    @actor = actor
    @move_deal = move_deal
    @sync_conversation_state = sync_conversation_state
  end

  def perform
    scores = calculate_scores
    total = scores.values.sum.clamp(0, 100)
    classification = classify(total)
    factors = build_factors(scores, total, classification)
    reason = build_reason(factors)

    ActiveRecord::Base.transaction do
      score = @deal.crm_lead_scores.create!(
        account: @deal.account,
        contact_id: @deal.contact_id,
        **scores,
        total_score: total,
        classification: classification,
        reason: reason,
        factors: factors,
        calculated_at: Time.current,
        calculated_by: calculated_by
      )

      @deal.update!(score_total: total, score_classification: classification, score_reason: reason)
      sync_captain_conversation_state(score, factors) if @sync_conversation_state
      move_deal_for_score(classification) if @move_deal
      score
    end
  end

  private

  def weights
    @weights ||= begin
      configured_weights = scoring_config['weights'].presence || scoring_config
      DEFAULT_WEIGHTS.merge(configured_weights.slice(*DEFAULT_WEIGHTS.keys)).transform_values(&:to_i)
    end
  end

  def thresholds
    @thresholds ||= begin
      configured_thresholds = scoring_config['classification_thresholds'].presence ||
                              scoring_config['thresholds'].presence ||
                              {}
      CLASSIFICATION_THRESHOLDS.merge(configured_thresholds.slice(*CLASSIFICATION_THRESHOLDS.keys)).transform_values(&:to_i)
    end
  end

  def stage_mapping
    @stage_mapping ||= DEFAULT_STAGE_MAPPING.merge((scoring_config['stage_mapping'].presence || {}).slice(*DEFAULT_STAGE_MAPPING.keys))
  end

  # Fase 2: pack define a base; pipeline e campanha sobrescrevem nessa ordem.
  def scoring_config
    @scoring_config ||= deep_merge_config(
      deep_merge_config(pack_scoring_config, pipeline_scoring_config),
      campaign_scoring_config
    )
  end

  def pack_scoring_config
    @pack_scoring_config ||= if @deal.account&.feature_enabled?('crm_universal')
                               Crm::PackOptions.installed_packs(@deal.account)
                                               .map(&:scoring)
                                               .reduce({}) { |merged, config| deep_merge_config(merged, hash_config(config)) }
                             else
                               {}
                             end
  end

  def calculate_scores
    return zero_scores if insufficient_data?

    {
      fit_score: fit_score,
      urgency_score: urgency_score,
      economic_score: economic_score,
      documents_score: documents_score,
      clarity_score: clarity_score,
      engagement_score: engagement_score,
      payment_capacity_score: payment_capacity_score,
      conflict_score: conflict_score
    }
  end

  def zero_scores
    COMPONENT_KEYS.keys.index_with(0)
  end

  def insufficient_data?
    captain_triage['data_quality'] == 'insufficient'
  end

  def fit_score
    @deal.legal_area.present? ? weights['fit'] : 0
  end

  def urgency_score
    pct = case @deal.urgency_level
          when 'critica' then 1.0
          when 'alta' then 0.8
          when 'media' then 0.5
          when 'baixa' then 0.2
          else 0.0
          end
    (weights['urgency'] * pct).round
  end

  def economic_score
    cents = @deal.value_estimate_cents.to_i
    pct = if cents > 50_000_00 then 1.0
          elsif cents > 10_000_00 then 0.67
          elsif cents > 1_000_00 then 0.33
          else
            case captain_triage['economic_potential']
            when 'alto' then 1.0
            when 'medio' then 0.67
            when 'baixo' then 0.33
            else 0.0
            end
          end
    (weights['economic'] * pct).round
  end

  def documents_score
    pct = case @deal.documents_status
          when 'completo' then 1.0
          when 'parcial' then 0.53
          when 'solicitado' then 0.27
          else 0.0
          end
    (weights['documents'] * pct).round
  end

  def clarity_score
    (@deal.summary.present? && @deal.case_type.present?) ? weights['clarity'] : 0
  end

  def engagement_score
    pct = case captain_triage['engagement_level']
          when 'alto' then 1.0
          when 'medio' then 0.7
          when 'baixo' then 0.3
          else
            @deal.crm_activities.count.positive? ? 1.0 : 0.5
          end
    (weights['engagement'] * pct).round
  end

  def payment_capacity_score
    return 0 if captain_triage['payment_capacity'] == 'nao_informado'

    pct = captain_triage['payment_capacity'] == 'informado' ? 1.0 : 0.5
    (weights['payment_capacity'] * pct).round
  end

  def conflict_score
    @deal.conflict_check_status == 'ok' ? weights['conflict'] : 0
  end

  def classify(total)
    CrmScoreClassification.classify(total, thresholds)
  end

  def build_factors(scores, total, classification)
    components = COMPONENT_KEYS.each_with_object({}) do |(score_key, weight_key), result|
      result[weight_key] = {
        score: scores[score_key],
        max_score: weights[weight_key],
        signal: signal_for(weight_key),
        evidence: evidence_for(weight_key)
      }
    end

    {
      total_score: total,
      classification: classification,
      calculated_by: calculated_by,
      weights: weights,
      thresholds: thresholds,
      stage_mapping: stage_mapping,
      auto_move_on_score: scoring_config['auto_move_on_score'] == true,
      components: components
    }
  end

  def build_reason(factors)
    top_components = factors[:components]
                     .sort_by { |_key, data| -data[:score].to_i }
                     .first(3)
                     .map { |key, data| "#{COMPONENT_LABELS[key.to_s] || key} #{data[:score]}/#{data[:max_score]}" }
                     .join(', ')

    classification = CLASSIFICATION_LABELS[factors[:classification].to_s] || factors[:classification]
    "Score #{factors[:total_score]} — #{classification}. Principais fatores: #{top_components}."
  end

  def move_deal_for_score(classification)
    return unless scoring_config['auto_move_on_score'] == true

    target_stage = stage_for_classification(classification)
    return unless target_stage
    return if @deal.crm_pipeline_stage_id == target_stage.id
    return if @deal.crm_pipeline_stage.position.to_i > target_stage.position.to_i

    Crm::DealMover.new(deal: @deal, stage_id: target_stage.id, actor: @actor).perform
  end

  def stage_for_classification(classification)
    slug = stage_mapping[classification]
    return if slug.blank?

    @deal.crm_pipeline.crm_pipeline_stages.active.find_by(slug: slug)
  end

  def sync_captain_conversation_state(score, factors)
    return if @deal.conversation_id.blank?

    state = @deal.account.captain_conversation_states.find_or_initialize_by(conversation_id: @deal.conversation_id)
    state.contact_id ||= @deal.contact_id
    state.crm_deal_id = @deal.id
    state.score_total = score.total_score
    state.score_classification = score.classification
    state.score_payload = factors
    state.context_summary = @deal.summary if @deal.summary.present?
    state.save!
  end

  def signal_for(weight_key)
    case weight_key
    when 'fit' then @deal.legal_area
    when 'urgency' then @deal.urgency_level
    when 'economic' then @deal.value_estimate_cents.to_i.positive? ? @deal.value_estimate_cents : captain_triage['economic_potential']
    when 'documents' then @deal.documents_status
    when 'clarity' then { summary: @deal.summary.present?, case_type: @deal.case_type.present? }
    when 'engagement' then captain_triage['engagement_level']
    when 'payment_capacity' then captain_triage['payment_capacity']
    when 'conflict' then @deal.conflict_check_status
    end
  end

  def evidence_for(weight_key)
    case weight_key
    when 'fit' then @deal.legal_area.present? ? "Categoria identificada: #{@deal.legal_area}" : 'Categoria ainda nao identificada'
    when 'urgency' then @deal.urgency_level.present? ? "Urgencia: #{@deal.urgency_level}" : 'Urgencia ausente'
    when 'economic' then @deal.value_estimate_cents.to_i.positive? ? 'Valor estimado informado' : 'Usando potencial economico da triagem'
    when 'documents' then "Documentos: #{@deal.documents_status || 'nao informado'}"
    when 'clarity' then @deal.summary.present? && @deal.case_type.present? ? 'Resumo e subcategoria preenchidos' : 'Faltam resumo ou subcategoria'
    when 'engagement' then captain_triage['engagement_level'].presence || 'Engajamento inferido por atividades'
    when 'payment_capacity' then captain_triage['payment_capacity'].presence || 'Capacidade financeira nao informada'
    when 'conflict' then @deal.conflict_check_status == 'ok' ? 'Conflito verificado como ok' : 'Conflito ainda pendente'
    end
  end

  def calculated_by
    return 'campaign_config' if campaign_scoring_config.present?
    return 'pipeline_config' if pipeline_scoring_config.present?

    'rule_based'
  end

  def captain_triage
    @captain_triage ||= (@deal.custom_fields || {})['captain_triage'] || {}
  end

  def pipeline_scoring_config
    @pipeline_scoring_config ||= hash_config(@deal.crm_pipeline&.scoring_config)
  end

  def campaign_scoring_config
    @campaign_scoring_config ||= begin
      config = hash_config(@deal.conversation&.campaign&.scoring_config)
      if config.blank?
        {}
      else
        configured_pipeline_id = config['crm_pipeline_id'].presence || config[:crm_pipeline_id].presence
        if configured_pipeline_id.present? && configured_pipeline_id.to_i != @deal.crm_pipeline_id
          {}
        else
          config
        end
      end
    end
  end

  def deep_merge_config(base, override)
    base.deep_merge(override) do |_key, old_value, new_value|
      new_value.nil? ? old_value : new_value
    end
  end

  def hash_config(config)
    config.is_a?(Hash) ? config.to_h : {}
  end
end
