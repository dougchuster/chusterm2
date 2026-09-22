require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §8.5 — filas "Para análise" e "Vencendo".
RSpec.describe 'CRM Documents queues API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Maria da Silva') }
  let(:url) { "/api/v1/accounts/#{account.id}/crm/documents/queue" }

  before { crm_documents_enable!(account) }

  it 'para análise: classificados que ainda não foram aprovados nem rejeitados' do
    waiting = crm_document_for(contact, doc_type: 'rg')
    crm_document_for(contact, doc_type: 'cpf').update!(status: 'approved')
    crm_document_for(contact)

    get url, params: { name: 'review' }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('id')).to eq([waiting.id])
    expect(response.parsed_body['payload'].first['contact_name']).to eq('Maria da Silva')
  end

  it 'vencendo: validade vencida ou nos próximos 30 dias, a mais urgente primeiro' do
    later = crm_document_for(contact, doc_type: 'cnh')
    later.update!(expires_on: Date.current + 20)
    overdue = crm_document_for(contact, doc_type: 'cpf')
    overdue.update!(expires_on: Date.current - 1)
    crm_document_for(contact, doc_type: 'rg').update!(expires_on: Date.current + 90)

    get url, params: { name: 'expiring' }, headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('id')).to eq([overdue.id, later.id])
  end

  it 'recorta pelo que o agente pode ver' do
    crm_document_for(contact, doc_type: 'rg')

    get url, params: { name: 'review' }, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body['payload']).to eq([])
  end

  it 'recusa fila desconhecida' do
    get url, params: { name: 'tudo' }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
