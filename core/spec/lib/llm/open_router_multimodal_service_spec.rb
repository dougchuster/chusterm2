require 'rails_helper'

RSpec.describe Llm::OpenRouterMultimodalService do
  before do
    allow(Llm::MediaConfig).to receive_messages(
      transcription_api_key: 'test-key',
      transcription_endpoint: 'https://openrouter.ai/api/v1',
      transcription_model: 'openai/gpt-4o-transcribe',
      media_api_key: 'test-key',
      media_endpoint: 'https://openrouter.ai/api/v1',
      media_model: 'google/gemini-2.5-flash'
    )
    allow(InstallationConfig).to receive(:find_by).and_return(nil)
  end

  describe '#transcribe_audio' do
    it 'sends base64 audio only to the OpenRouter transcription endpoint' do
      service = described_class.new(purpose: :transcription)
      attachment = instance_double(Attachment)
      allow(service).to receive(:with_inline_data).with(attachment).and_yield('encoded-audio', 'audio/ogg', 'lead.ogg')
      allow(service).to receive(:post_json).and_return({ 'text' => 'Quero atendimento previdenciário.' })

      result = service.transcribe_audio(attachment)

      expect(result).to eq('Quero atendimento previdenciário.')
      expect(service).to have_received(:post_json).with(
        'audio/transcriptions',
        {
          model: 'openai/gpt-4o-transcribe',
          input_audio: { data: 'encoded-audio', format: 'ogg' },
          language: 'pt'
        }
      )
    end
  end

  describe '#understand_media' do
    it 'uses OpenRouter file parsing for PDF documents' do
      service = described_class.new
      attachment = instance_double(Attachment)
      allow(service).to receive(:with_inline_data).with(attachment).and_yield('encoded-pdf', 'application/pdf', 'cnis.pdf')
      allow(service).to receive(:post_json).and_return(
        {
          'choices' => [{ 'message' => { 'content' => '{"image_description":"","ocr_text":"CNIS 2026","document_guess":"cnis"}' } }]
        }
      )

      result = service.understand_media(attachment)

      expect(result).to include(ocr_text: 'CNIS 2026', document_guess: 'cnis')
      expect(service).to have_received(:post_json).with(
        'chat/completions',
        hash_including(
          model: 'google/gemini-2.5-flash',
          plugins: [{ id: 'file-parser', pdf: { engine: 'mistral-ocr' } }]
        )
      )
    end
  end
end
