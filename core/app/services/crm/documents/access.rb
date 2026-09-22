# Quem vê os documentos de quem (PROJETO-COFRE-DOCUMENTOS.md §10).
# Administrador vê tudo. Agente vê os contatos que atende: conversa numa inbox
# dele ou negócio visível para ele pela mesma regra de CrmDeal.visible_to.
# Fora disso, o controller responde 404 — nem a existência do documento vaza.
class Crm::Documents::Access
  def initialize(user, account)
    @user = user
    @account = account
  end

  def administrator?
    return @administrator if defined?(@administrator)

    @administrator = @account.account_users.find_by(user_id: @user.id)&.administrator? || false
  end

  def contact_visible?(contact)
    return false if contact.nil? || contact.account_id != @account.id
    return true if administrator?

    visible_contacts.exists?(id: contact.id)
  end

  def visible_contacts
    return @account.contacts if administrator?

    @account.contacts.where(id: served_contact_ids).or(@account.contacts.where(id: deal_contact_ids))
  end

  def documents
    scope = CrmDocument.where(account_id: @account.id)
    administrator? ? scope : scope.where(contact_id: visible_contacts.select(:id))
  end

  def folders
    scope = CrmDocumentFolder.where(account_id: @account.id)
    administrator? ? scope : scope.where(contact_id: visible_contacts.select(:id))
  end

  private

  def served_contact_ids
    inbox_ids = @user.inboxes.where(account_id: @account.id).select(:id)
    Conversation.where(account_id: @account.id, inbox_id: inbox_ids).select(:contact_id)
  end

  def deal_contact_ids
    CrmDeal.visible_to(@user, @account).where.not(contact_id: nil).select(:contact_id)
  end
end
