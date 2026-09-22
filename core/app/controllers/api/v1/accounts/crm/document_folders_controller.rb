# Pastas da gaveta do cliente. A primeira visita cria a gaveta pelo modelo; com
# `deal_id`, também a pasta do processo. Pastas do modelo podem ser renomeadas
# (o slot preserva o papel), mas não arquivadas.
class Api::V1::Accounts::Crm::DocumentFoldersController < Api::V1::Accounts::Crm::DocumentsBaseController
  before_action :load_folder, only: [:update, :destroy]

  def index
    authorize CrmDocument, :index?
    contact = find_visible_contact!(params.require(:contact_id))
    deal = find_contact_deal!(contact, params[:deal_id])
    Crm::Documents::DrawerProvisioner.new(contact).ensure!
    case_folder = deal && Crm::Documents::CaseFolderProvisioner.new(deal).ensure!
    render json: {
      client_folder_name: Crm::Documents::Naming::PathBuilder.client_folder_name(contact),
      case_folder_id: case_folder&.id,
      folders: folders_payload(contact)
    }
  end

  def create
    authorize CrmDocument, :create?
    contact = find_visible_contact!(params.require(:contact_id))
    folder = CrmDocumentFolder.create!(
      account: Current.account, contact: contact, parent: find_contact_folder!(contact, params[:parent_id]),
      name: params.require(:name), kind: 'custom'
    )
    audit('document_folder_created', folder, parent_id: folder.parent_id)
    render json: serializer.folder(folder), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  def update
    authorize CrmDocument, :update?
    attributes = params.require(:folder).permit(:name, :parent_id, :position).to_h.symbolize_keys
    attributes[:parent] = find_contact_folder!(@folder.contact, attributes.delete(:parent_id)) if attributes.key?(:parent_id)
    @folder.update!(attributes)
    audit('document_folder_updated', @folder, changes: @folder.saved_changes.except('updated_at'))
    render json: serializer.folder(@folder)
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  def destroy
    authorize CrmDocument, :destroy?
    return render_unprocessable('Pastas do modelo não podem ser arquivadas.') if @folder.system?
    return render_unprocessable('A pasta ainda tem documentos ou subpastas. Mova-os antes.') unless empty?(@folder)

    @folder.update!(archived_at: Time.current)
    audit('document_folder_archived', @folder)
    head :no_content
  end

  private

  def load_folder
    @folder = documents_access.folders.active.find(params[:id])
  end

  def folders_payload(contact)
    folders = CrmDocumentFolder.active.where(account_id: Current.account.id, contact_id: contact.id).ordered
    counts = CrmDocument.active.where(account_id: Current.account.id, contact_id: contact.id)
                        .group(:crm_document_folder_id).count
    folders.map { |folder| serializer.folder(folder, documents_count: counts.fetch(folder.id, 0)) }
  end

  def empty?(folder)
    !folder.crm_documents.active.exists? && !folder.children.active.exists?
  end
end
