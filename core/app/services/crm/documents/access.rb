# Quem vê os documentos de quem (PROJETO-COFRE-DOCUMENTOS.md §10).
# Administrador vê tudo. Agente vê os contatos que atende: conversa numa inbox
# dele, ou negócio do qual é dono, responsável ou do time dele.
#
# Deliberadamente NÃO reusa CrmDeal.visible_to: no funil, negócio sem inbox é
# visível para todo agente, o que aqui abriria RG/CPF/laudos de clientes que o
# agente nunca atendeu (achado CRÍTICO da revisão de segurança de 22/09/2026).
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

  # Negócios em que o agente pode arquivar documentos: os dele (dono,
  # responsável, time) e os da inbox dele. Negócio sem inbox de outro agente
  # fica de fora — é outro caso do mesmo cliente (sigilo entre casos).
  def deals
    scope = CrmDeal.where(account_id: @account.id)
    return scope if administrator?

    own_deals(scope).or(scope.where(inbox_id: @user.inboxes.where(account_id: @account.id).select(:id)))
  end

  private

  def served_contact_ids
    inbox_ids = @user.inboxes.where(account_id: @account.id).select(:id)
    Conversation.where(account_id: @account.id, inbox_id: inbox_ids).select(:contact_id)
  end

  def deal_contact_ids
    own_deals(CrmDeal.where(account_id: @account.id).where.not(contact_id: nil)).select(:contact_id)
  end

  def own_deals(scope)
    team_ids = @user.teams.where(account_id: @account.id).select(:id)
    scope.where(owner_id: @user.id).or(scope.where(assignee_id: @user.id)).or(scope.where(team_id: team_ids))
  end
end
