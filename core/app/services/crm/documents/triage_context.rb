# O que a Caixa de Triagem precisa além do documento: nome do contato, processos
# abertos (para escolher onde vai um CNIS ou laudo) e a pasta de descarte
# (99 Arquivo). Uma consulta por lista, não por documento.
class Crm::Documents::TriageContext
  DISCARD_SLOT = 'arquivo'.freeze

  def initialize(account:, user:, documents:)
    @account = account
    @user = user
    @contact_ids = documents.map(&:contact_id).uniq
  end

  def for(document)
    {
      contact_name: document.contact&.name,
      contact_deals: deals_by_contact.fetch(document.contact_id, []),
      discard_folder_id: discard_folders[document.contact_id]
    }
  end

  private

  def deals_by_contact
    @deals_by_contact ||= CrmDeal.visible_to(@user, @account)
                                 .where(account_id: @account.id, contact_id: @contact_ids, status: 'open')
                                 .order(:created_at).pluck(:contact_id, :id, :title)
                                 .group_by(&:first)
                                 .transform_values { |rows| rows.map { |_contact, id, title| { id: id, title: title } } }
  end

  def discard_folders
    @discard_folders ||= CrmDocumentFolder.active.roots
                                          .where(account_id: @account.id, contact_id: @contact_ids, slot: DISCARD_SLOT)
                                          .pluck(:contact_id, :id).to_h
  end
end
