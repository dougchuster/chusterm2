# Entrada única de arquivos no cofre (upload da equipe agora; captura do
# WhatsApp e portal nas próximas fases). Identifica o tipo real pelo conteúdo,
# deduplica por checksum dentro do contato e roteia pela nomenclatura.
class Crm::Documents::Uploader
  class InvalidFile < StandardError; end

  Result = Struct.new(:document, :duplicate, keyword_init: true) do
    def duplicate?
      duplicate == true
    end
  end

  MAX_BYTES = 50.megabytes
  ALLOWED_CONTENT_TYPES = Crm::Documents::Naming::Extension::BY_CONTENT_TYPE.keys.freeze

  # rubocop:disable Metrics/ParameterLists
  def initialize(contact:, io:, filename:, source:, user: nil, folder: nil, deal: nil, attributes: {})
    @contact = contact
    @account = contact.account
    @io = io
    @filename = Crm::Documents::Naming::Sanitizer.call(filename, max: 200, fallback: 'arquivo')
    @source = source
    @user = user
    @folder = folder
    @deal = deal
    @attributes = attributes.to_h.symbolize_keys.slice(:doc_type, :description, :document_date, :tags)
  end
  # rubocop:enable Metrics/ParameterLists

  def call
    check_size!
    blob = ActiveStorage::Blob.create_and_upload!(io: @io, filename: @filename, identify: true)
    check_content_type!(blob)
    duplicate = find_duplicate(blob)
    return reuse(duplicate, blob) if duplicate

    Result.new(document: create_document(blob), duplicate: false)
  rescue StandardError
    blob&.purge unless blob&.attachments&.any?
    raise
  end

  private

  def check_size!
    size = @io.respond_to?(:size) ? @io.size : nil
    return if size.nil? || size <= MAX_BYTES

    raise InvalidFile, "O arquivo passa do limite de #{MAX_BYTES / 1.megabyte} MB."
  end

  def check_content_type!(blob)
    return if ALLOWED_CONTENT_TYPES.include?(blob.content_type)

    raise InvalidFile, 'Este tipo de arquivo não é aceito. Envie PDF, imagem, áudio, vídeo ou documento do Office.'
  end

  def find_duplicate(blob)
    CrmDocument.active.find_by(account_id: @account.id, contact_id: @contact.id, checksum: blob.checksum)
  end

  def reuse(document, blob)
    blob.purge
    Crm::AuditLogger.log(account: @account, actor: @user, action: 'document_resent', target: document,
                         payload: { source: @source, filename: @filename })
    Result.new(document: document, duplicate: true)
  end

  def create_document(blob)
    document = CrmDocument.create!(
      account: @account, contact: @contact, crm_deal: @deal, source: @source, uploaded_by_user: @user,
      crm_document_folder: destination_folder, original_filename: @filename, content_type: blob.content_type,
      byte_size: blob.byte_size, checksum: blob.checksum, file: blob, **@attributes
    )
    Crm::AuditLogger.log(account: @account, actor: @user, action: 'document_created', target: document,
                         payload: { source: @source, folder_id: document.crm_document_folder_id })
    document
  end

  def destination_folder
    router = Crm::Documents::Router.new(@contact, deal: @deal)
    return @folder if @folder && @attributes[:doc_type].blank?

    router.folder_for(@attributes[:doc_type], current_folder: @folder)
  end
end
