# Catálogo de tipos de documento da conta (chips de classificação na tela).
class Api::V1::Accounts::Crm::DocumentTypesController < Api::V1::Accounts::Crm::DocumentsBaseController
  def index
    authorize CrmDocument, :index?
    Crm::Documents::Defaults.ensure!(Current.account)
    types = Current.account.crm_document_types.active.ordered
    labels = folder_labels
    render json: types.map { |type| serializer.document_type(type).merge(target_folder_label: labels[type.target_slot]) }
  end

  private

  # Nome da pasta de destino de cada slot, pelos modelos da conta — a tela
  # mostra "Vai para: 01 Documentos Pessoais" antes de confirmar.
  def folder_labels
    templates = Current.account.crm_document_folder_templates
    client = templates.client_scope.first&.nodes || []
    generic_case = templates.case_scope.find_by(legal_area: Crm::Documents::Defaults::GENERIC_AREA)&.nodes || []
    (client + generic_case).to_h { |node| [node['slot'], node['name']] }
  end
end
