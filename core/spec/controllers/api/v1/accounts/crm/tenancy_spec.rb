require 'rails_helper'

# CRM-020: invariante de isolamento multi-tenant da API CRM.
# Dois contratos distintos:
#  - usuário que NÃO é membro da conta da URL -> 401 (account_accessible_for_user?)
#  - membro da conta tentando id de recurso de OUTRA conta -> 404 (escopo Current.account)
RSpec.describe 'CRM API tenancy isolation', type: :request do
  let(:account_a) { create(:account) }
  let(:account_b) { create(:account) }
  let(:admin_a) { create(:user, account: account_a, role: :administrator) }
  let(:admin_b) { create(:user, account: account_b, role: :administrator) }
  let(:agent_b) { create(:user, account: account_b, role: :agent) }
  let(:headers_a) { admin_a.create_new_auth_token }
  let(:headers_b) { admin_b.create_new_auth_token }
  let(:headers_agent_b) { agent_b.create_new_auth_token }

  let(:pipeline_a) { CrmPipeline.create!(account: account_a, name: 'Pipeline A', position: 1, is_default: true) }
  let(:stage_a) { CrmPipelineStage.create!(account: account_a, crm_pipeline: pipeline_a, name: 'Novo', position: 1) }
  let!(:deal_a) do
    CrmDeal.create!(account: account_a, crm_pipeline: pipeline_a, crm_pipeline_stage: stage_a, title: 'Negócio da conta A')
  end

  describe 'usuário sem membership na conta da URL' do
    it 'nega listagem de deals da conta B com token da conta A' do
      get "/api/v1/accounts/#{account_b.id}/crm/deals", headers: headers_a, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'nega leitura do deal pelo id dentro da conta B' do
      get "/api/v1/accounts/#{account_b.id}/crm/deals/#{deal_a.id}", headers: headers_a, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'membro da conta acessando id de recurso de outra conta' do
    it 'retorna 404 no show do deal estrangeiro' do
      get "/api/v1/accounts/#{account_b.id}/crm/deals/#{deal_a.id}", headers: headers_b, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'retorna 404 no update e não altera o deal estrangeiro' do
      patch "/api/v1/accounts/#{account_b.id}/crm/deals/#{deal_a.id}",
            params: { title: 'Título adulterado' }, headers: headers_b, as: :json

      expect(response).to have_http_status(:not_found)
      expect(deal_a.reload.title).to eq('Negócio da conta A')
    end

    it 'ignora id estrangeiro no bulk_action e não atribui dono' do
      post "/api/v1/accounts/#{account_b.id}/crm/deals/bulk_action",
           params: { bulk_action: 'assign_owner', deal_ids: [deal_a.id], owner_id: admin_b.id },
           headers: headers_b, as: :json

      expect(response).to have_http_status(:success)
      expect(deal_a.reload.owner_id).to be_nil
      expect(deal_a.reload.assignee_id).to be_nil
    end

    it 'retorna 404 ao mover deal estrangeiro' do
      post "/api/v1/accounts/#{account_b.id}/crm/deals/#{deal_a.id}/move",
           params: { stage_id: stage_a.id }, headers: headers_b, as: :json

      expect(response).to have_http_status(:not_found)
      expect(deal_a.reload.crm_pipeline_stage_id).to eq(stage_a.id)
    end
  end

  describe 'trilha de auditoria' do
    let!(:event_b) do
      pipeline = CrmPipeline.create!(account: account_b, name: 'Pipeline B', position: 1, is_default: true)
      stage = CrmPipelineStage.create!(account: account_b, crm_pipeline: pipeline, name: 'Novo', position: 1)
      deal = CrmDeal.create!(account: account_b, crm_pipeline: pipeline, crm_pipeline_stage: stage,
                             title: 'Negócio da conta B')
      CrmAuditEvent.create!(account: account_b, action: 'deal_created', actor_type: 'user', actor_id: admin_b.id,
                            target_type: 'CrmDeal', target_id: deal.id, payload: {}, created_at: Time.current)
    end

    it 'nega leitura para agente não-admin da própria conta' do
      get "/api/v1/accounts/#{account_b.id}/crm/audit-events", headers: headers_agent_b, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'admin da conta A não enxerga eventos da conta B' do
      CrmAuditEvent.create!(account: account_a, action: 'deal_created', actor_type: 'user', actor_id: admin_a.id,
                            target_type: 'CrmDeal', target_id: deal_a.id, payload: {}, created_at: Time.current)

      get "/api/v1/accounts/#{account_a.id}/crm/audit-events", headers: headers_a, as: :json

      expect(response).to have_http_status(:success)
      ids = response.parsed_body.map { |e| e['id'] }
      expect(ids).not_to include(event_b.id)
    end
  end
end
