class Api::V1::Accounts::Captain::AgentConfigsController < Api::V1::Accounts::BaseController
  ASSISTANT_CONFIG_KEYS = %w[
    product_name feature_faq feature_memory feature_citation feature_contact_attributes
    welcome_message handoff_message resolution_message instructions temperature
    llm_provider llm_main_model llm_fallback_model llm_classifier_model llm_summarizer_model
    llm_max_tokens llm_timeout_seconds llm_cost_limit_cents_per_conversation
  ].freeze

  ACCOUNT_FEATURE_KEYS = %w[
    editor assistant copilot label_suggestion audio_transcription help_center_search
  ].freeze

  before_action :ensure_admin!
  before_action :set_assistant

  def show
    render json: payload
  end

  def update
    ActiveRecord::Base.transaction do
      update_assistant if params[:assistant].present?
      update_account_preferences if params[:account_preferences].present?
      update_inboxes if params[:inboxes].present?
    end

    render json: payload
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def ensure_admin!
    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def set_assistant
    @assistant = Current.account.captain_assistants.find(params[:assistant_id] || params[:id])
  end

  def update_assistant
    @assistant.update!(assistant_params)
  end

  def assistant_params
    permitted = params.require(:assistant).permit(
      :name, :description,
      response_guidelines: [],
      guardrails: [],
      config: ASSISTANT_CONFIG_KEYS
    )

    normalize_assistant_config(permitted)
  end

  def normalize_assistant_config(permitted)
    return permitted unless permitted[:config].present?

    config = permitted[:config].to_h.stringify_keys.slice(*ASSISTANT_CONFIG_KEYS)
    config['temperature'] = bounded_float(config['temperature'], 0.0, 2.0) if config.key?('temperature')
    config['llm_max_tokens'] = optional_integer(config['llm_max_tokens']) if config.key?('llm_max_tokens')
    config['llm_timeout_seconds'] = optional_integer(config['llm_timeout_seconds']) if config.key?('llm_timeout_seconds')
    if config.key?('llm_cost_limit_cents_per_conversation')
      config['llm_cost_limit_cents_per_conversation'] = optional_integer(config['llm_cost_limit_cents_per_conversation'])
    end

    %w[feature_faq feature_memory feature_citation feature_contact_attributes].each do |key|
      config[key] = boolean_value(config[key]) if config.key?(key)
    end

    permitted[:config] = (@assistant.config || {}).merge(config)
    permitted
  end

  def update_account_preferences
    preferences = params.require(:account_preferences).permit(
      :captain_auto_resolve_mode,
      :keep_pending_on_bot_failure,
      captain_features: {},
      captain_models: {}
    )

    if preferences[:captain_features].present?
      Current.account.captain_features = (Current.account.captain_features || {}).merge(
        normalize_account_features(preferences[:captain_features])
      )
    end

    if preferences[:captain_models].present?
      Current.account.captain_models = (Current.account.captain_models || {}).merge(
        normalize_account_models(preferences[:captain_models])
      )
    end

    if preferences.key?(:captain_auto_resolve_mode)
      Current.account.captain_auto_resolve_mode = preferences[:captain_auto_resolve_mode]
    end

    if preferences.key?(:keep_pending_on_bot_failure)
      Current.account.keep_pending_on_bot_failure = boolean_value(preferences[:keep_pending_on_bot_failure])
    end

    Current.account.save!
  end

  def normalize_account_features(raw_features)
    raw_features.to_h.stringify_keys.slice(*ACCOUNT_FEATURE_KEYS).transform_values { |value| boolean_value(value) }
  end

  def normalize_account_models(raw_models)
    raw_models.to_h.stringify_keys.slice(*ACCOUNT_FEATURE_KEYS).compact_blank
  end

  def update_inboxes
    Array(params[:inboxes]).each do |raw_inbox|
      values = raw_inbox.to_unsafe_h.stringify_keys
      inbox_id = values['inbox_id']
      captain_inbox = @assistant.captain_inboxes.find_by!(inbox_id: inbox_id)

      captain_inbox.update!(
        values.slice('enabled', 'auto_reply_enabled', 'ai_mode', 'handoff_strategy', 'routing_config')
      )
    end
  end

  def payload
    {
      assistant: serialize_assistant,
      account_preferences: serialize_account_preferences,
      inboxes: @assistant.captain_inboxes.includes(:inbox).map { |captain_inbox| serialize_captain_inbox(captain_inbox) },
      inventory: inventory_payload,
      model_catalog: model_catalog
    }
  end

  def serialize_assistant
    {
      id: @assistant.id,
      name: @assistant.name,
      description: @assistant.description,
      config: (@assistant.config || {}).slice(*ASSISTANT_CONFIG_KEYS),
      llm_config_with_defaults: @assistant.llm_config_with_defaults,
      response_guidelines: @assistant.response_guidelines || [],
      guardrails: @assistant.guardrails || [],
      available_tools_count: @assistant.available_agent_tools.count,
      updated_at: @assistant.updated_at
    }
  end

  def serialize_account_preferences
    preferences = Current.account.captain_preferences

    {
      captain_features: preferences[:features] || {},
      captain_models: preferences[:models] || {},
      captain_auto_resolve_mode: Current.account.captain_auto_resolve_mode,
      keep_pending_on_bot_failure: Current.account.keep_pending_on_bot_failure
    }
  end

  def serialize_captain_inbox(captain_inbox)
    inbox = captain_inbox.inbox

    {
      id: captain_inbox.id,
      inbox_id: captain_inbox.inbox_id,
      inbox_name: inbox&.name,
      inbox_type: inbox&.inbox_type,
      enabled: captain_inbox.enabled,
      auto_reply_enabled: captain_inbox.auto_reply_enabled,
      ai_mode: captain_inbox.ai_mode,
      handoff_strategy: captain_inbox.handoff_strategy,
      routing_config: captain_inbox.routing_config || {},
      responsible: captain_inbox.responsible?,
      active_for_auto_reply: captain_inbox.active_for_auto_reply?,
      updated_at: captain_inbox.updated_at
    }
  end

  def inventory_payload
    {
      faqs: faq_inventory,
      documents: document_inventory,
      scenarios: scenario_inventory,
      playbooks: playbook_inventory,
      tools: tools_inventory,
      campaigns: campaign_inventory,
      conversation_memory: memory_inventory,
      flows: flow_inventory
    }
  end

  def faq_inventory
    records = @assistant.responses.ordered.limit(5)
    {
      count: @assistant.responses.count,
      approved_count: @assistant.responses.approved.count,
      pending_count: @assistant.responses.pending.count,
      records: records.map { |response| { id: response.id, title: response.question, status: response.status, updated_at: response.updated_at } }
    }
  end

  def document_inventory
    records = @assistant.documents.ordered.limit(5)
    {
      count: @assistant.documents.count,
      available_count: @assistant.documents.available.count,
      in_progress_count: @assistant.documents.in_progress.count,
      records: records.map { |document| { id: document.id, title: document.name.presence || document.external_link, status: document.status, updated_at: document.updated_at } }
    }
  end

  def scenario_inventory
    records = @assistant.scenarios.order(updated_at: :desc).limit(5)
    {
      count: @assistant.scenarios.count,
      enabled_count: @assistant.scenarios.enabled.count,
      records: records.map { |scenario| { id: scenario.id, title: scenario.title, status: scenario.enabled ? 'enabled' : 'disabled', updated_at: scenario.updated_at } }
    }
  end

  def playbook_inventory
    scope = Current.account.captain_playbooks.where(assistant_id: [@assistant.id, nil])
    records = scope.ordered.limit(5)
    {
      count: scope.count,
      active_count: scope.active.count,
      records: records.map { |playbook| { id: playbook.id, title: playbook.name, status: playbook.active ? 'active' : 'inactive', updated_at: playbook.updated_at } }
    }
  end

  def tools_inventory
    scope = Current.account.respond_to?(:captain_custom_tools) ? Current.account.captain_custom_tools : Captain::CustomTool.none
    records = scope.order(updated_at: :desc).limit(5)
    {
      count: scope.count,
      enabled_count: scope.enabled.count,
      built_in_count: Captain::Assistant.built_in_agent_tools.count,
      records: records.map { |tool| { id: tool.id, title: tool.title, status: tool.enabled ? 'enabled' : 'disabled', updated_at: tool.updated_at } }
    }
  end

  def campaign_inventory
    scope = Current.account.campaigns.where(captain_assistant_id: @assistant.id)
    records = scope.order(updated_at: :desc).limit(5)
    {
      count: scope.count,
      active_count: scope.active.count,
      records: records.map { |campaign| { id: campaign.display_id, title: campaign.title, status: campaign.campaign_status, updated_at: campaign.updated_at } }
    }
  end

  def memory_inventory
    scope = Current.account.captain_conversation_states.where(captain_assistant_id: @assistant.id)
    {
      count: scope.count,
      auto_count: scope.where(ai_mode: 'auto').count,
      human_count: scope.where(ai_mode: CaptainConversationState::HUMAN_MODES).count,
      high_score_count: scope.where('score_total >= ?', CaptainConversationState::HIGH_PRIORITY_SCORE_THRESHOLD).count
    }
  end

  def flow_inventory
    scope = Captain::Flow.where(account_id: Current.account.id, captain_assistant_id: [@assistant.id, nil])
    records = scope.active.ordered.limit(5)
    {
      count: scope.count,
      published_count: scope.published.count,
      records: records.map { |flow| { id: flow.id, title: flow.name, status: flow.status, updated_at: flow.updated_at } }
    }
  end

  def model_catalog
    {
      providers: Llm::Models.providers,
      models: Llm::Models.models,
      features: Llm::Models.feature_keys.index_with { |feature_key| Llm::Models.feature_config(feature_key) }
    }
  end

  def optional_integer(value)
    value.to_s.blank? ? nil : value.to_i
  end

  def bounded_float(value, min, max)
    return nil if value.to_s.blank?

    value.to_f.clamp(min, max)
  end

  def boolean_value(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
