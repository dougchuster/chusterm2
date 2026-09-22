require 'rails_helper'

RSpec.describe 'CRM Documents API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account, name: 'Maria da Silva') }
  let(:base) { "/api/v1/accounts/#{account.id}/crm/documents" }

  before { crm_documents_enable!(account) }

  describe 'módulo desligado' do
    it 'responde 404 em qualquer rota' do
      Crm::Documents::Feature.disable!(account)

      get base, params: { contact_id: contact.id }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /crm/documents' do
    it 'lista os documentos ativos do contato com caminho e link de download' do
      document = crm_document_for(contact, doc_type: 'rg')
      crm_document_for(contact).update!(archived_at: Time.current)

      get base, params: { contact_id: contact.id }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['payload'].pluck('id')).to eq([document.id])
      expect(body['payload'].first).to include('file_name' => document.file_name, 'doc_type' => 'rg',
                                               'folder_id' => document.crm_document_folder_id)
      expect(body['payload'].first['path']).to start_with('Clientes/Maria da Silva · C')
      expect(body['payload'].first['download_path']).to end_with("/crm/documents/#{document.id}/download")
      expect(body['meta']).to include('count' => 1)
    end

    it 'filtra por pasta e por busca' do
      rg = crm_document_for(contact, doc_type: 'rg')
      crm_document_for(contact, doc_type: 'cnis')

      get base, params: { contact_id: contact.id, folder_id: rg.crm_document_folder_id, q: 'rg' },
                headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([rg.id])
    end

    it 'mostra os arquivados quando pedido' do
      archived = crm_document_for(contact)
      archived.update!(archived_at: Time.current)

      get base, params: { contact_id: contact.id, archived: true }, headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body['payload'].pluck('id')).to eq([archived.id])
    end

    it 'responde 404 para agente que não atende o contato' do
      crm_document_for(contact)

      get base, params: { contact_id: contact.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /crm/documents' do
    it 'recebe o arquivo e guarda na triagem' do
      post base, params: { contact_id: contact.id, file: crm_pdf_upload('RG da Maria.pdf') },
                 headers: admin.create_new_auth_token

      expect(response).to have_http_status(:created)
      document = CrmDocument.last
      expect(document.crm_document_folder.slot).to eq('triagem')
      expect(document.uploaded_by_user_id).to eq(admin.id)
      expect(response.parsed_body).to include('duplicate' => false)
    end

    it 'classifica e roteia quando o tipo vem junto' do
      post base, params: { contact_id: contact.id, doc_type: 'rg', description: 'Frente e verso',
                           file: crm_pdf_upload }, headers: admin.create_new_auth_token

      expect(CrmDocument.last.crm_document_folder.slot).to eq('pessoais')
      expect(response.parsed_body['document']['file_name']).to end_with('— RG — Frente e verso.pdf')
    end

    it 'avisa quando o arquivo já existia, sem duplicar' do
      post base, params: { contact_id: contact.id, file: crm_pdf_upload }, headers: admin.create_new_auth_token
      post base, params: { contact_id: contact.id, file: crm_pdf_upload('outro-nome.pdf') },
                 headers: admin.create_new_auth_token

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['duplicate']).to be(true)
      expect(CrmDocument.count).to eq(1)
    end

    it 'recusa tipo de arquivo não aceito com mensagem clara' do
      post base, params: { contact_id: contact.id, file: crm_pdf_upload('x.html', '<html><body>x</body></html>') },
                 headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to match(/não é aceito/)
    end

    it 'exige o arquivo' do
      post base, params: { contact_id: contact.id }, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /crm/documents/:id' do
    it 'classifica da triagem e move para a pasta do tipo' do
      document = crm_document_for(contact)

      patch "#{base}/#{document.id}", params: { document: { doc_type: 'cpf' } },
                                      headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(document.reload.crm_document_folder.slot).to eq('pessoais')
      expect(document.file_name).to end_with('— CPF.pdf')
    end

    it 'não tira da pasta atual quando o documento já estava organizado' do
      document = crm_document_for(contact, doc_type: 'rg')

      patch "#{base}/#{document.id}", params: { document: { doc_type: 'cnh' } },
                                      headers: admin.create_new_auth_token, as: :json

      expect(document.reload.crm_document_folder.slot).to eq('pessoais')
    end

    it 'trava o nome quando a equipe renomeia' do
      document = crm_document_for(contact, doc_type: 'rg')

      patch "#{base}/#{document.id}", params: { document: { file_name: 'RG antigo.pdf' } },
                                      headers: admin.create_new_auth_token, as: :json

      expect(document.reload).to have_attributes(file_name: 'RG antigo.pdf', name_locked: true)
    end

    it 'exige motivo ao rejeitar' do
      document = crm_document_for(contact, doc_type: 'rg')

      patch "#{base}/#{document.id}", params: { document: { status: 'rejected' } },
                                      headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'registra a mudança na auditoria' do
      document = crm_document_for(contact)

      patch "#{base}/#{document.id}", params: { document: { doc_type: 'cpf' } },
                                      headers: admin.create_new_auth_token, as: :json

      expect(CrmAuditEvent.for_target('CrmDocument', document.id).pluck(:action)).to include('document_updated')
    end
  end

  describe 'arquivar, restaurar e apagar' do
    it 'arquiva e restaura' do
      document = crm_document_for(contact)

      delete "#{base}/#{document.id}", headers: agent_with_access.create_new_auth_token
      expect(document.reload).to be_archived

      post "#{base}/#{document.id}/restore", headers: agent_with_access.create_new_auth_token
      expect(document.reload).not_to be_archived
    end

    it 'só o administrador apaga de vez' do
      document = crm_document_for(contact)

      delete "#{base}/#{document.id}/purge", headers: agent_with_access.create_new_auth_token
      expect(response).to have_http_status(:unauthorized)

      delete "#{base}/#{document.id}/purge", headers: admin.create_new_auth_token
      expect(response).to have_http_status(:no_content)
      expect(CrmDocument.exists?(document.id)).to be(false)
    end
  end

  describe 'GET /crm/documents/:id/download' do
    it 'registra o acesso e redireciona para um link temporário' do
      document = crm_document_for(contact, doc_type: 'rg')

      get "#{base}/#{document.id}/download", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:found)
      expect(response.location).to include('/rails/active_storage/disk/')
      expect(CrmAuditEvent.for_target('CrmDocument', document.id).pluck(:action)).to include('document_download_link_issued')
    end

    it 'devolve a URL temporária em JSON para o dashboard abrir' do
      document = crm_document_for(contact, doc_type: 'rg')

      get "#{base}/#{document.id}/download", params: { disposition: 'inline', mode: 'url' },
                                             headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['url']).to include('/rails/active_storage/disk/')
      expect(response.parsed_body['expires_in']).to eq(300)
    end
  end

  def agent_with_access
    @agent_with_access ||= begin
      inbox = create(:inbox, account: account)
      create(:inbox_member, user: agent, inbox: inbox)
      create(:conversation, account: account, inbox: inbox, contact: contact)
      agent
    end
  end
end
