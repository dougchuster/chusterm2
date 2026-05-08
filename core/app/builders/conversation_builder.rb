class ConversationBuilder
  pattr_initialize [:params!, :contact_inbox!]

  JSON_ATTRIBUTE_SCALAR_CLASSES = [String, Numeric, TrueClass, FalseClass, NilClass].freeze

  def perform
    look_up_exising_conversation || create_new_conversation
  end

  private

  def look_up_exising_conversation
    return unless @contact_inbox.inbox.lock_to_single_conversation?

    @contact_inbox.conversations.last
  end

  def create_new_conversation
    ::Conversation.create!(conversation_params)
  end

  def conversation_params
    additional_attributes = sanitized_attribute_hash(:additional_attributes)
    custom_attributes = sanitized_attribute_hash(:custom_attributes)
    status = params[:status].present? ? { status: params[:status] } : {}

    # TODO: temporary fallback for the old bot status in conversation, we will remove after couple of releases
    # commenting this out to see if there are any errors, if not we can remove this in subsequent releases
    # status = { status: 'pending' } if status[:status] == 'bot'
    {
      account_id: @contact_inbox.inbox.account_id,
      inbox_id: @contact_inbox.inbox_id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: additional_attributes,
      custom_attributes: custom_attributes,
      snoozed_until: params[:snoozed_until],
      assignee_id: params[:assignee_id],
      team_id: params[:team_id]
    }.merge(status)
  end

  def sanitized_attribute_hash(attribute_name)
    raw_attributes = params[attribute_name]
    return {} if raw_attributes.blank?

    raw_attributes = raw_attributes.to_unsafe_h if raw_attributes.respond_to?(:to_unsafe_h)
    return {} unless raw_attributes.respond_to?(:to_h)

    sanitize_json_attribute(raw_attributes.to_h)
  end

  def sanitize_json_attribute(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested_value), sanitized|
        sanitized[key.to_s] = sanitize_json_attribute(nested_value)
      end
    when Array
      value.map { |nested_value| sanitize_json_attribute(nested_value) }
    when *JSON_ATTRIBUTE_SCALAR_CLASSES
      value
    else
      value.to_s
    end
  end
end
