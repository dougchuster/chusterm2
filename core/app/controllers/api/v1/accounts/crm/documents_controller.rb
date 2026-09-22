# Documentos do cofre: listar, enviar, classificar/mover, arquivar, restaurar,
# apagar (admin) e baixar com link temporário auditado.
class Api::V1::Accounts::Crm::DocumentsController < Api::V1::Accounts::Crm::DocumentsBaseController
  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100
  DOWNLOAD_TTL = 5.minutes
  UPDATABLE = %i[doc_type description document_date crm_document_folder_id crm_deal_id status review_note
                 file_name expires_on].freeze

  LIST_INCLUDES = [:contact, :uploaded_by_user, { source_message: :conversation },
                   { crm_document_folder: { parent: :parent } }].freeze

  before_action :load_document, except: [:index, :create, :triage, :queue]

  def index
    authorize CrmDocument, :index?
    contact = find_visible_contact!(params.require(:contact_id))
    scope = Crm::Documents::DocumentFilter.new(contact: contact, params: params).scope
    records = paginate(scope.includes(*LIST_INCLUDES))
    render json: { payload: records.map { |d| serializer.document(d) }, meta: { count: scope.count, page: page } }
  end

  # Caixa de Triagem (§8.3): o que chegou e ainda não foi classificado, de
  # todos os clientes que o usuário atende.
  def triage
    authorize CrmDocument, :index?
    scope = Crm::Documents::TriageQuery.new(documents_access).scope
    records = paginate(scope.includes(*LIST_INCLUDES)).to_a
    context = Crm::Documents::TriageContext.new(account: Current.account, user: Current.user, documents: records)
    render json: { payload: records.map { |d| serializer.document(d).merge(context.for(d)) },
                   meta: { count: scope.count, page: page } }
  end

  # Filas do escritório: ?name=review (para análise) ou expiring (vencendo).
  def queue
    authorize CrmDocument, :index?
    scope = Crm::Documents::QueueQuery.new(documents_access, params.require(:name)).scope
    records = paginate(scope.includes(*LIST_INCLUDES))
    render json: { payload: records.map { |d| serializer.document(d).merge(contact_name: d.contact&.name) },
                   meta: { count: scope.count, page: page } }
  rescue ArgumentError => e
    render_unprocessable(e.message)
  end

  def show
    authorize @document, :show?
    render json: serializer.document(@document)
  end

  def create
    authorize CrmDocument, :create?
    contact = find_visible_contact!(params.require(:contact_id))
    return render_unprocessable('Envie um arquivo.') if params[:file].blank?
    return render_too_large if request.content_length.to_i > Crm::Documents::Uploader::MAX_BYTES + 1.megabyte

    result = upload(contact)
    render json: { document: serializer.document(result.document), duplicate: result.duplicate? },
           status: result.duplicate? ? :ok : :created
  rescue Crm::Documents::Uploader::InvalidFile => e
    render_unprocessable(e.message)
  end

  def update
    authorize @document, :update?
    changes = Crm::Documents::DocumentUpdater.new(document: @document, attributes: update_params).call
    audit('document_updated', @document, changes: changes)
    render json: serializer.document(@document.reload)
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  def destroy
    authorize @document, :destroy?
    @document.update!(archived_at: Time.current)
    audit('document_archived', @document)
    head :no_content
  end

  def restore
    authorize @document, :restore?
    @document.update!(archived_at: nil)
    audit('document_restored', @document)
    render json: serializer.document(@document)
  end

  def purge
    authorize @document, :purge?
    audit('document_purged', @document, file_name: @document.file_name, contact_id: @document.contact_id)
    @document.destroy!
    head :no_content
  end

  def download
    authorize @document, :download?
    return render json: { error: 'not_found' }, status: :not_found unless @document.file.attached?

    # Registra a emissão do link temporário (o download em si acontece depois,
    # direto no storage). Nome explícito para a trilha não afirmar mais do que sabe.
    audit('document_download_link_issued', @document, disposition: disposition)
    # O dashboard autentica por cabeçalho, que o navegador não envia ao seguir
    # um link: com mode=url a resposta traz a URL temporária para a tela abrir.
    return render json: { url: temporary_url, expires_in: DOWNLOAD_TTL.to_i } if params[:mode] == 'url'

    redirect_to temporary_url, allow_other_host: true
  end

  private

  def render_too_large
    render json: { error: "O arquivo passa do limite de #{Crm::Documents::Uploader::MAX_BYTES / 1.megabyte} MB." },
           status: :payload_too_large
  end

  def page
    [params[:page].to_i, 1].max
  end

  def paginate(scope)
    per_page = params[:per_page].present? ? params[:per_page].to_i.clamp(1, MAX_PER_PAGE) : DEFAULT_PER_PAGE
    scope.offset((page - 1) * per_page).limit(per_page)
  end

  def load_document
    @document = documents_access.documents.find(params[:id])
  end

  def upload(contact)
    Crm::Documents::Uploader.new(
      contact: contact, io: params[:file], filename: params[:file].original_filename, source: 'upload',
      user: Current.user, folder: find_contact_folder!(contact, params[:folder_id]),
      deal: find_contact_deal!(contact, params[:deal_id]),
      attributes: params.permit(:doc_type, :description, :document_date).to_h
    ).call
  end

  def update_params
    attributes = params.require(:document).permit(*UPDATABLE).to_h.symbolize_keys
    if attributes.key?(:crm_document_folder_id)
      attributes[:crm_document_folder_id] = find_contact_folder!(@document.contact, attributes[:crm_document_folder_id])&.id
    end
    attributes[:crm_deal_id] = find_contact_deal!(@document.contact, attributes[:crm_deal_id])&.id if attributes.key?(:crm_deal_id)
    attributes
  end

  def disposition
    params[:disposition] == 'inline' ? :inline : :attachment
  end

  def temporary_url
    file_name = Crm::Documents::Naming::PathBuilder.new.unique_file_name(@document)
    ActiveStorage::Current.set(url_options: { protocol: request.protocol, host: request.host, port: request.port }) do
      @document.file.blob.url(expires_in: DOWNLOAD_TTL, disposition: disposition,
                              filename: ActiveStorage::Filename.new(file_name))
    end
  end
end
