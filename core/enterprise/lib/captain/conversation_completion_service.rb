# Evaluates whether a conversation is complete and can be auto-resolved.
# Used by InboxPendingConversationsResolutionJob to determine if inactive
# conversations should be resolved or handed off to human agents.
#
# NOTE: This service intentionally does NOT count toward Captain usage limits.
# The response excludes the :message key that Enterprise::Captain::BaseTaskService
# checks for usage tracking. This is an internal operational evaluation,
# not a customer-facing value-add, so we don't charge for it.
class Captain::ConversationCompletionService < Captain::BaseTaskService
  RESPONSE_SCHEMA = Captain::ConversationCompletionSchema
  # A binary complete/incomplete verdict never needs the model's full output
  # budget. Capping max_tokens keeps OpenRouter credit-limit checks cheap and
  # stops every sweep call from reserving 65k tokens.
  EVALUATION_MAX_TOKENS = 512

  pattr_initialize [:account!, :conversation_display_id!]

  def perform
    content = format_messages_as_string
    return default_incomplete_response('No messages found') if content.blank?

    response = make_api_call(
      model: InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_MODEL')&.value.presence || GPT_MODEL,
      messages: [
        { role: 'system', content: prompt_from_file('conversation_completion') },
        { role: 'user', content: content }
      ],
      schema: RESPONSE_SCHEMA
    )

    return provider_error_response(response[:error]) if response[:error].present?

    parse_response(response[:message])
  end

  private

  def prompt_from_file(file_name)
    Rails.root.join('enterprise/lib/captain/prompts', "#{file_name}.liquid").read
  end

  def format_messages_as_string
    messages = conversation_messages(start_from: 0)
    messages.map do |msg|
      sender_type = msg[:role] == 'user' ? 'Customer' : 'Assistant'
      "#{sender_type}: #{msg[:content]}"
    end.join("\n")
  end

  def parse_response(message)
    return default_incomplete_response('Invalid response format') unless message.is_a?(Hash)

    {
      complete: message['complete'] == true,
      reason: message['reason'] || 'No reason provided'
    }
  end

  def default_incomplete_response(reason)
    { complete: false, reason: reason }
  end

  # Provider/API failures are flagged explicitly so the caller can route them to
  # handoff without regexing free-form reason text (LLM reasons can contain words
  # like "credit" or "timeout" without being provider failures).
  def provider_error_response(error)
    { complete: false, reason: error, provider_error: true }
  end

  def build_chat(context, model:, messages:, schema: nil, tools: [])
    chat = super
    chat.with_params(max_tokens: EVALUATION_MAX_TOKENS)
    chat
  end

  # All AI traffic uses the installation-wide OpenRouter gateway.
  def api_key
    @api_key ||= system_api_key
  end

  def event_name
    'captain.conversation_completion'
  end

  def build_follow_up_context?
    false
  end
end

Captain::ConversationCompletionService.prepend_mod_with('Captain::ConversationCompletionService')
