class Captain::Llm::AssistantChatService < Llm::BaseAiService
  include Captain::ChatHelper

  def initialize(assistant: nil, conversation: nil, source: nil)
    @assistant = assistant
    super()
    apply_assistant_llm_config

    @conversation = conversation
    @conversation_id = conversation&.display_id
    @source = source

    @deal_context = build_deal_context
    @messages = [system_message]
    @response = ''
    @tools = build_tools
  end

  # additional_message: A single message (String) from the user that should be appended to the chat.
  #                    It can be an empty String or nil when you only want to supply historical messages.
  # message_history:   An Array of already formatted messages that provide the previous context.
  # role:              The role for the additional_message (defaults to `user`).
  #
  # NOTE: Parameters are provided as keyword arguments to improve clarity and avoid relying on
  # positional ordering.
  def generate_response(additional_message: nil, message_history: [], role: 'user')
    @messages += message_history
    @messages << { role: role, content: additional_message } if additional_message.present?
    request_chat_completion
  end

  private

  def build_tools
    [Captain::Tools::SearchDocumentationService.new(@assistant, user: nil)]
  end

  def system_message
    {
      role: 'system',
      content: Captain::Llm::SystemPromptsService.assistant_response_generator(
        @assistant.name, @assistant.config['product_name'], @assistant.config,
        contact: contact_attributes,
        deal_context: @deal_context
      )
    }
  end

  def contact_attributes
    return nil unless @conversation&.contact
    return nil unless @assistant&.feature_contact_attributes

    @conversation.contact.attributes.symbolize_keys.slice(
      :id, :name, :email, :phone_number, :identifier, :custom_attributes,
      :relationship_status, :lifecycle_stage, :crm_owner_id
    ).merge(crm_owner_name: @conversation.contact.try(:crm_owner)&.name)
  end

  def build_deal_context
    return nil unless @conversation

    captain_state = @conversation.captain_conversation_state
    deal = captain_state&.crm_deal || @conversation.account.crm_deals.open_deals.find_by(conversation: @conversation)
    return nil unless deal

    stage = deal.crm_pipeline_stage
    {
      title: deal.title,
      stage_name: stage&.name,
      score: deal.score_total,
      legal_area: deal.legal_area,
      case_type: deal.case_type,
      urgency_level: deal.urgency_level,
      summary: deal.summary,
      next_best_action: deal.next_best_action,
      documents_status: deal.documents_status,
      conflict_check_status: deal.conflict_check_status
    }.compact
  end

  def persist_message(message, message_type = 'assistant')
    # No need to implement
  end

  def feature_name
    'assistant'
  end

  def apply_assistant_llm_config
    return unless @assistant

    @model = Llm::Config.resolve_model(@assistant.llm_config_with_defaults[:main_model])
  end
end
