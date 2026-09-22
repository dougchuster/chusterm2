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
  FOLDER_NAME_MAX = 120

  def self.client_folder_name(contact)
    values = { 'nome' => Crm::Documents::Naming::Sanitizer.call(contact.name, max: CLIENT_NAME_MAX),
               'codigo' => contact.id.to_s.rjust(CLIENT_CODE_DIGITS, '0') }
    render(contact.account, 'client_folder', values)
  end

  # Número interno do CRM (ano de criação + id), nunca um número externo.
  def self.deal_folder_name(deal)
    values = { 'ano' => deal.created_at.year.to_s, 'numero' => deal.id.to_s.rjust(DEAL_NUMBER_DIGITS, '0'),
               'titulo' => Crm::Documents::Naming::Sanitizer.call(deal.title, max: DEAL_TITLE_MAX, fallback: 'Negócio'),
               'cliente' => deal.contact&.name.to_s, 'codigo' => deal.contact_id.to_s.rjust(CLIENT_CODE_DIGITS, '0') }
    render(deal.account, 'case_folder', values)
  end

  def self.render(account, kind, values)
    template = Crm::Documents::Defaults.settings_for(account).naming_template(kind)
    Crm::Documents::Naming::Template.render(template, values, max: FOLDER_NAME_MAX, shrink: %w[titulo nome cliente])
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
