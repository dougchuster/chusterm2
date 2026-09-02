# frozen_string_literal: true

# OpenRouter processes PDFs inline through its chat-completions API. This service
# keeps the historical openai_file_id column as a local readiness marker so the
# surrounding Captain document pipeline remains backward compatible.
class Captain::Llm::PdfProcessingService
  INLINE_MARKER_PREFIX = 'openrouter-inline'

  def initialize(document)
    @document = document
  end

  def process
    return if document.openai_file_id.to_s.start_with?("#{INLINE_MARKER_PREFIX}:")

    blob = document.pdf_file&.blob
    raise_upload_error if blob.blank? || blob.byte_size > Llm::OpenRouterMultimodalService::MAX_INLINE_BYTES
    raise_upload_error unless blob.content_type == 'application/pdf'
    raise_upload_error unless Llm::MediaConfig.media_configured?

    document.store_openai_file_id("#{INLINE_MARKER_PREFIX}:#{blob.checksum}")
  end

  private

  attr_reader :document

  def raise_upload_error
    raise CustomExceptions::Pdf::UploadError, I18n.t('captain.documents.pdf_upload_failed')
  end
end
