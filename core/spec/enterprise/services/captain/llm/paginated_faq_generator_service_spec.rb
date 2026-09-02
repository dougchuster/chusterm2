require 'rails_helper'

RSpec.describe Captain::Llm::PaginatedFaqGeneratorService do
  let(:document) { create(:captain_document) }
  let(:service) { described_class.new(document, pages_per_chunk: 5) }
  let(:openai_client) { instance_double(OpenAI::Client) }
  let(:blob) do
    instance_double(
      ActiveStorage::Blob,
      filename: ActiveStorage::Filename.new('beneficio.pdf'),
      byte_size: 1024,
      download: '%PDF synthetic content'
    )
  end
  let(:pdf_file) { double('pdf_file', blob: blob) } # rubocop:disable RSpec/VerifiedDoubles

  before do
    allow(document).to receive(:pdf_file).and_return(pdf_file)
    allow(Llm::Config).to receive(:system_api_key).and_return('test-openrouter-key')
    allow(Llm::Config).to receive(:openai_endpoint).and_return('https://openrouter.ai/api/v1')
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
  end

  describe '#generate' do
    context 'when document lacks OpenAI file ID' do
      before do
        allow(document).to receive(:openai_file_id).and_return(nil)
      end

      it 'raises an error' do
        expect { service.generate }.to raise_error(CustomExceptions::Pdf::FaqGenerationError)
      end
    end

    context 'when generating FAQs from PDF pages' do
      let(:faq_response) do
        {
          'choices' => [{
            'message' => {
              'content' => JSON.generate({
                                           'faqs' => [
                                             { 'question' => 'What is this document about?', 'answer' => 'It explains key concepts.' }
                                           ],
                                           'has_content' => true
                                         })
            }
          }]
        }
      end

      let(:empty_response) do
        {
          'choices' => [{
            'message' => {
              'content' => JSON.generate({
                                           'faqs' => [],
                                           'has_content' => false
                                         })
            }
          }]
        }
      end

      before do
        allow(document).to receive(:openai_file_id).and_return('openrouter-inline:pdf-checksum')
      end

      it 'generates FAQs from paginated content' do
        allow(openai_client).to receive(:chat).and_return(faq_response, empty_response)

        faqs = service.generate

        expect(faqs).to have_attributes(size: 1)
        expect(faqs.first['question']).to eq('What is this document about?')
        expect(openai_client).to have_received(:chat).with(
          parameters: hash_including(
            model: 'google/gemini-2.5-flash',
            plugins: [{ id: 'file-parser', pdf: { engine: 'mistral-ocr' } }]
          )
        ).at_least(:once)
      end

      it 'stops when no more content' do
        allow(openai_client).to receive(:chat).and_return(empty_response)

        faqs = service.generate

        expect(faqs).to be_empty
      end

      it 'respects max iterations limit' do
        allow(openai_client).to receive(:chat).and_return(faq_response)

        # Force max iterations
        service.instance_variable_set(:@iterations_completed, 19)

        service.generate
        expect(service.iterations_completed).to eq(20)
      end
    end
  end

  describe '#should_continue_processing?' do
    it 'stops at max iterations' do
      service.instance_variable_set(:@iterations_completed, 20)
      expect(service.should_continue_processing?(faqs: ['faq'], has_content: true)).to be false
    end

    it 'stops when no FAQs returned' do
      expect(service.should_continue_processing?(faqs: [], has_content: true)).to be false
    end

    it 'continues when FAQs exist and under limits' do
      expect(service.should_continue_processing?(faqs: ['faq'], has_content: true)).to be true
    end
  end
end
