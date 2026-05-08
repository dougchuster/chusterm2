class Captain::Tools::Copilot::GetCrmContextService < Captain::Tools::BaseTool
  def self.name
    'get_crm_context'
  end

  description 'Get CRM context for a conversation, including lead/customer status, lifecycle, owner, labels, notes, documents and media understanding.'
  param :conversation_id, type: :number, desc: 'The display ID of the conversation to inspect', required: true

  def execute(conversation_id:)
    conversation = Conversation.find_by(display_id: conversation_id, account_id: @assistant.account_id)
    return 'Conversation not found' if conversation.blank?

    Captain::CrmContextBuilder.new(conversation).perform.to_json
  end

  def active?
    user_has_permission('conversation_manage')
  end
end
