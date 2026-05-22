class Messages::MediaUnderstandingService
  SUPPORTED_FILE_CONTENT_TYPES = %w[
    application/pdf
    image/jpeg
    image/png
    image/webp
    image/heic
    image/heif
    video/mp4
    video/quicktime
    video/webm
  ].freeze

  attr_reader :attachment, :message, :account

  def initialize(attachment)
    @attachment = attachment
    @message = attachment.message
    @account = message.account
  end

  def perform
    return { error: 'Message not found' } if message.blank?
    return { error: 'Unsupported attachment' } unless supported_attachment?
    return existing_result if already_processed?
    return mark_skipped('captain_integration_disabled') unless account.feature_enabled?('captain_integration')
    return mark_skipped('gemini_multimodal_not_configured') unless Llm::GeminiMultimodalService.active?(purpose: :media)

    update_meta(media_understanding_status: 'processing')
    result = understand_attachment
    return mark_failed('empty_media_understanding_result') if result.blank?

    update_meta(result.merge(media_understanding_status: 'processed', media_understanding_error: nil))
    sync_document_labels
    notify_message_update
    { success: true, result: result }
  rescue StandardError => e
    Rails.logger.warn("[MediaUnderstanding] Failed for attachment #{attachment.id}: #{e.message}")
    mark_failed(e.message)
  end

  private

  def supported_attachment?
    return false unless attachment.file.attached?
    return true if attachment.image?
    return SUPPORTED_FILE_CONTENT_TYPES.include?(attachment.file.blob.content_type.to_s) if attachment.video?

    attachment.file? && SUPPORTED_FILE_CONTENT_TYPES.include?(attachment.file.blob.content_type.to_s)
  end

  def understand_attachment
    multimodal = Llm::GeminiMultimodalService.new
    return { video_description: multimodal.describe_video(attachment) } if attachment.video?

    multimodal.understand_media(attachment)
  end

  def already_processed?
    attachment.meta&.dig('media_understanding_status') == 'processed'
  end

  def existing_result
    sync_document_labels

    {
      success: true,
      result: {
        image_description: attachment.meta&.dig('image_description'),
        video_description: attachment.meta&.dig('video_description'),
        ocr_text: attachment.meta&.dig('ocr_text'),
        document_guess: attachment.meta&.dig('document_guess')
      }
    }
  end

  def mark_skipped(reason)
    update_meta(media_understanding_status: 'skipped', media_understanding_error: reason)
    { error: reason }
  end

  def mark_failed(reason)
    update_meta(media_understanding_status: 'failed', media_understanding_error: reason.to_s.truncate(500))
    { error: reason }
  end

  def update_meta(values)
    normalized_values = values.stringify_keys
    next_meta = (attachment.meta || {}).merge(normalized_values)
    next_meta.delete('media_understanding_error') if normalized_values['media_understanding_error'].nil?

    attachment.update!(meta: next_meta)
  end

  def notify_message_update
    message.reload.send_update_event
    message.reindex if ChusteRMApp.advanced_search_allowed?
  end

  def sync_document_labels
    Crm::DocumentLabelSync.new(attachment).perform
  rescue StandardError => e
    Rails.logger.warn("[MediaUnderstanding] Failed to sync CRM document labels for attachment #{attachment.id}: #{e.message}")
  end
end
