module ConversationAccountScoped
  extend ActiveSupport::Concern

  included do
    validate :conversation_belongs_to_account
  end

  private

  def conversation_belongs_to_account
    return if conversation_id.blank? || account_id.blank?
    return if conversation.present? && conversation.account_id == account_id

    errors.add(:conversation, 'must belong to the same account')
  end
end
