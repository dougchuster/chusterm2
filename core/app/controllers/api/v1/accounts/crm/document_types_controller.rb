# Catálogo de tipos de documento da conta. Ler: quem usa o cofre (chips de
# classificação). Criar/editar/desativar: administrador. Desativar não apaga:
# documentos já classificados continuam com o tipo.
class Api::V1::Accounts::Crm::DocumentTypesController < Api::V1::Accounts::Crm::DocumentsBaseController
  PERMITTED = [:label, :target_slot, :validity_days, :position, :active, { patterns: [] }].freeze

  before_action :load_type, only: [:update, :destroy]

  def index
    authorize CrmDocument, :index?
    Crm::Documents::Defaults.ensure!(Current.account)
    types = Current.account.crm_document_types.ordered
    types = types.active unless ActiveModel::Type::Boolean.new.cast(params[:all])
    labels = folder_labels
    render json: types.map { |type| serialize(type, labels) }
  end

  def create
    authorize CrmDocument, :manage?
    type = Current.account.crm_document_types.create!(params.permit(:slug, *PERMITTED))
    audit('document_type_created', type)
    render json: serialize(type, folder_labels), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  def update
    authorize CrmDocument, :manage?
    @type.update!(params.permit(*PERMITTED))
    audit('document_type_updated', @type, changes: @type.saved_changes.except('updated_at'))
    render json: serialize(@type, folder_labels)
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  def destroy
    authorize CrmDocument, :manage?
    @type.update!(active: false)
    audit('document_type_deactivated', @type)
    head :no_content
  end

  private

  def load_type
    @type = Current.account.crm_document_types.find(params[:id])
  end

  def serialize(type, labels)
    serializer.document_type(type).merge(
      id: type.id, position: type.position, active: type.active, patterns: type.patterns,
      target_folder_label: labels[type.target_slot]
    )
  end

  # Nome da pasta de destino de cada slot, pelos modelos da conta — a tela
  # mostra "Vai para: 01 Documentos Pessoais" antes de confirmar.
  def folder_labels
    templates = Current.account.crm_document_folder_templates
    client = templates.client_scope.first&.nodes || []
    generic_case = templates.case_scope.find_by(legal_area: Crm::Documents::Defaults::GENERIC_AREA)&.nodes || []
    (client + generic_case).to_h { |node| [node['slot'], node['name']] }
  end
end
