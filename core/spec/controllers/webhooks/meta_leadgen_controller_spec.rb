require 'rails_helper'

RSpec.describe Webhooks::MetaLeadgenController, type: :request do
  before do
    allow(GlobalConfigService).to receive(:load).with('META_WEBHOOK_VERIFY_TOKEN', nil).and_return('verify-token-123')
  end

  describe 'GET /webhooks/meta_leadgen' do
    it 'retorna o challenge quando o token confere' do
      get '/webhooks/meta_leadgen', params: {
        'hub.mode' => 'subscribe',
        'hub.verify_token' => 'verify-token-123',
        'hub.challenge' => 'challenge-abc'
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('challenge-abc')
    end

    it 'rejeita token errado' do
      get '/webhooks/meta_leadgen', params: {
        'hub.mode' => 'subscribe',
        'hub.verify_token' => 'wrong',
        'hub.challenge' => 'challenge-abc'
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /webhooks/meta_leadgen' do
    let(:payload) do
      {
        object: 'page',
        entry: [
          {
            id: 'page_1',
            changes: [
              { field: 'leadgen', value: { leadgen_id: 'lead_1', form_id: 'form_1', page_id: 'page_1' } },
              { field: 'leadgen', value: { leadgen_id: 'lead_2', form_id: 'form_1', page_id: 'page_1' } }
            ]
          }
        ]
      }
    end

    it 'enfileira um job por leadgen_id' do
      expect do
        post '/webhooks/meta_leadgen', params: payload, as: :json
      end.to have_enqueued_job(Marketing::LeadgenIngestJob).with('lead_1', anything)
                                                           .and have_enqueued_job(Marketing::LeadgenIngestJob).with('lead_2', anything)

      expect(response).to have_http_status(:ok)
    end

    it 'ignora payloads sem leadgen' do
      expect do
        post '/webhooks/meta_leadgen', params: { object: 'page', entry: [] }, as: :json
      end.not_to have_enqueued_job(Marketing::LeadgenIngestJob)

      expect(response).to have_http_status(:ok)
    end

    it 'deduplica leadgen_ids repetidos no mesmo payload' do
      dup = payload.deep_dup
      dup[:entry][0][:changes] << { field: 'leadgen', value: { leadgen_id: 'lead_1' } }

      expect(Marketing::LeadgenIngestJob).to receive(:perform_later).twice
      post '/webhooks/meta_leadgen', params: dup, as: :json
    end
  end
end
