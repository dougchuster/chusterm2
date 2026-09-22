# Entrada única de arquivos no cofre: upload da equipe, captura de anexos de
# conversa (AttachmentIngestor) e, na F4, o portal. Identifica o tipo real pelo
# conteúdo, deduplica por anexo de origem e por checksum dentro do contato e
# roteia pela nomenclatura.
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
  # Recebe `io` (upload) ou `blob` já pronto (captura: clone por hardlink).
  # `provenance`: source_attachment_id, source_message_id, uploaded_by_contact,
  # received_at (hora em que o cliente mandou) e meta.
  def initialize(contact:, filename:, source:, io: nil, blob: nil, max_bytes: MAX_BYTES, user: nil, folder: nil,
                 deal: nil, attributes: {}, provenance: {})
    @contact = contact
    @account = contact.account
    @io = io
    @prebuilt_blob = blob
    @max_bytes = max_bytes
    @filename = Crm::Documents::Naming::Sanitizer.call(filename, max: 200, fallback: 'arquivo')
    @source = source
    @user = user
    @folder = folder
    @deal = deal
    @attributes = attributes.to_h.symbolize_keys.slice(:doc_type, :description, :document_date, :tags)
    @provenance = provenance.to_h.symbolize_keys
  end
  # rubocop:enable Metrics/ParameterLists

  def call
    by_attachment = find_by_source_attachment
    return Result.new(document: by_attachment, duplicate: true) if by_attachment

    blob = @prebuilt_blob || upload_io
    check_size!(blob.byte_size)
    check_content_type!(blob)
    duplicate = find_duplicate(blob)
    return reuse(duplicate, blob) if duplicate

    Result.new(document: create_document(blob), duplicate: false)
  rescue StandardError
    discard_orphan(blob)
    raise
  end

  private

  # Arquivo que não virou documento não pode ficar ocupando disco.
  def discard_orphan(blob)
    blob.purge if blob&.attachments&.none?
  end

  def upload_io
    check_size!(@io.respond_to?(:size) ? @io.size : nil)
    ActiveStorage::Blob.create_and_upload!(io: @io, filename: @filename, identify: true)
  end

  def check_size!(size)
    return if size.nil? || size <= @max_bytes

    raise InvalidFile, "O arquivo passa do limite de #{@max_bytes / 1.megabyte} MB."
  end

  def check_content_type!(blob)
    return if ALLOWED_CONTENT_TYPES.include?(blob.content_type)

    raise InvalidFile, 'Este tipo de arquivo não é aceito. Envie PDF, imagem, áudio, vídeo ou documento do Office.'
  end

  def find_by_source_attachment
    return if @provenance[:source_attachment_id].blank?

    CrmDocument.find_by(account_id: @account.id, source_attachment_id: @provenance[:source_attachment_id])
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
      byte_size: blob.byte_size, checksum: blob.checksum, file: blob, **@attributes, **provenance_attributes
    )
    Crm::AuditLogger.log(account: @account, actor: @user, action: 'document_created', target: document,
                         payload: { source: @source, folder_id: document.crm_document_folder_id })
    Crm::Documents::Versioner.call(document, actor: @user)
    document
  end

  def provenance_attributes
    attributes = @provenance.slice(:source_attachment_id, :source_message_id, :uploaded_by_contact)
    attributes[:created_at] = @provenance[:received_at] if @provenance[:received_at]
    attributes[:meta] = @provenance[:meta] if @provenance[:meta].present?
    attributes
  end

  def destination_folder
    router = Crm::Documents::Router.new(@contact, deal: @deal)
    return @folder if @folder && @attributes[:doc_type].blank?

    router.folder_for(@attributes[:doc_type], current_folder: @folder)
  end
end
