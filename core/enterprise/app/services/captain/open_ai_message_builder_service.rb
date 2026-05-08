class Captain::OpenAiMessageBuilderService
  pattr_initialize [:message!]

  # Extracts text and image URLs from multimodal content array (reverse of generate_content)
  def self.extract_text_and_attachments(content)
    return [content, []] unless content.is_a?(Array)

    text_parts = content.select { |part| part[:type] == 'text' }.pluck(:text)
    image_urls = content.select { |part| part[:type] == 'image_url' }.filter_map { |part| part.dig(:image_url, :url) }
    [text_parts.join(' ').presence, image_urls]
  end

  def generate_content
    parts = []
    parts << text_part(@message.content) if @message.content.present?
    parts.concat(attachment_parts(@message.attachments)) if @message.attachments.any?

    return 'Message without content' if parts.blank?
    return parts.first[:text] if parts.one? && parts.first[:type] == 'text'

    parts
  end

  private

  def text_part(text)
    { type: 'text', text: text }
  end

  def image_part(image_url)
    { type: 'image_url', image_url: { url: image_url } }
  end

  def attachment_parts(attachments)
    image_content = image_parts(attachments.where(file_type: :image))

    audio_text = process_audio(attachments)
    audio_part = text_part("Transcrição do áudio: #{audio_text}") if audio_text.present?

    video_text = process_video(attachments)
    video_part = text_part("Descrição do vídeo: #{video_text}") if video_text.present?

    other_part = text_part('User has shared an attachment') if attachments.where.not(file_type: %i[image audio video]).exists?

    [image_content, audio_part, video_part, other_part].flatten.compact
  end

  def image_parts(image_attachments)
    image_attachments.each_with_object([]) do |attachment, parts|
      url = get_attachment_url(attachment)
      parts << image_part(url) if url.present?
    end
  end

  def get_attachment_url(attachment)
    return attachment.download_url if attachment.download_url.present?
    return attachment.external_url if attachment.external_url.present?

    attachment.file.attached? ? attachment.file_url : nil
  end

  def process_audio(attachments)
    audio_attachments = attachments.where(file_type: :audio)
    return '' if audio_attachments.blank?

    if Llm::MediaConfig.transcription_gemini?
      service = Llm::GeminiMultimodalService.new(purpose: :transcription)
      audio_attachments.filter_map { |a| service.transcribe_audio(a).presence }.join(' ')
    else
      audio_attachments.map do |attachment|
        result = Messages::AudioTranscriptionService.new(attachment).perform
        result[:success] ? result[:transcriptions] : ''
      end.join
    end
  end

  def process_video(attachments)
    video_attachments = attachments.where(file_type: :video)
    return '' if video_attachments.blank?
    return '' unless Llm::GeminiMultimodalService.active?(purpose: :media)

    service = Llm::GeminiMultimodalService.new(purpose: :media)
    video_attachments.filter_map { |a| service.describe_video(a).presence }.join("\n")
  end
end
