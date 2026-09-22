require 'rails_helper'

RSpec.describe 'CRM Document checklist API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Casos', slug: 'casos-checklist-api', kind: 'legal_intake') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0) }
  let(:deal) do
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact, title: 'Caso')
  end
  let!(:template) do
    account.crm_checklist_templates.create!(
      name: 'Divórcio Consensual', legal_area: 'familia',
      items: [{ key: 'certidao_casamento', kind: 'document', title: 'Certidão de casamento', required: true },
              { key: 'relacao_bens', kind: 'document', title: 'Relação de bens', required: true }]
    )
  end
  let(:url) { "/api/v1/accounts/#{account.id}/crm/document_checklist" }

  before { crm_documents_enable!(account) }

  it 'escolhe o checklist, marca item em papel e conta o documento do tipo' do
    crm_document_for(contact, doc_type: 'certidao_casamento')

    patch url, params: { deal_id: deal.id, template_id: template.id }, headers: admin.create_new_auth_token, as: :json
    patch url, params: { deal_id: deal.id, mark: { key: 'relacao_bens', done: true } },
               headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('template_id' => template.id, 'total' => 2, 'done' => 2)
    get url, params: { deal_id: deal.id }, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body['items'].pluck('status')).to eq(%w[received manual])
  end

  it 'responde 404 para quem não atende o cliente' do
    get url, params: { deal_id: deal.id }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
