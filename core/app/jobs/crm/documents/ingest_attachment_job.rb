# Captura um anexo de conversa para o cofre (PROJETO-COFRE-DOCUMENTOS.md §7).
# Fila de baixa prioridade: nunca atrasa a entrega de mensagens.
class Crm::Documents::IngestAttachmentJob < ApplicationJob
  queue_as :low

  # O arquivo do Evolution pode chegar depois do evento da mensagem.
  retry_on ActiveStorage::FileNotFoundError, wait: 30.seconds, attempts: 5

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return if attachment.nil?

    Crm::Documents::AttachmentIngestor.new(attachment).call
  end
end
