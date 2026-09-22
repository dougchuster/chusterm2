# Caminho completo de um documento na árvore única do cofre
# (PROJETO-COFRE-DOCUMENTOS.md §5.6):
#
#   Clientes / Maria da Silva Souza · C000123 / 01 Documentos Pessoais / 2026-09-22 — RG.pdf
#
# Usado pela tela (breadcrumb), pelo .zip, pelo espelho em disco e pelo Drive.
# Determinístico: mesmo estado do banco, mesmo caminho — por isso o desempate
# de nomes iguais segue a ordem de criação (id).
class Crm::Documents::Naming::PathBuilder
  ROOT = 'Clientes'.freeze
  CLIENT_CODE_DIGITS = 6
  DEAL_NUMBER_DIGITS = 4
  CLIENT_NAME_MAX = 80
  DEAL_TITLE_MAX = 80

  def self.client_folder_name(contact)
    name = Crm::Documents::Naming::Sanitizer.call(contact.name, max: CLIENT_NAME_MAX)
    "#{name} · C#{contact.id.to_s.rjust(CLIENT_CODE_DIGITS, '0')}"
  end

  # Número interno do CRM (ano de criação + id), nunca o número CNJ.
  def self.deal_folder_name(deal)
    number = "#{deal.created_at.year}-#{deal.id.to_s.rjust(DEAL_NUMBER_DIGITS, '0')}"
    "#{number} · #{Crm::Documents::Naming::Sanitizer.call(deal.title, max: DEAL_TITLE_MAX, fallback: 'Processo')}"
  end

  # `file_name` evita recalcular o desempate quando quem chama já o tem.
  def path_for(document, file_name: nil)
    [ROOT, self.class.client_folder_name(document.contact), *folder_segments(document.crm_document_folder),
     file_name || unique_file_name(document)]
  end

  def folder_segments(folder)
    return [] if folder.nil?

    folder.lineage.map(&:name)
  end

  def unique_file_name(document)
    ids = CrmDocument.active
                     .where(account_id: document.account_id, contact_id: document.contact_id,
                            crm_document_folder_id: document.crm_document_folder_id)
                     .where('lower(file_name) = ?', document.file_name.to_s.downcase)
                     .order(:id).pluck(:id)
    position = document.persisted? ? ids.index(document.id).to_i : ids.size
    return document.file_name if position.zero?

    ext = File.extname(document.file_name)
    "#{File.basename(document.file_name, ext)} (#{position + 1})#{ext}"
  end
end
