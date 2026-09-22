require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §8.3 — Caixa de Triagem: tudo que chegou e ainda
# não foi classificado, de todos os clientes que o usuário atende.
RSpec.describe 'CRM Documents triage API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:maria) { create(:contact, account: account, name: 'Maria da Silva') }
  let(:joao) { create(:contact, account: account, name: 'João Pereira') }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/documents/triage" }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Casos', slug: 'casos-triagem', kind: 'legal_intake') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0) }

  before { crm_documents_enable!(account) }

  it 'lista só o que está na triagem sem tipo, de vários clientes, com nome e processos abertos' do
    pending_maria = crm_document_for(maria)
    pending_joao = crm_document_for(joao)
    crm_document_for(maria, doc_type: 'rg')
    deal = account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: maria,
                                     title: 'Aposentadoria')

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    payload = response.parsed_body['payload']
    expect(payload.pluck('id')).to contain_exactly(pending_maria.id, pending_joao.id)
    maria_row = payload.find { |row| row['id'] == pending_maria.id }
    expect(maria_row).to include('contact_name' => 'Maria da Silva')
    expect(maria_row['contact_deals']).to eq([{ 'id' => deal.id, 'title' => 'Aposentadoria' }])
    expect(maria_row['discard_folder_id']).to eq(CrmDocumentFolder.find_by(contact: maria, slot: 'arquivo').id)
    expect(response.parsed_body['meta']['count']).to eq(2)
  end

  it 'mostra ao agente só os clientes que ele atende' do
    inbox = create(:inbox, account: account)
    create(:inbox_member, user: agent, inbox: inbox)
    create(:conversation, account: account, inbox: inbox, contact: maria)
    mine = crm_document_for(maria)
    crm_document_for(joao)

    get url, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('id')).to eq([mine.id])
  end

  it 'classificar pela triagem com o processo leva para a subpasta do processo' do
    document = crm_document_for(maria)
    deal = account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: maria,
                                     title: 'Aposentadoria', legal_area: 'previdenciario')

    patch "/api/v1/accounts/#{account.id}/crm/documents/#{document.id}",
          params: { document: { doc_type: 'cnis', crm_deal_id: deal.id } }, headers: admin.create_new_auth_token, as: :json

    expect(document.reload.crm_document_folder).to have_attributes(slot: 'processo_docs', crm_deal_id: deal.id)
  end
end
