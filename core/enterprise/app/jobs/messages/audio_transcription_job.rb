class Messages::AudioTranscriptionJob < ApplicationJob
  queue_as :low

  discard_on Faraday::BadRequestError do |job, error|
    log_context = {
      attachment_id: job.arguments.first,
      job_id: job.job_id,
      status_code: error.response&.dig(:status)
    }

    Rails.logger.warn("Discarding audio transcription job due to bad request: #{log_context}")
  end
  retry_on ActiveStorage::FileNotFoundError, wait: 2.seconds, attempts: 3
  retry_on Llm::TransientProviderError, wait: 30.seconds, attempts: 6 do |job, error|
    attachment = Attachment.find_by(id: job.arguments.first)
    attachment&.update!(
      meta: (attachment.meta || {}).merge(
        'media_understanding_status' => 'failed',
        'media_understanding_error' => "transient_provider_exhausted: #{error.message}".truncate(500)
      )
    )
    attachment&.message&.reload&.send_update_event
  end

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return if attachment.blank?

    Messages::AudioTranscriptionService.new(attachment).perform
  end
end
