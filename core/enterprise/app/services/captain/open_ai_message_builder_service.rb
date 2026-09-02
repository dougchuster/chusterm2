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
    image_context = metadata_context_parts(
      attachments.where(file_type: :image),
      'Contexto analisado da imagem',
      %w[image_description ocr_text]
    )

    audio_text = process_audio(attachments)
    audio_part = text_part("Transcrição do áudio: #{audio_text}") if audio_text.present?

    video_text = process_video(attachments)
    video_part = text_part("Descrição do vídeo: #{video_text}") if video_text.present?

    file_parts = file_attachment_parts(attachments.where.not(file_type: %i[image audio video]))

    [image_content, image_context, audio_part, video_part, file_parts].flatten.compact
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

    audio_attachments.filter_map do |attachment|
      cached_text = attachment.meta&.dig('transcribed_text').presence
      next cached_text.strip if cached_text

      result = Messages::AudioTranscriptionService.new(attachment).perform
      result[:transcriptions].to_s.strip if result[:success]
    end.join(' ')
  end

  def process_video(attachments)
    video_attachments = attachments.where(file_type: :video)
    return '' if video_attachments.blank?
    return '' unless Llm::OpenRouterMultimodalService.active?(purpose: :media)

    service = Llm::OpenRouterMultimodalService.new(purpose: :media)
    video_attachments.filter_map do |attachment|
      attachment.meta&.dig('video_description').presence || service.describe_video(attachment).presence
    end.join("\n")
  end

  def file_attachment_parts(attachments)
    attachments.map do |attachment|
      context = metadata_context_text(
        attachment,
        'Contexto analisado do arquivo',
        %w[document_guess image_description transcribed_text ocr_text]
      )
      text_part(context.presence || 'User has shared an attachment')
    end
  end

  def metadata_context_parts(attachments, label, keys)
    attachments.filter_map do |attachment|
      context = metadata_context_text(attachment, label, keys)
      text_part(context) if context.present?
    end
  end

  def metadata_context_text(attachment, label, keys)
    values = attachment.meta.to_h.slice(*keys).filter_map do |key, value|
      "#{key}: #{value}" if value.present?
    end
    return if values.blank?

    filename = attachment.file.filename.to_s if attachment.file.attached?
    ["#{label}#{" (#{filename})" if filename.present?}", values.join('; ')].join(': ')
  end
end
