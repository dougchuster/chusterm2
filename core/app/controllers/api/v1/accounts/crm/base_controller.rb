class Api::V1::Accounts::Crm::BaseController < Api::V1::Accounts::BaseController
  before_action :check_crm_authorization

  private

  def check_crm_authorization
    access_denied unless current_account_user
  end

  def current_account_user
    @current_account_user ||= Current.account_user
  end

  def administrator?
    current_account_user&.administrator?
  end

  # CRM relations persist the global Conversation primary key. Resolve it only
  # inside the current account and never fall back to the account-scoped
  # display_id used by Chatwoot routes.
  def resolve_conversation_id!(attributes)
    return attributes unless attributes.key?(:conversation_id)

    conversation_id = attributes[:conversation_id]
    attributes[:conversation_id] = if conversation_id.present?
                                     Current.account.conversations.find(conversation_id).id
                                   end
    attributes
  end

  def resolve_account_scoped_ids!(attributes, mapping)
    mapping.each do |attribute, association|
      next unless attributes.key?(attribute)

      value = attributes[attribute]
      attributes[attribute] = value.present? ? Current.account.public_send(association).find(value).id : nil
    end
    attributes
  end

  def render_conversation_not_found
    render json: { error: 'Conversation not found' }, status: :not_found
  end
end
