# Enfileira a captura dos anexos de cada mensagem para o cofre de documentos
# (PROJETO-COFRE-DOCUMENTOS.md §7.1). Não toca nenhum serviço de canal: vale
# para WhatsApp, e-mail, Instagram e qualquer canal futuro.
class CrmDocumentIntakeListener < BaseListener
  def message_created(event)
    message = event.data[:message]
    return unless capturable?(message)

    message.attachments.each do |attachment|
      next unless Crm::Documents::AttachmentIngestor::INGESTED_FILE_TYPES.include?(attachment.file_type.to_s)

      Crm::Documents::IngestAttachmentJob.perform_later(attachment.id)
    end
  end

  private

  def capturable?(message)
    return false if message.blank? || message.private?
    return false unless message.incoming? || message.outgoing?

    Crm::Documents::Feature.enabled?(message.account)
  end
end
