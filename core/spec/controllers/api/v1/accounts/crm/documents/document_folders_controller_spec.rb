require 'rails_helper'

RSpec.describe 'CRM Document Folders API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Maria da Silva') }
  let(:base) { "/api/v1/accounts/#{account.id}/crm/document_folders" }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Casos', slug: 'casos-api-docs', kind: 'legal_intake') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0) }

  before { crm_documents_enable!(account) }

  describe 'GET /crm/document_folders' do
    it 'cria a gaveta na primeira visita e devolve a árvore com contagens' do
      document = crm_document_for(contact, doc_type: 'rg')

      get base, params: { contact_id: contact.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['client_folder_name']).to start_with('Maria da Silva · C')
      pessoais = body['folders'].find { |f| f['slot'] == 'pessoais' }
      expect(pessoais).to include('name' => '01 Documentos Pessoais', 'kind' => 'system', 'documents_count' => 1)
      expect(pessoais['id']).to eq(document.crm_document_folder_id)
    end

    it 'garante a pasta do processo quando o negócio é informado' do
      deal = account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact,
                                       title: 'Aposentadoria', legal_area: 'previdenciario')

      get base, params: { contact_id: contact.id, deal_id: deal.id }, headers: admin.create_new_auth_token, as: :json

      body = response.parsed_body
      case_folder = body['folders'].find { |f| f['id'] == body['case_folder_id'] }
      expect(case_folder['name']).to end_with('· Aposentadoria')
      expect(body['folders'].count { |f| f['parent_id'] == case_folder['id'] }).to eq(4)
    end

    it 'recusa negócio de outro contato' do
      other = create(:contact, account: account)
      deal = account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: other, title: 'X')

      get base, params: { contact_id: contact.id, deal_id: deal.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'criar, renomear, mover e arquivar' do
    let(:roots) { Crm::Documents::DrawerProvisioner.new(contact).ensure! }
    let(:processes) { roots.find { |f| f.slot == 'processos' } }

    it 'cria pasta comum dentro de outra' do
      post base, params: { contact_id: contact.id, parent_id: processes.id, name: 'Provas: fotos' },
                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('name' => 'Provas fotos', 'kind' => 'custom', 'parent_id' => processes.id)
    end

    it 'recusa nome repetido na mesma pasta' do
      roots
      post base, params: { contact_id: contact.id, name: '01 documentos pessoais' },
                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'renomeia pasta do modelo sem perder o papel dela' do
      folder = roots.find { |f| f.slot == 'pessoais' }

      patch "#{base}/#{folder.id}", params: { folder: { name: 'Pessoais' } },
                                    headers: admin.create_new_auth_token, as: :json

      expect(folder.reload).to have_attributes(name: 'Pessoais', slot: 'pessoais')
    end

    it 'não arquiva pasta do modelo' do
      delete "#{base}/#{processes.id}", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'não arquiva pasta comum que ainda tem documentos' do
      folder = CrmDocumentFolder.create!(account: account, contact: contact, parent: processes, name: 'Extra')
      crm_document_for(contact).update!(crm_document_folder: folder)

      delete "#{base}/#{folder.id}", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/documentos/)
    end

    it 'arquiva pasta comum vazia' do
      folder = CrmDocumentFolder.create!(account: account, contact: contact, parent: processes, name: 'Extra')

      delete "#{base}/#{folder.id}", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:no_content)
      expect(folder.reload).to be_archived
    end
  end

  describe 'GET /crm/document_types' do
    it 'devolve o catálogo da conta' do
      get "/api/v1/accounts/#{account.id}/crm/document_types", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('slug')).to include('rg', 'cnis', 'outro')
    end
  end
end
