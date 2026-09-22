# Captura para o cofre os anexos que já existiam antes do módulo
# (PROJETO-COFRE-DOCUMENTOS.md §7.4). Idempotente e em lotes: roda de novo sem
# duplicar e sem carregar tudo na memória. Rodar em janela noturna.
class Crm::Documents::Backfill
  BATCH_SIZE = 500

  Report = Struct.new(:scanned, :created, :skipped, keyword_init: true)

  def initialize(account:, since: nil)
    @account = account
    @since = since
  end

  def call
    report = Report.new(scanned: 0, created: 0, skipped: 0)
    scope.find_each(batch_size: BATCH_SIZE) do |attachment|
      report.scanned += 1
      created?(attachment) ? report.created += 1 : report.skipped += 1
    end
    report
  end

  private

  def scope
    records = Attachment.where(account_id: @account.id, file_type: Crm::Documents::AttachmentIngestor::INGESTED_FILE_TYPES)
                        .joins(:message)
                        .where(messages: { private: false, message_type: %w[incoming outgoing] })
    records = records.where(attachments: { created_at: @since.beginning_of_day.. }) if @since
    records
  end

  def created?(attachment)
    return false if CrmDocument.exists?(account_id: @account.id, source_attachment_id: attachment.id)

    document = Crm::Documents::AttachmentIngestor.new(attachment).call
    document.present? && document.source_attachment_id == attachment.id
  end
end
