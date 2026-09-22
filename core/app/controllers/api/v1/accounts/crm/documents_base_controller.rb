# Base dos endpoints do cofre de documentos. Garante o módulo ligado na conta
# e resolve contato/negócio sempre dentro do que o usuário pode ver — o que
# está fora responde 404, sem revelar que existe.
class Api::V1::Accounts::Crm::DocumentsBaseController < Api::V1::Accounts::Crm::BaseController
  before_action :ensure_documents_enabled

  private

  def ensure_documents_enabled
    render json: { error: 'not_found' }, status: :not_found unless Crm::Documents::Feature.enabled?(Current.account)
  end

  def documents_access
    @documents_access ||= Crm::Documents::Access.new(Current.user, Current.account)
  end

  def find_visible_contact!(contact_id)
    contact = Current.account.contacts.find(contact_id)
    raise ActiveRecord::RecordNotFound unless documents_access.contact_visible?(contact)

    contact
  end

  def find_contact_deal!(contact, deal_id)
    return if deal_id.blank?

    CrmDeal.visible_to(Current.user, Current.account).where(account_id: Current.account.id, contact_id: contact.id)
           .find(deal_id)
  end

  def find_contact_folder!(contact, folder_id)
    return if folder_id.blank?

    CrmDocumentFolder.active.where(account_id: Current.account.id, contact_id: contact.id).find(folder_id)
  end

  def serializer
    @serializer ||= Crm::Documents::Serializer.new(account: Current.account)
  end

  def audit(action, target, payload = {})
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: action, target: target,
                         payload: payload, ip: request.remote_ip, user_agent: request.user_agent)
  end

  def render_unprocessable(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
