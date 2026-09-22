# Decide a pasta de destino de um tipo de documento (PROJETO-COFRE-DOCUMENTOS.md
# §5.4). Tipos de processo (`processo_*`) só vão para a pasta do processo quando
# ele é conhecido; sem processo, ficam na Triagem para a equipe escolher.
class Crm::Documents::Router
  TRIAGE_SLOT = 'triagem'.freeze

  def initialize(contact, deal: nil)
    @contact = contact
    @deal = deal
    @drawer = Crm::Documents::DrawerProvisioner.new(contact)
    Crm::Documents::Defaults.ensure!(contact.account)
  end

  def triage_folder
    @drawer.folder_for_slot(TRIAGE_SLOT)
  end

  # `current_folder` é devolvida para o tipo "outro" (fica onde está).
  def folder_for(doc_type, current_folder: nil)
    type = find_type(doc_type)
    return current_folder || triage_folder if keeps_current_folder?(type)
    return case_folder_for(type.target_slot) if type.case_folder_target?

    @drawer.folder_for_slot(type.target_slot) || triage_folder
  end

  private

  def find_type(doc_type)
    return if doc_type.blank?

    @contact.account.crm_document_types.find_by(slug: doc_type)
  end

  def keeps_current_folder?(type)
    type.nil? || type.target_slot == CrmDocumentType::CURRENT_FOLDER_SLOT
  end

  def case_folder_for(slot)
    return triage_folder if @deal.nil?

    case_folder = Crm::Documents::CaseFolderProvisioner.new(@deal).ensure!
    case_folder.children.active.find_by(slot: slot) || case_folder
  end
end
