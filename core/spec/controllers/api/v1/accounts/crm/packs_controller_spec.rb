# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRM Packs API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:headers) { admin.create_new_auth_token }
  let(:agent_headers) { agent.create_new_auth_token }

  describe 'GET /api/v1/accounts/:account_id/crm/packs' do
    it 'responde 404 sem a flag crm_universal' do
      get "/api/v1/accounts/#{account.id}/crm/packs", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    context 'when crm_universal is enabled' do
      before { account.enable_features('crm_universal') }

      it 'lista packs disponíveis e os instalados na conta' do
        get "/api/v1/accounts/#{account.id}/crm/packs", headers: headers

        expect(response).to have_http_status(:ok)
        packs = response.parsed_body['packs']
        expect(packs.map { |p| p['slug'] }).to include('sales_default', 'legal')

        sales = packs.find { |p| p['slug'] == 'sales_default' }
        expect(sales['installed']).to be(true)
        expect(sales['categories'].map { |c| c['value'] }).to include('comercial')

        legal = packs.find { |p| p['slug'] == 'legal' }
        expect(legal['installed']).to be(false)
        expect(legal['field_definitions'].map { |f| f['key'] }).to include('numero_processo')
        expect(legal['ai']['prompt_base']).to include('advocacia')
      end

      it 'devolve ai_settings no payload' do
        get "/api/v1/accounts/#{account.id}/crm/packs", headers: headers

        expect(response.parsed_body['ai_settings']).to eq('prompt_override' => nil)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/packs/ai_settings' do
    before { account.enable_features('crm_universal') }

    it 'salva o override do prompt da IA na conta' do
      patch "/api/v1/accounts/#{account.id}/crm/packs/ai_settings",
            params: { prompt_override: 'Fale como um concierge.' }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(account.reload.custom_attributes['crm_ai_prompt_override']).to eq('Fale como um concierge.')
    end

    it 'prompt vazio volta ao prompt do pack' do
      account.update!(custom_attributes: { 'crm_ai_prompt_override' => 'x' })

      patch "/api/v1/accounts/#{account.id}/crm/packs/ai_settings",
            params: { prompt_override: '' }, headers: headers, as: :json

      expect(account.reload.custom_attributes['crm_ai_prompt_override']).to be_nil
    end

    it 'nega para agente comum' do
      patch "/api/v1/accounts/#{account.id}/crm/packs/ai_settings",
            params: { prompt_override: 'x' }, headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/packs' do
    before { account.enable_features('crm_universal') }

    it 'instala o pack e devolve 201' do
      post "/api/v1/accounts/#{account.id}/crm/packs",
           params: { slug: 'legal' }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_account_packs.pluck(:slug)).to include('legal')
      expect(account.crm_activity_types.pluck(:key)).to include('revisao_juridica')
    end

    it 'é idempotente — reinstalar não duplica tipos' do
      Crm::PackInstaller.new(account).install('legal')

      expect do
        post "/api/v1/accounts/#{account.id}/crm/packs",
             params: { slug: 'legal' }, headers: headers, as: :json
      end.not_to(change { account.crm_activity_types.count })
    end

    it 'devolve 404 para pack inexistente' do
      post "/api/v1/accounts/#{account.id}/crm/packs",
           params: { slug: 'nao-existe' }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'nega instalação para agente comum' do
      post "/api/v1/accounts/#{account.id}/crm/packs",
           params: { slug: 'legal' }, headers: agent_headers, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(account.crm_account_packs.pluck(:slug)).not_to include('legal')
    end
  end
end
