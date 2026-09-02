require 'base64'
require 'json'
require 'net/http'
require 'uri'

# The nested form keeps this service consistent with the other Llm namespace files.
# rubocop:disable Style/ClassAndModuleChildren
module Llm
  class OpenRouterMultimodalService
    MAX_INLINE_BYTES = 25.megabytes
    TRANSIENT_STATUS_CODES = [408, 409, 429].freeze

    def self.active?(purpose: :media)
      purpose.to_sym == :transcription ? Llm::MediaConfig.transcription_configured? : Llm::MediaConfig.media_configured?
    end

    def initialize(purpose: :media)
      @purpose = purpose.to_sym
      @api_key = @purpose == :transcription ? Llm::MediaConfig.transcription_api_key : Llm::MediaConfig.media_api_key
      @endpoint = @purpose == :transcription ? Llm::MediaConfig.transcription_endpoint : Llm::MediaConfig.media_endpoint
      @model = @purpose == :transcription ? Llm::MediaConfig.transcription_model : Llm::MediaConfig.media_model
    end

    def transcribe_audio(attachment)
      with_inline_data(attachment) do |data, mime_type, filename|
        call_with_models(transcription_model_candidates) do |model|
          response = post_json(
            'audio/transcriptions',
            {
              model: model,
              input_audio: { data: data, format: audio_format(filename, mime_type) },
              language: 'pt'
            }
          )
          response&.dig('text').to_s.strip.presence
        end
      end.to_s
    end

    def understand_media(attachment)
      prompt = <<~PROMPT
        Analise este anexo para um CRM jurídico brasileiro. Retorne somente JSON válido, sem markdown.
        Campos:
        - image_description: descrição objetiva do conteúdo visual, se aplicável.
        - ocr_text: todo texto legível extraído do arquivo, preservando números e datas.
        - document_guess: tipo provável em snake_case, como rg, cpf, cnh, ctps, cnis,
          comprovante_residencia, procuracao, contrato, termo_rescisao, extrato, peticao,
          decisao, laudo_medico, atestado_medico, outro.

        Se não tiver certeza, use string vazia no campo incerto.
      PROMPT

      response = call_media(attachment, prompt, json_response: true)
      parse_media_response(response)
    end

    def describe_video(attachment)
      prompt = <<~PROMPT
        Descreva objetivamente o conteúdo deste vídeo para o histórico de um CRM jurídico brasileiro.
        Informe o que acontece e transcreva as falas relevantes. Retorne somente texto em português.
      PROMPT
      call_media(attachment, prompt, json_response: false).to_s.strip
    end

    private

    def call_media(attachment, prompt, json_response:)
      with_inline_data(attachment) do |data, mime_type, filename|
        call_with_models(media_model_candidates) do |model|
          payload = {
            model: model,
            messages: [{ role: 'user', content: [{ type: 'text', text: prompt }, media_part(data, mime_type, filename)] }]
          }
          payload[:response_format] = { type: 'json_object' } if json_response
          payload[:plugins] = [{ id: 'file-parser', pdf: { engine: 'mistral-ocr' } }] if mime_type == 'application/pdf'

          extract_message_content(post_json('chat/completions', payload))
        end
      end
    end

    def with_inline_data(attachment)
      blob = attachment.file.blob
      if blob.byte_size > MAX_INLINE_BYTES
        Rails.logger.warn("[OpenRouterMultimodal] Attachment #{attachment.id} exceeds #{MAX_INLINE_BYTES} bytes")
        return nil
      end

      file_data = nil
      blob.open { |file| file_data = file.read }
      yield(Base64.strict_encode64(file_data), blob.content_type.to_s, blob.filename.to_s)
    rescue Llm::TransientProviderError
      raise
    rescue StandardError => e
      Rails.logger.warn("[OpenRouterMultimodal] Attachment #{attachment.id} could not be read: #{e.class}")
      nil
    end

    def media_part(data, mime_type, filename)
      data_url = "data:#{mime_type};base64,#{data}"
      return { type: 'image_url', image_url: { url: data_url } } if mime_type.start_with?('image/')
      return { type: 'video_url', video_url: { url: data_url } } if mime_type.start_with?('video/')

      { type: 'file', file: { filename: filename, file_data: data_url } }
    end

    def post_json(path, payload)
      uri = URI.join(Llm::Config.normalize_endpoint(@endpoint), path)
      response = build_http(uri).request(build_request(uri, payload))
      return parse_json_response(response.body) if response.is_a?(Net::HTTPSuccess)

      handle_error_response(response, payload[:model])
    rescue Timeout::Error, Errno::ECONNRESET, EOFError => e
      raise Llm::TransientProviderError, "OpenRouter network error: #{e.class}"
    end

    def build_http(uri)
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 30
        http.read_timeout = 120
      end
    end

    def build_request(uri, payload)
      Net::HTTP::Post.new(uri).tap do |request|
        request['Authorization'] = "Bearer #{@api_key}"
        request['Content-Type'] = 'application/json'
        request['HTTP-Referer'] = ENV.fetch('FRONTEND_URL', nil) if ENV.fetch('FRONTEND_URL', nil).present?
        request['X-Title'] = 'ChusteRM'
        request.body = payload.to_json
      end
    end

    def parse_json_response(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise Llm::TransientProviderError, "OpenRouter invalid JSON response: #{e.message}"
    end

    def handle_error_response(response, model)
      code = response.code.to_i
      message = parsed_error_message(response.body)
      Rails.logger.warn("[OpenRouterMultimodal] API error status=#{code} model=#{model} error=#{message.truncate(180)}")
      raise Llm::TransientProviderError, "OpenRouter temporary API error #{code}" if
        TRANSIENT_STATUS_CODES.include?(code) || code >= 500

      nil
    end

    def parsed_error_message(body)
      JSON.parse(body).dig('error', 'message').to_s.presence || 'unknown_error'
    rescue JSON::ParserError
      'invalid_error_response'
    end

    def call_with_models(models)
      last_transient_error = nil
      models.each do |model|
        result = yield(model)
        return result if result.present?
      rescue Llm::TransientProviderError => e
        last_transient_error = e
        Rails.logger.warn("[OpenRouterMultimodal] Temporary failure model=#{model}; trying configured fallback")
      end
      raise last_transient_error if last_transient_error

      nil
    end

    def transcription_model_candidates
      model_candidates('CAPTAIN_AUDIO_TRANSCRIPTION_FALLBACK_MODELS')
    end

    def media_model_candidates
      model_candidates('CAPTAIN_MEDIA_AI_FALLBACK_MODELS')
    end

    def model_candidates(fallback_config_name)
      fallback_value = InstallationConfig.find_by(name: fallback_config_name)&.value.presence || ENV.fetch(fallback_config_name, nil)
      ([Llm::MediaConfig.normalize_model(@model)] + fallback_value.to_s.split(',').map(&:strip)).compact_blank.uniq
    end

    def extract_message_content(response)
      content = response&.dig('choices', 0, 'message', 'content')
      return content if content.is_a?(String)
      return content.filter_map { |part| part['text'] }.join("\n") if content.is_a?(Array)

      nil
    end

    def parse_media_response(response)
      return {} if response.blank?

      sanitized = response.strip.sub(/\A```(?:json)?\s*\n?/, '').sub(/\n?\s*```\s*\z/, '').strip
      data = JSON.parse(sanitized)
      {
        image_description: data['image_description'].to_s.strip,
        ocr_text: data['ocr_text'].to_s.strip,
        document_guess: data['document_guess'].to_s.strip
      }
    rescue JSON::ParserError
      { image_description: response.to_s.strip }
    end

    def audio_format(filename, mime_type)
      extension = File.extname(filename).delete('.').downcase
      return extension if extension.present?

      subtype = mime_type.split(';').first.to_s.split('/').last.to_s.downcase
      { 'mpeg' => 'mp3', 'x-m4a' => 'm4a', 'x-wav' => 'wav', 'mp4' => 'm4a' }.fetch(subtype, subtype.presence || 'ogg')
    end
  end
end
# rubocop:enable Style/ClassAndModuleChildren
