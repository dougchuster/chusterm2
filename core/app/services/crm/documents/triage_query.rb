# Documentos esperando classificação: sem tipo, ativos e dentro da pasta de
# triagem, só dos contatos que o usuário pode ver. Mais recentes primeiro.
class Crm::Documents::TriageQuery
  def initialize(access)
    @access = access
  end

  def scope
    @access.documents.active.where(doc_type: nil)
           .joins(:crm_document_folder)
           .where(crm_document_folders: { slot: Crm::Documents::Router::TRIAGE_SLOT })
           .ordered
  end
end
