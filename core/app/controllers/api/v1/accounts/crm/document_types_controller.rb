# Catálogo de tipos de documento da conta (chips de classificação na tela).
class Api::V1::Accounts::Crm::DocumentTypesController < Api::V1::Accounts::Crm::DocumentsBaseController
  def index
    authorize CrmDocument, :index?
    Crm::Documents::Defaults.ensure!(Current.account)
    types = Current.account.crm_document_types.active.ordered
    render json: types.map { |type| serializer.document_type(type) }
  end
end
