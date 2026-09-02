require 'rails_helper'

RSpec.describe Captain::Llm::PdfProcessingService do
  let(:document) { create(:captain_document) }
  let(:service) { described_class.new(document) }
  let(:blob) do
    instance_double(
      ActiveStorage::Blob,
      byte_size: 1024,
      checksum: 'pdf-checksum',
      content_type: 'application/pdf'
    )
  end
  let(:pdf_file) { double('pdf_file', blob: blob) } # rubocop:disable RSpec/VerifiedDoubles

  before do
    allow(document).to receive(:pdf_file).and_return(pdf_file)
    allow(Llm::MediaConfig).to receive(:media_configured?).and_return(true)
  end

  describe '#process' do
    it 'keeps an existing readiness marker' do
      allow(document).to receive(:openai_file_id).and_return('openrouter-inline:existing')

      expect(document).not_to receive(:store_openai_file_id)
      service.process
    end

    it 'stores a local OpenRouter inline marker without uploading to a vendor files API' do
      allow(document).to receive(:openai_file_id).and_return(nil)

      expect(document).to receive(:store_openai_file_id).with('openrouter-inline:pdf-checksum')
      service.process
    end

    it 'replaces a legacy vendor file id with the OpenRouter inline marker' do
      allow(document).to receive(:openai_file_id).and_return('file-old-provider')

      expect(document).to receive(:store_openai_file_id).with('openrouter-inline:pdf-checksum')
      service.process
    end

    it 'rejects documents above the inline processing limit' do
      allow(document).to receive(:openai_file_id).and_return(nil)
      allow(blob).to receive(:byte_size).and_return(Llm::OpenRouterMultimodalService::MAX_INLINE_BYTES + 1)

      expect { service.process }.to raise_error(CustomExceptions::Pdf::UploadError)
    end
  end
end
