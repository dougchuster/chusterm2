# frozen_string_literal: true

require 'rails_helper'

# 5.4 do PLANO_17_09.md — MCP server: JSON-RPC 2.0 sobre a mesma auth da API.
RSpec.describe 'CRM MCP endpoint', type: :request do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot) }
  let(:inbox) { create(:inbox, account: account) }
  let(:bot_headers) { { api_access_token: agent_bot.access_token.token } }
  let(:pipeline) { account.crm_pipelines.active.default_first.first }
  let(:stage) { pipeline.crm_pipeline_stages.active.ordered.first }
  let(:other_stage) do
    CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', position: 90)
  end
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:deal) do
    CrmDeal.create!(account: account, crm_pipeline: pipeline, crm_pipeline_stage: stage,
                    title: 'Lead teste', contact: contact)
  end
  let(:admin_headers) { create(:user, account: account, role: :administrator).create_new_auth_token }

  before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot) }

  def rpc(method, params: nil, id: 1, headers: admin_headers)
    post "/api/v1/accounts/#{account.id}/crm/mcp",
         params: { jsonrpc: '2.0', id: id, method: method, params: params }.compact,
         headers: headers, as: :json
  end

  describe 'initialize e tools/list' do
    it 'responde o handshake MCP' do
      rpc('initialize')

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['result']['protocolVersion']).to eq('2025-06-18')
      expect(body['result']['serverInfo']['name']).to eq('chusterm-crm')
    end

    it 'lista as tools do plano' do
      rpc('tools/list')

      names = response.parsed_body['result']['tools'].map { |t| t['name'] }
      expect(names).to contain_exactly(
        'deals.search', 'deals.move', 'activities.create', 'contacts.timeline', 'fields.list'
      )
    end

    it 'responde 202 para notification sem id' do
      post "/api/v1/accounts/#{account.id}/crm/mcp",
           params: { jsonrpc: '2.0', method: 'notifications/initialized' },
           headers: admin_headers, as: :json

      expect(response).to have_http_status(:accepted)
    end
  end

  describe 'tools/call' do
    it 'deals.search filtra pela conta' do
      deal
      vizinha = create(:account)
      vizinha.crm_deals.create!(
        crm_pipeline: vizinha.crm_pipelines.first,
        crm_pipeline_stage: vizinha.crm_pipelines.first.crm_pipeline_stages.first,
        title: 'Deal alheio'
      )

      rpc('tools/call', params: { name: 'deals.search', arguments: { q: 'Lead' } })

      result = response.parsed_body['result']
      payload = JSON.parse(result['content'].first['text'])
      expect(payload['deals'].pluck('id')).to eq([deal.id])
    end

    it 'deals.move move de etapa' do
      rpc('tools/call', params: { name: 'deals.move', arguments: { deal_id: deal.id, stage_id: other_stage.id } })

      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload['deal']['stage_id']).to eq(other_stage.id)
    end

    it 'activities.create cria atividade no deal' do
      rpc('tools/call',
          params: { name: 'activities.create',
                    arguments: { deal_id: deal.id, title: 'Ligar amanhã', kind: 'follow_up' } })

      expect(response).to have_http_status(:ok)
      expect(deal.crm_activities.last.title).to eq('Ligar amanhã')
    end

    it 'contacts.timeline devolve deals do contato' do
      deal
      rpc('tools/call', params: { name: 'contacts.timeline', arguments: { contact_id: contact.id } })

      payload = JSON.parse(response.parsed_body['result']['content'].first['text'])
      expect(payload['contact']['name']).to eq('Maria')
      expect(payload['deals'].pluck('id')).to include(deal.id)
    end

    it 'fields.list devolve as definições da conta' do
      rpc('tools/call', params: { name: 'fields.list' })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['result']['content'].first['text']).to include('field_definitions')
    end

    it 'retorna erro JSON-RPC para tool desconhecida' do
      rpc('tools/call', params: { name: 'nope' })

      expect(response.parsed_body['error']['code']).to eq(-32_602)
    end

    it 'funciona com token de AgentBot' do
      deal
      rpc('tools/call', params: { name: 'deals.search', arguments: {} }, headers: bot_headers)

      expect(response).to have_http_status(:ok)
    end
  end
end
