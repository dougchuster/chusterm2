class Messages::AudioTranscriptionService
  include Integrations::LlmInstrumentation

  attr_reader :attachment, :message, :account

  def initialize(attachment)
    @attachment = attachment
    @message = attachment.message
    @account = message.account
  end

  def perform
    return { error: 'Message not found' } if message.blank?
    return existing_result if already_transcribed?
    return mark_skipped('captain_integration_disabled') unless account.feature_enabled?('captain_integration')
    return mark_skipped('audio_transcription_disabled') unless audio_transcription_enabled?
    return mark_skipped('audio_transcription_not_configured') unless Llm::MediaConfig.transcription_configured?
    return mark_skipped('transcription_limit_exceeded') unless response_usage_available?

    update_meta(media_understanding_status: 'processing', media_understanding_error: nil)
    transcriptions = transcribe_audio
    return mark_failed('empty_audio_transcription_result') if transcriptions.blank?

    Rails.logger.info(
      "[AudioTranscription] Completed attachment=#{attachment.id} model=#{transcription_model} characters=#{transcriptions.length}"
    )
    { success: true, transcriptions: transcriptions }
  rescue Faraday::UnauthorizedError
    Rails.logger.warn('Skipping audio transcription: transcription provider configuration is invalid or disabled (401 Unauthorized).')
    mark_failed('Transcription provider configuration is invalid or disabled (401)')
  rescue Llm::TransientProviderError => e
    Rails.logger.warn("[AudioTranscription] Temporary provider failure for attachment #{attachment.id}: #{e.message}")
    mark_retrying(e.message)
    raise
  rescue StandardError => e
    Rails.logger.warn("[AudioTranscription] Failed for attachment #{attachment.id}: #{e.message}")
    mark_failed(e.message)
  end

  private

  def response_usage_available?
    account.usage_limits[:captain][:responses][:current_available].positive?
  end

  def audio_transcription_enabled?
    return true if account.audio_transcriptions.nil?

    ActiveModel::Type::Boolean.new.cast(account.audio_transcriptions)
  end

  def already_transcribed?
    attachment.meta&.[]('transcribed_text').present?
  end

  def existing_result
    { success: true, transcriptions: attachment.meta['transcribed_text'] }
  end

  def transcribe_audio
    transcribed_text = attachment.meta&.[]('transcribed_text') || ''
    return transcribed_text if transcribed_text.present?

    transcribed_text = Llm::OpenRouterMultimodalService.new(purpose: :transcription).transcribe_audio(attachment)

    update_transcription(transcribed_text)
    transcribed_text
  end

  def instrumentation_params(file_path)
    {
      span_name: 'llm.messages.audio_transcription',
      model: transcription_model,
      account_id: account&.id,
      feature_name: 'audio_transcription',
      file_path: file_path
    }
  end

  def update_transcription(transcribed_text)
    return if transcribed_text.blank?

    update_meta(
      transcribed_text: transcribed_text,
      media_understanding_status: 'processed',
      media_understanding_error: nil
    )
    message.reload.send_update_event
    message.account.increment_response_usage

    return unless ChusteRMApp.advanced_search_allowed?

    message.reindex
  end

  def transcription_model
    Llm::MediaConfig.transcription_model
  end

  def mark_skipped(reason)
    update_meta(media_understanding_status: 'skipped', media_understanding_error: reason)
    notify_message_update
    { error: reason }
  end

  def mark_failed(reason)
    update_meta(media_understanding_status: 'failed', media_understanding_error: reason.to_s.truncate(500))
    notify_message_update
    { error: reason }
  end

  def mark_retrying(reason)
    update_meta(media_understanding_status: 'processing', media_understanding_error: "transient_provider_retry: #{reason}".truncate(500))
    notify_message_update
    { error: reason, retrying: true }
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
end
