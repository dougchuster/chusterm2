class Api::V1::Accounts::Captain::ScoreSettingsController < Api::V1::Accounts::BaseController
  DEFAULT_CLASSIFICATION_LABELS = {
    'baixo_potencial' => 'Frio',
    'medio_potencial' => 'Morno',
    'qualificado' => 'Quente',
    'prioridade_alta' => 'Prioridade alta'
  }.freeze

  DEFAULT_MEMORY_FIELDS = %w[
    nome
    idade
    profissao
    regime_previdenciario
    tempo_contribuicao
    cnis_status
    objetivo_previdenciario
    urgencia
    pendencias_documentais
  ].freeze

  DEFAULT_TRIAGE_FIELDS = %w[
    idade
    sexo
    profissao
    regime_previdenciario
    tempo_contribuicao
    tipo_vinculo
    possui_cnis
    simulacao_meu_inss
    objetivo
  ].freeze

  DEFAULT_SCORE_MODEL = 'previdenciario-planejamento-v1'.freeze

  before_action :ensure_admin!
  before_action :set_campaign, only: [:update]

  def index
    render json: {
      defaults: default_score_config,
      campaigns: campaigns.map { |campaign| serialize_campaign(campaign) },
      recent_states: recent_states.map { |state| serialize_state(state) }
    }
  end

  def update
    @campaign.update!(
      scoring_config: normalized_score_config(
        (@campaign.scoring_config || {}).deep_merge(score_setting_params.to_h)
      )
    )

    render json: { campaign: serialize_campaign(@campaign.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  def update_conversation_state
    state = Current.account.captain_conversation_states.find(params[:id])
    state.assign_attributes(conversation_state_params)
    state.save!

    render json: { state: serialize_state(state.reload) }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  def ensure_admin!
    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def campaigns
    @campaigns ||= Current.account.campaigns
                          .includes(:inbox, :captain_assistant)
                          .order(updated_at: :desc, id: :desc)
  end

  def set_campaign
    @campaign = Current.account.campaigns.find_by!(display_id: params[:campaign_id])
  end

  def recent_states
    @recent_states ||= Current.account.captain_conversation_states
                              .includes(:contact, :captain_assistant, conversation: [:campaign])
                              .order(updated_at: :desc)
                              .limit(30)
  end

  def score_setting_params
    params.require(:score_setting).permit(
      :score_model,
      :memory_enabled,
      :triage_enabled,
      :classification_enabled,
      :auto_move_on_score,
      weights: {},
      classification_thresholds: {},
      stage_mapping: {},
      classification_labels: {},
      memory_fields: [],
      triage_required_fields: [],
      triage_questions: [],
      handoff_rules: []
    )
  end

  def conversation_state_params
    permitted = params.require(:conversation_state).permit(
      :score_total,
      :score_classification,
      :context_summary,
      :ai_mode,
      :handoff_reason,
      score_payload: {}
    )

    permitted[:score_total] = permitted[:score_total].to_i if permitted.key?(:score_total)
    permitted
  end

  def serialize_campaign(campaign)
    config = normalized_score_config(campaign.scoring_config || {})
    counts = state_counts_for(campaign.id)

    {
      id: campaign.display_id,
      record_id: campaign.id,
      title: campaign.title,
      description: campaign.description,
      enabled: campaign.enabled,
      campaign_status: campaign.campaign_status,
      campaign_type: campaign.campaign_type,
      inbox_id: campaign.inbox_id,
      inbox_name: campaign.inbox&.name,
      captain_assistant_id: campaign.captain_assistant_id,
      captain_assistant_name: campaign.captain_assistant&.name,
      scoring_config: config,
      score_summary: score_summary(counts),
      updated_at: campaign.updated_at
    }
  end

  def serialize_state(state)
    conversation = state.conversation
    campaign = conversation&.campaign

    {
      id: state.id,
      conversation_id: state.conversation_id,
      conversation_display_id: conversation&.display_id,
      contact_id: state.contact_id,
      contact_name: state.contact&.name,
      campaign_id: campaign&.display_id,
      campaign_title: campaign&.title,
      captain_assistant_id: state.captain_assistant_id,
      captain_assistant_name: state.captain_assistant&.name,
      score_total: state.score_total,
      score_classification: state.score_classification,
      score_bucket: score_bucket(state.score_classification),
      ai_mode: state.ai_mode,
      context_summary: state.context_summary,
      score_payload: state.score_payload || {},
      handoff_reason: state.handoff_reason,
      updated_at: state.updated_at
    }
  end

  def state_counts_for(campaign_id)
    grouped_state_counts.each_with_object(Hash.new(0)) do |((group_campaign_id, classification), count), result|
      next unless group_campaign_id == campaign_id

      result[classification.presence || 'sem_classificacao'] += count
    end
  end

  def grouped_state_counts
    @grouped_state_counts ||= Current.account.captain_conversation_states
                                     .joins(:conversation)
                                     .group('conversations.campaign_id', 'captain_conversation_states.score_classification')
                                     .count
  end

  def score_summary(counts)
    {
      total: counts.values.sum,
      frio: counts['baixo_potencial'].to_i,
      morno: counts['medio_potencial'].to_i,
      quente: counts['qualificado'].to_i + counts['prioridade_alta'].to_i,
      prioridade_alta: counts['prioridade_alta'].to_i,
      sem_classificacao: counts['sem_classificacao'].to_i,
      raw: counts
    }
  end

  def score_bucket(classification)
    case classification
    when 'baixo_potencial'
      'frio'
    when 'medio_potencial'
      'morno'
    when 'qualificado', 'prioridade_alta'
      'quente'
    else
      'sem_classificacao'
    end
  end

  def default_score_config
    {
      'score_model' => DEFAULT_SCORE_MODEL,
      'memory_enabled' => true,
      'triage_enabled' => true,
      'classification_enabled' => true,
      'auto_move_on_score' => true,
      'weights' => Crm::LeadScoreCalculator::DEFAULT_WEIGHTS,
      'classification_thresholds' => CrmScoreClassification::DEFAULT_THRESHOLDS,
      'stage_mapping' => Crm::LeadScoreCalculator::DEFAULT_STAGE_MAPPING,
      'classification_labels' => DEFAULT_CLASSIFICATION_LABELS,
      'memory_fields' => DEFAULT_MEMORY_FIELDS,
      'triage_required_fields' => DEFAULT_TRIAGE_FIELDS
    }
  end

  def normalized_score_config(config)
    config = (config || {}).deep_stringify_keys
    defaults = default_score_config

    defaults.merge(config).merge(
      'weights' => normalize_integer_hash(config['weights'], defaults['weights']),
      'classification_thresholds' => normalize_integer_hash(config['classification_thresholds'], defaults['classification_thresholds']),
      'stage_mapping' => normalize_string_hash(config['stage_mapping'], defaults['stage_mapping']),
      'classification_labels' => normalize_string_hash(config['classification_labels'], defaults['classification_labels']),
      'memory_fields' => normalize_array(config['memory_fields'], defaults['memory_fields']),
      'triage_required_fields' => normalize_array(config['triage_required_fields'], defaults['triage_required_fields']),
      'score_model' => config['score_model'].presence || defaults['score_model'],
      'memory_enabled' => boolean_value(config['memory_enabled'], defaults['memory_enabled']),
      'triage_enabled' => boolean_value(config['triage_enabled'], defaults['triage_enabled']),
      'classification_enabled' => boolean_value(config['classification_enabled'], defaults['classification_enabled']),
      'auto_move_on_score' => boolean_value(config['auto_move_on_score'], defaults['auto_move_on_score'])
    )
  end

  def normalize_integer_hash(value, defaults)
    source = value.is_a?(Hash) ? value.deep_stringify_keys : {}

    defaults.each_with_object({}) do |(key, fallback), result|
      result[key] = source.fetch(key, fallback).to_i.clamp(0, 100)
    end
  end

  def normalize_string_hash(value, defaults)
    source = value.is_a?(Hash) ? value.deep_stringify_keys : {}

    defaults.each_with_object({}) do |(key, fallback), result|
      result[key] = source.fetch(key, fallback).to_s.presence || fallback
    end
  end

  def normalize_array(value, defaults)
    array = value.is_a?(Array) ? value : defaults
    array.map { |item| item.to_s.strip }.reject(&:blank?).uniq
  end

  def boolean_value(value, fallback)
    return fallback if value.nil?
    return value if value == true || value == false

    ActiveModel::Type::Boolean.new.cast(value)
  end
end
