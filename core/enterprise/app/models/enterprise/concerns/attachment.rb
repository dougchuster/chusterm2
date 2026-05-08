module Enterprise::Concerns::Attachment
  extend ActiveSupport::Concern

  included do
    after_create_commit :enqueue_audio_transcription
    after_create_commit :enqueue_media_understanding
  end

  private

  def enqueue_audio_transcription
    return unless file_type.to_sym == :audio

    Messages::AudioTranscriptionJob.perform_later(id)
  end

  def enqueue_media_understanding
    return unless file_type.to_sym.in?(%i[image file])

    Messages::MediaUnderstandingJob.perform_later(id)
  end
end
