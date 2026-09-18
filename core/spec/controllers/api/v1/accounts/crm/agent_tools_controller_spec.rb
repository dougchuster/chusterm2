# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CRM Agent Tools API', type: :request do
  let(:account) { create(:account) }
  let(:agent_bot) { create(:agent_bot) }
  let(:inbox) { create(:inbox, account: account) }
  let(:bot_headers) { { api_access_token: agent_bot.access_token.token } }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Funil', position: 1, is_default: true) }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo', position: 1) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:deal) do
    CrmDeal.create!(account: account, crm_pipeline: pipeline, crm_pipeline_stage: stage,
                    title: 'Lead teste', contact: contact, conversation: conversation)
  end
  let(:admin_headers) { create(:user, account: account, role: :administrator).create_new_auth_token }

  before { create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot) }

  describe 'GET /crm/agent_tools' do
    it 'lista as tools disponíveis' do
      get "/api/v1/accounts/#{account.id}/crm/agent_tools", headers: bot_headers

      expect(response).to have_http_status(:ok)
      tools = response.parsed_body['tools']
      expect(tools.map { |t| t['name'] }).to include('get_deal_context', 'set_category', 'move_stage')
      expect(tools.find { |t| t['name'] == 'set_category' }['positional']).to eq(['value'])
    end

    it 'nega acesso sem token válido' do
      get "/api/v1/accounts/#{account.id}/crm/agent_tools"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /crm/agent_tools/execute' do
    it 'executa get_deal_context com deal_id' do
      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'get_deal_context', deal_id: deal.id },
           headers: bot_headers

      expect(response).to have_http_status(:ok)
      data = response.parsed_body['data']
      expect(data['deal_id']).to eq(deal.id)
      expect(data['allowed_stages']).to include(stage.slug)
    end

    it 'resolve o deal pela conversation_id' do
      deal.attach_conversation!(conversation)

      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'get_deal_context', conversation_id: conversation.id },
           headers: bot_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'deal_id')).to eq(deal.id)
    end

    it 'executa set_category com args whitelisted' do
      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'set_category', deal_id: deal.id,
                     args: { value: 'previdenciario', reason: 'teste', hack: 'ignorado' } },
           headers: bot_headers

      expect(response).to have_http_status(:ok)
      expect(deal.reload.category).to eq('previdenciario')
      expect(CrmAuditEvent.where(account: account, action: 'ai_set_category').count).to eq(1)
    end

    it 'rejeita tool desconhecida' do
      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'drop_table', deal_id: deal.id },
           headers: bot_headers

      expect(response).to have_http_status(:bad_request)
    end

    it 'retorna 404 quando o deal nao existe' do
      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'get_deal_context', deal_id: 999_999 },
           headers: bot_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'propaga erro da tool como 422' do
      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'set_urgency', deal_id: deal.id, args: { level: 'mega_ultra' } },
           headers: bot_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('urgência')
    end

    it 'funciona também para usuário humano' do
      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'get_deal_context', deal_id: deal.id },
           headers: admin_headers

      expect(response).to have_http_status(:ok)
    end

    it 'não vaza deal de outra conta' do
      other_account = create(:account)
      other_pipeline = CrmPipeline.create!(account: other_account, name: 'Outro', position: 1, is_default: true)
      other_stage = CrmPipelineStage.create!(account: other_account, crm_pipeline: other_pipeline, name: 'Novo', position: 1)
      other_deal = CrmDeal.create!(account: other_account, crm_pipeline: other_pipeline, crm_pipeline_stage: other_stage, title: 'x')

      post "/api/v1/accounts/#{account.id}/crm/agent_tools/execute",
           params: { tool: 'get_deal_context', deal_id: other_deal.id },
           headers: bot_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
