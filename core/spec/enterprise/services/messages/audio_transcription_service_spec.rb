require 'rails_helper'

RSpec.describe Messages::AudioTranscriptionService, type: :service do
  let(:account) { create(:account, audio_transcriptions: true) }
  let(:conversation) { create(:conversation, account: account) }
  let(:message) { create(:message, conversation: conversation) }
  let(:attachment) { message.attachments.create!(account: account, file_type: :audio) }

  before do
    # Create required installation configs
    InstallationConfig.find_or_create_by!(name: 'CAPTAIN_OPEN_AI_API_KEY') { |config| config.value = 'test-api-key' }
    InstallationConfig.find_or_create_by!(name: 'CAPTAIN_OPEN_AI_MODEL') { |config| config.value = 'gpt-4o-mini' }

    # Mock usage limits for transcription to be available
    allow(account).to receive(:usage_limits).and_return({ captain: { responses: { current_available: 100 } } })
    allow(Llm::MediaConfig).to receive(:transcription_configured?).and_return(true)
  end

  describe '#perform' do
    let(:service) { described_class.new(attachment) }

    context 'when captain_integration feature is not enabled' do
      before do
        account.disable_features!('captain_integration')
        allow_any_instance_of(Account).to receive(:feature_enabled?).and_call_original
        allow_any_instance_of(Account).to receive(:feature_enabled?).with('captain_integration').and_return(false)
      end

      it 'returns captain integration disabled' do
        expect(service.perform).to eq({ error: 'captain_integration_disabled' })
      end
    end

    context 'when transcription is successful' do
      before do
        allow(service).to receive(:transcribe_audio).and_return('Hello world transcription')
      end

      it 'returns successful transcription' do
        result = service.perform
        expect(result).to eq({ success: true, transcriptions: 'Hello world transcription' })
      end
    end

    context 'when audio transcriptions are disabled' do
      before do
        allow(service).to receive(:audio_transcription_enabled?).and_return(false)
      end

      it 'returns audio transcription disabled' do
        result = service.perform
        expect(result).to eq({ error: 'audio_transcription_disabled' })
      end
    end

    context 'when audio transcription setting is unset' do
      before do
        account.update!(audio_transcriptions: nil)
        allow(service).to receive(:transcribe_audio).and_return('Transcription with default setting')
      end

      it 'treats transcription as enabled when the provider is configured' do
        result = service.perform
        expect(result).to eq({ success: true, transcriptions: 'Transcription with default setting' })
      end
    end

    context 'when attachment already has transcribed text' do
      before do
        attachment.update!(meta: { transcribed_text: 'Existing transcription' })
      end

      it 'returns existing transcription without calling API' do
        result = service.perform
        expect(result).to eq({ success: true, transcriptions: 'Existing transcription' })
      end
    end

    context 'when the provider has a temporary failure' do
      before do
        allow(service).to receive(:transcribe_audio).and_raise(Llm::TransientProviderError, 'timeout')
      end

      it 'keeps the attachment processing and re-raises for job retry' do
        expect { service.perform }.to raise_error(Llm::TransientProviderError)

        expect(attachment.reload.meta).to include(
          'media_understanding_status' => 'processing',
          'media_understanding_error' => a_string_matching(/transient_provider_retry/)
        )
      end
    end
  end

  describe '#transcribe_audio' do
    let(:service) { described_class.new(attachment) }
    let(:openrouter_service) { instance_double(Llm::OpenRouterMultimodalService) }

    before do
      attachment.file.attach(
        io: File.open(Rails.public_path.join('audio/widget/ding.mp3')),
        filename: 'speech.mp3',
        content_type: 'audio/mpeg'
      )
      allow(Llm::OpenRouterMultimodalService).to receive(:new)
        .with(purpose: :transcription)
        .and_return(openrouter_service)
      allow(openrouter_service).to receive(:transcribe_audio).with(attachment).and_return('Teste de áudio')
      allow(service).to receive(:update_transcription)
    end

    it 'routes transcription through OpenRouter' do
      result = service.send(:transcribe_audio)

      expect(result).to eq('Teste de áudio')
      expect(openrouter_service).to have_received(:transcribe_audio).with(attachment)
    end
  end
end
