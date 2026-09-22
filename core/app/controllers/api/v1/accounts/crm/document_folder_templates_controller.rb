# Modelos de pasta da conta (gaveta do cliente e subpastas de negócio por
# área). Editar só afeta gavetas criadas depois; as existentes não mudam.
class Api::V1::Accounts::Crm::DocumentFolderTemplatesController < Api::V1::Accounts::Crm::DocumentsBaseController
  def index
    authorize CrmDocument, :index?
    Crm::Documents::Defaults.ensure!(Current.account)
    templates = Current.account.crm_document_folder_templates.order(:scope, :legal_area)
    render json: templates.map { |template| serialize(template) }
  end

  def update
    authorize CrmDocument, :manage?
    template = Current.account.crm_document_folder_templates.find(params[:id])
    template.update!(name: params[:name].presence || template.name, tree: tree_param)
    audit('document_folder_template_updated', template)
    render json: serialize(template)
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  private

  def tree_param
    Array(params[:tree]).map do |node|
      node = node.respond_to?(:permit) ? node.permit(:slot, :name).to_h : node.to_h
      name = node['name'].to_s.strip
      # Pasta nova ganha um slot estável a partir do nome.
      { 'slot' => node['slot'].to_s.strip.presence || "pasta_#{name.parameterize(separator: '_')}", 'name' => name }
    end
  end

  def serialize(template)
    { id: template.id, scope: template.scope, legal_area: template.legal_area, name: template.name,
      tree: template.nodes }
  end
end
