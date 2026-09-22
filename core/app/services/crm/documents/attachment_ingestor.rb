# Captura automática (PROJETO-COFRE-DOCUMENTOS.md §7): transforma um anexo de
# conversa em documento na gaveta do contato.
#
# - Recebido do cliente → 00 Triagem, com sugestão de tipo (nunca classifica
#   sozinho, D9). Enviado pela equipe → 05 Enviados pelo Escritório (D5).
# - O documento ganha CÓPIA PRÓPRIA do arquivo: se a conversa ou a mensagem for
#   apagada, o documento continua existindo — é o problema que o módulo resolve.
# - Idempotente por anexo (webhook duplicado do Evolution) e por checksum.
class Crm::Documents::AttachmentIngestor
  INGESTED_FILE_TYPES = %w[image video file].freeze
  SMALL_IMAGE_BYTES = 40.kilobytes
  CAPTION_MAX_LENGTH = 500
  CAPTURE_OUTGOING_KEY = 'crm_documents_capture_outgoing'.freeze
  SENT_SLOT = 'enviados'.freeze
  SOURCE_BY_CHANNEL = {
    'Channel::Whatsapp' => 'whatsapp', 'Channel::Email' => 'email', 'Channel::Instagram' => 'instagram'
  }.freeze

  def initialize(attachment)
    @attachment = attachment
    @message = attachment.message
    @account = attachment.account
  end

  def call
    return unless ingestible?

    Crm::Documents::Defaults.ensure!(@account)
    existing_document || copy_into_vault
  rescue Crm::Documents::Uploader::InvalidFile => e
    Rails.logger.info("[CRM Documents] anexo #{@attachment.id} ignorado: #{e.message}")
    nil
  rescue ActiveRecord::RecordNotUnique
    existing_document
  end

  private

  def ingestible?
    return false unless public_message_with_contact?
    return false unless Crm::Documents::Feature.enabled?(@account) && document_file?

    @message.incoming? || (@message.outgoing? && capture_outgoing?)
  end

  def public_message_with_contact?
    @message.present? && !@message.private? && contact.present?
  end

  def document_file?
    INGESTED_FILE_TYPES.include?(@attachment.file_type.to_s) && @attachment.file.attached?
  end

  def capture_outgoing?
    @account.settings&.dig(CAPTURE_OUTGOING_KEY) != false
  end

  def contact
    @contact ||= @message.conversation&.contact
  end

  def existing_document
    CrmDocument.find_by(account_id: @account.id, source_attachment_id: @attachment.id)
  end

  def copy_into_vault
    @attachment.file.blob.open do |file|
      Crm::Documents::Uploader.new(
        contact: contact, io: file, filename: @attachment.file.filename.to_s, source: source,
        folder: destination_folder, provenance: provenance
      ).call.document
    end
  end

  def destination_folder
    return unless @message.outgoing?

    Crm::Documents::DrawerProvisioner.new(contact).folder_for_slot(SENT_SLOT)
  end

  def provenance
    { source_attachment_id: @attachment.id, source_message_id: @message.id, uploaded_by_contact: @message.incoming?,
      received_at: @message.created_at, meta: meta }
  end

  def meta
    caption = @message.content.to_s.strip.first(CAPTION_MAX_LENGTH).presence
    suggestion = Crm::Documents::Classifier.new(@account).suggest(caption: caption, filename: @attachment.file.filename.to_s)
    { 'caption' => caption, 'suggested_doc_type' => suggestion, 'likely_irrelevant' => likely_irrelevant?(caption) }.compact
  end

  # Figurinha ou print solto: vai para a triagem marcado, para descartar rápido.
  def likely_irrelevant?(caption)
    return nil unless @attachment.file_type.to_s == 'image' && caption.blank?

    @attachment.file.blob.byte_size < SMALL_IMAGE_BYTES ? true : nil
  end

  def source
    SOURCE_BY_CHANNEL.fetch(@message.inbox&.channel_type.to_s, 'chat')
  end
end
