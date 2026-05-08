module Concerns::Agentable
  extend ActiveSupport::Concern

  def agent
    Agents::Agent.new(
      name: agent_name,
      instructions: ->(context) { agent_instructions(context) },
      tools: agent_tools,
      model: agent_model,
      temperature: temperature.to_f || 0.7,
      response_schema: agent_response_schema
    )
  end

  def agent_instructions(context = nil)
    enhanced_context = prompt_context

    if context
      state = context.context[:state] || {}
      config = state[:assistant_config] || {}
      enhanced_context = enhanced_context.merge(
        conversation: state[:conversation] || {},
        contact: config['feature_contact_attributes'].present? ? state[:contact] : nil,
        campaign: state[:campaign] || {},
        crm_context: state[:crm_context] || {},
        crm_context_json: formatted_crm_context(state[:crm_context])
      )
    end

    prompt = Captain::PromptRenderer.render(template_name, enhanced_context.with_indifferent_access)
    openrouter_model? ? "#{prompt}#{json_response_format_instruction}" : prompt
  end

  private

  def agent_name
    raise NotImplementedError, "#{self.class} must implement agent_name"
  end

  def template_name
    self.class.name.demodulize.underscore
  end

  def agent_tools
    []  # Default implementation, override if needed
  end

  def agent_model
    configured = if respond_to?(:llm_config_with_defaults)
                   llm_config_with_defaults[:main_model]
                 elsif respond_to?(:assistant) && assistant.respond_to?(:llm_config_with_defaults)
                   assistant.llm_config_with_defaults[:main_model]
                 else
                   InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value
                 end
    Llm::Config.resolve_model(configured.presence || LlmConstants::DEFAULT_MODEL)
  end

  def agent_response_schema
    Captain::ResponseSchema
  end

  def openrouter_model?
    agent_model.to_s.include?('/')
  end

  def json_response_format_instruction
    <<~INSTRUCTION

      # Response Format
      You MUST respond with a valid JSON object only — no text outside the JSON.
      Use exactly this structure:
      {"response": "<your reply to the user>", "reasoning": "<brief internal thinking>"}
    INSTRUCTION
  end

  def formatted_crm_context(crm_context)
    return if crm_context.blank?

    JSON.pretty_generate(crm_context)
  rescue StandardError
    crm_context.to_json
  end

  def prompt_context
    raise NotImplementedError, "#{self.class} must implement prompt_context"
  end
end
