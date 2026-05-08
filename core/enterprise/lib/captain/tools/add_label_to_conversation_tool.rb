class Captain::Tools::AddLabelToConversationTool < Captain::Tools::BasePublicTool
  description 'Add a label to a conversation'
  param :label_name, type: 'string', desc: 'The name of the label to add'

  def perform(tool_context, label_name:)
    conversation = find_conversation(tool_context.state)
    return 'Conversation not found' unless conversation

    label_name = label_name&.strip&.downcase
    return 'Label name is required' if label_name.blank?

    label = find_label(label_name)
    return 'Label not found' unless label

    add_label_to_conversation(conversation, label)
    add_label_to_contact(conversation.contact, label) if sync_to_contact?(label)

    log_tool_usage('added_label', conversation_id: conversation.id, label: label.title, slug: label.slug)

    "Label '#{label.title}' added to conversation ##{conversation.display_id}"
  end

  private

  def find_label(label_name)
    account_scoped(Label).find_by(slug: label_name) ||
      account_scoped(Label).find_by(title: label_name.tr('.', '_')) ||
      account_scoped(Label).find_by(title: label_name)
  end

  def add_label_to_conversation(conversation, label)
    apply_label(conversation, label)
  rescue StandardError => e
    Rails.logger.error "Failed to add label to conversation: #{e.message}"
    raise
  end

  def add_label_to_contact(contact, label)
    return unless contact

    apply_label(contact, label)
  rescue StandardError => e
    Rails.logger.error "Failed to sync label to contact: #{e.message}"
    raise
  end

  def apply_label(record, label)
    current_labels = record.label_list.to_a
    conflict_labels = conflict_labels_for(label)
    next_labels = (current_labels - conflict_labels + [label.title]).uniq
    record.update!(label_list: next_labels)
  end

  def conflict_labels_for(label)
    return [] unless label.category.in?(%w[area temperature relationship])

    account_scoped(Label).where(category: label.category).pluck(:title)
  end

  def sync_to_contact?(label)
    label.scope.in?(%w[contact both]) && label.category.in?(%w[area temperature relationship status])
  end
end
