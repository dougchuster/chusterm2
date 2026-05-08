require 'net/http'
require 'base64'
require 'json'

module Llm
  class GeminiMultimodalService
    GEMINI_ENDPOINT_PATTERN = /generativelanguage\.googleapis\.com/.freeze
    MAX_INLINE_BYTES = 20.megabytes
    GEMINI_BASE_URL  = 'https://generativelanguage.googleapis.com'.freeze

    def self.active?(purpose: :media)
      purpose.to_sym == :transcription ? Llm::MediaConfig.transcription_gemini? : Llm::MediaConfig.media_gemini?
    end

    def initialize(purpose: :media)
      @purpose = purpose.to_sym
      @api_key = @purpose == :transcription ? Llm::MediaConfig.transcription_api_key : Llm::MediaConfig.media_api_key
      @model = @purpose == :transcription ? Llm::MediaConfig.transcription_model : Llm::MediaConfig.media_model
    end

    def transcribe_audio(attachment)
      prompt = 'Transcreva exatamente o que é dito neste áudio, na língua original. Retorne apenas a transcrição, sem comentários adicionais.'
      with_inline_data(attachment) { |b64, mime| call_generate_content(b64, mime, prompt) } || ''
    end

    def understand_media(attachment)
      prompt = <<~PROMPT
        Analise este anexo para um CRM juridico. Retorne somente JSON valido, sem markdown.
        Campos:
        - image_description: descricao objetiva do que aparece no arquivo, se aplicavel.
        - ocr_text: texto legivel extraido do arquivo, se houver.
        - document_guess: tipo provavel do documento em snake_case, como rg, cpf, cnh, ctps, cnis, comprovante_residencia, procuracao, contrato, termo_rescisao, extrato, peticao, decisao, outro.

        Se nao tiver certeza, use string vazia no campo incerto.
      PROMPT

      response = with_inline_data(attachment) { |b64, mime| call_generate_content(b64, mime, prompt) }
      parse_media_response(response)
    end

    def describe_video(attachment)
      prompt = 'Descreva detalhadamente o conteúdo deste vídeo: o que acontece, quem aparece, o que é dito (se houver fala). Seja objetivo e completo.'
      with_inline_data(attachment) { |b64, mime| call_generate_content(b64, mime, prompt) } || ''
    end

    private

    def with_inline_data(attachment)
      blob = attachment.file.blob

      if blob.byte_size > MAX_INLINE_BYTES
        Rails.logger.warn("[GeminiMultimodal] Attachment #{attachment.id} too large (#{blob.byte_size} bytes), skipping")
        return nil
      end

      file_data = nil
      blob.open { |f| file_data = f.read }
      yield(Base64.strict_encode64(file_data), blob.content_type)
    rescue StandardError => e
      Rails.logger.warn("[GeminiMultimodal] Failed to process attachment #{attachment.id}: #{e.message}")
      nil
    end

    def call_generate_content(base64_data, mime_type, prompt)
      uri = URI("#{GEMINI_BASE_URL}/v1beta/models/#{@model}:generateContent?key=#{@api_key}")

      body = {
        contents: [{
          parts: [
            { inline_data: { mime_type: mime_type, data: base64_data } },
            { text: prompt }
          ]
        }]
      }

      http            = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl    = true
      http.open_timeout = 30
      http.read_timeout = 120

      request                  = Net::HTTP::Post.new(uri)
      request['Content-Type']  = 'application/json'
      request.body             = body.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[GeminiMultimodal] API error #{response.code}: #{response.body.to_s.truncate(300)}")
        return nil
      end

      JSON.parse(response.body).dig('candidates', 0, 'content', 'parts', 0, 'text')&.strip
    rescue StandardError => e
      Rails.logger.warn("[GeminiMultimodal] API call failed: #{e.message}")
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
  end
end
