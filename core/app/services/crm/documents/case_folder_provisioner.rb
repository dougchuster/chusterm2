# Garante a pasta de um processo dentro de "04 Processos", com as subpastas do
# modelo da área (PROJETO-COFRE-DOCUMENTOS.md §5.2). A pasta do processo é
# achada pelo crm_deal_id, então renomear o negócio não cria pasta nova.
class Crm::Documents::CaseFolderProvisioner
  CASE_SLOT = 'processo'.freeze
  PROCESSES_SLOT = 'processos'.freeze

  def initialize(deal)
    @deal = deal
    @account = deal.account
    @contact = deal.contact
  end

  def ensure!
    raise ArgumentError, 'o negócio precisa ter um contato' if @contact.nil?

    parent = Crm::Documents::DrawerProvisioner.new(@contact).folder_for_slot(PROCESSES_SLOT)
    case_folder = existing_case_folder || create_case_folder(parent)
    ensure_children(case_folder)
    case_folder
  end

  private

  def existing_case_folder
    CrmDocumentFolder.active.find_by(account_id: @account.id, contact_id: @contact.id, crm_deal_id: @deal.id,
                                     slot: CASE_SLOT)
  end

  def create_case_folder(parent)
    CrmDocumentFolder.transaction(requires_new: true) do
      CrmDocumentFolder.create!(
        account: @account, contact: @contact, parent: parent, crm_deal: @deal, slot: CASE_SLOT, kind: 'system',
        name: Crm::Documents::Naming::PathBuilder.deal_folder_name(@deal)
      )
    end
  rescue ActiveRecord::RecordNotUnique
    existing_case_folder || raise
  end

  def ensure_children(case_folder)
    existing = case_folder.children.active.pluck(:slot)
    template.nodes.each_with_index do |node, index|
      next if existing.include?(node['slot'])

      CrmDocumentFolder.transaction(requires_new: true) do
        CrmDocumentFolder.create!(
          account: @account, contact: @contact, parent: case_folder, crm_deal: @deal,
          name: node['name'], slot: node['slot'], kind: 'system', position: index
        )
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      next
    end
  end

  def template
    area = Crm::Documents::Defaults.case_area_for(@deal.category.presence || @deal.legal_area, @account)
    templates = @account.crm_document_folder_templates.case_scope
    templates.find_by(legal_area: area) || templates.find_by!(legal_area: Crm::Documents::Defaults::GENERIC_AREA)
  end
end
