# Formulários de envio montados pela conta (PROJETO-COFRE-DOCUMENTOS.md §8.7).
# Ler e gerar link personalizado: quem usa o cofre. Criar/editar/arquivar:
# administrador. Novo formulário parte do modelo da área (FormTemplates).
class Api::V1::Accounts::Crm::DocumentFormsController < Api::V1::Accounts::Crm::DocumentsBaseController
  LINK_TTL_DAYS = (1..60)
  ALLOWED_ENTRY_KEYS = %w[key label type required help placeholder options maps_to show_if doc_type multiple].freeze

  before_action :load_form, except: [:index, :create]

  def index
    authorize CrmDocument, :index?
    forms = Current.account.crm_document_forms.kept.order(:name)
    render json: forms.map { |form| serialize(form) }
  end

  def show
    authorize CrmDocument, :index?
    render json: serialize(@form)
  end

  def create
    authorize CrmDocument, :manage?
    Crm::Documents::Defaults.ensure!(Current.account)
    attributes = Crm::Documents::FormTemplates.default_attributes(Current.account).merge(form_params.to_h.symbolize_keys)
    form = Current.account.crm_document_forms.create!(attributes.merge(created_by_user: Current.user))
    audit('document_form_created', form)
    render json: serialize(form), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  def update
    authorize CrmDocument, :manage?
    @form.update!(form_params)
    audit('document_form_updated', @form, changes: @form.saved_changes.keys - ['updated_at'])
    render json: serialize(@form)
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  def destroy
    authorize CrmDocument, :manage?
    @form.update!(archived_at: Time.current, active: false)
    audit('document_form_archived', @form)
    head :no_content
  end

  # Link personalizado para um cliente ("o que falta"). O token cru só sai
  # nesta resposta; o banco guarda o digest.
  def links
    authorize CrmDocument, :index?
    contact = find_visible_contact!(params.require(:contact_id))
    deal = find_contact_deal!(contact, params[:deal_id])
    days = params[:ttl_days].to_i.clamp(LINK_TTL_DAYS.min, LINK_TTL_DAYS.max)
    link, token = CrmDocumentFormLink.issue!(form: @form, contact: contact, deal: deal, user: Current.user,
                                             ttl: days.days)
    audit('document_form_link_issued', link, contact_id: contact.id, deal_id: deal&.id)
    render json: { url: "#{request.base_url}/l/#{token}", expires_at: link.expires_at }, status: :created
  end

  private

  def load_form
    @form = Current.account.crm_document_forms.kept.find(params[:id])
  end

  def form_params
    permitted = params.permit(:name, :active)
    permitted[:fields] = json_param(:fields) if params.key?(:fields)
    permitted[:document_items] = json_param(:document_items) if params.key?(:document_items)
    permitted[:settings] = params[:settings].permit(*Crm::Documents::FormSchema::TEXT_LIMITS.keys).to_h if params[:settings].respond_to?(:permit)
    permitted
  end

  # Estrutura livre (validada por FormSchema): lista de hashes simples, só com
  # as chaves conhecidas; a condição fica reduzida a { field, equals }.
  def json_param(key)
    Array(params[key]).map do |entry|
      entry = (entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h).stringify_keys.slice(*ALLOWED_ENTRY_KEYS)
      entry['show_if'] = entry['show_if'].to_h.stringify_keys.slice('field', 'equals').presence if entry.key?('show_if')
      entry.compact
    end
  end

  def serialize(form)
    {
      id: form.id, name: form.name, active: form.active, fields: form.fields, document_items: form.document_items,
      settings: form.settings, submissions_count: form.submissions_count, created_at: form.created_at,
      updated_at: form.updated_at, public_url: "#{request.base_url}/f/#{form.public_token}"
    }
  end
end
