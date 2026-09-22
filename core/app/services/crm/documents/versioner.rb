# Versões (PROJETO-COFRE-DOCUMENTOS.md §4.3 e §5.3): quando chega outro
# arquivo do mesmo tipo, na mesma pasta do mesmo cliente, ele vira a versão
# atual. A anterior NUNCA é apagada: vai para 99 Arquivo, obsoleta, com o
# sufixo "(v1)" no nome. O tipo "outro" não versiona (cada um é um documento).
class Crm::Documents::Versioner
  ARCHIVE_SLOT = 'arquivo'.freeze
  UNVERSIONED_TYPE = 'outro'.freeze

  def self.call(document, actor: nil)
    new(document, actor: actor).call
  end

  def initialize(document, actor: nil)
    @document = document
    @actor = actor
  end

  def call
    previous = predecessor
    return if previous.nil?

    supersede!(previous)
    @document.update!(versions_count: previous.versions_count + 1,
                      meta: (@document.meta || {}).merge('previous_version_id' => previous.id))
    previous
  end

  private

  def predecessor
    return if @document.doc_type.blank? || @document.doc_type == UNVERSIONED_TYPE || @document.archived?

    CrmDocument.active.where(account_id: @document.account_id, contact_id: @document.contact_id,
                             doc_type: @document.doc_type, crm_document_folder_id: @document.crm_document_folder_id)
               .where.not(id: @document.id).where.not(status: 'obsolete').where.not(checksum: @document.checksum)
               .order(:created_at, :id).last
  end

  def supersede!(previous)
    previous.update!(status: 'obsolete', name_locked: true, file_name: versioned_name(previous),
                     crm_document_folder: archive_folder || previous.crm_document_folder,
                     meta: (previous.meta || {}).merge('superseded_by_id' => @document.id))
    Crm::AuditLogger.log(account: previous.account, actor: @actor, action: 'document_superseded', target: previous,
                         payload: { superseded_by_id: @document.id, version: previous.versions_count })
  end

  def versioned_name(previous)
    extension = File.extname(previous.file_name)
    "#{File.basename(previous.file_name, extension)} (v#{previous.versions_count})#{extension}"
  end

  def archive_folder
    Crm::Documents::DrawerProvisioner.new(@document.contact).folder_for_slot(ARCHIVE_SLOT)
  end
end
