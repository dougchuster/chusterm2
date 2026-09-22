require 'rails_helper'

# Configuração do cofre pela tela: modelo por área, padrões de nome, tipos,
# pastas, formulários e fila de envios.
RSpec.describe 'CRM Documents configuration API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}/crm" }

  before { crm_documents_enable!(account, preset: 'geral') }

  describe 'document_settings' do
    it 'mostra o modelo, os padrões de nome e os marcadores aceitos' do
      get "#{base}/document_settings", headers: agent.create_new_auth_token, as: :json

      body = response.parsed_body
      expect(body['preset']).to eq('geral')
      expect(body['presets'].pluck('slug')).to include('legal', 'clinic')
      expect(body['effective_naming']['file']).to eq('{data} — {tipo} — {descricao}')
      expect(body['naming_tokens']['client_folder']).to eq(%w[nome codigo])
    end

    it 'o administrador troca o modelo e o padrão de nome' do
      patch "#{base}/document_settings", params: { preset: 'education', naming: { file: '{tipo} - {data}' } },
                                         headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('preset' => 'education')
      expect(response.parsed_body['effective_naming']['file']).to eq('{tipo} - {data}')
      expect(account.crm_document_types.pluck(:slug)).to include('historico_escolar')
    end

    it 'recusa padrão inválido e modelo desconhecido' do
      patch "#{base}/document_settings", params: { naming: { client_folder: '{nome}' } },
                                         headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      patch "#{base}/document_settings", params: { preset: 'marte' }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'agente não altera a configuração' do
      patch "#{base}/document_settings", params: { preset: 'legal' }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'document_types' do
    it 'o administrador cria, edita e desativa um tipo' do
      post "#{base}/document_types", params: { slug: 'alvara', label: 'Alvará', target_slot: 'contratos', validity_days: 365 },
                                     headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:created)
      id = response.parsed_body['id']

      patch "#{base}/document_types/#{id}", params: { label: 'Alvará de Funcionamento' },
                                            headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['label']).to eq('Alvará de Funcionamento')

      delete "#{base}/document_types/#{id}", headers: admin.create_new_auth_token
      get "#{base}/document_types", headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body.pluck('slug')).not_to include('alvara')
    end
  end

  describe 'document_folder_templates' do
    let(:client_template) { account.crm_document_folder_templates.client_scope.first }

    it 'renomeia e acrescenta pasta na gaveta, gerando o slot da pasta nova' do
      tree = client_template.nodes + [{ 'name' => '06 Orçamentos' }]

      patch "#{base}/document_folder_templates/#{client_template.id}", params: { tree: tree },
                                                                       headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(client_template.reload.nodes.last).to eq('slot' => 'pasta_06_orcamentos', 'name' => '06 Orçamentos')
    end

    it 'não deixa tirar as pastas de que o sistema depende' do
      tree = client_template.nodes.reject { |node| node['slot'] == 'triagem' }

      patch "#{base}/document_folder_templates/#{client_template.id}", params: { tree: tree },
                                                                       headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('triagem')
    end
  end

  describe 'document_forms' do
    it 'cria a partir do modelo da área, edita e publica o link' do
      post "#{base}/document_forms", params: { name: 'Cadastro de inquilino' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      form = response.parsed_body
      expect(form['fields'].pluck('maps_to')).to include('contact_name', 'contact_phone')
      expect(form['public_url']).to match(%r{/f/\w{20}\z})

      fields = form['fields'] + [{ key: 'profissao', label: 'Profissão', type: 'text', required: true }]
      patch "#{base}/document_forms/#{form['id']}", params: { fields: fields }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['fields'].pluck('key')).to include('profissao')
    end

    it 'recusa estrutura inválida com mensagem clara' do
      form = account.crm_document_forms.create!(Crm::Documents::FormTemplates.default_attributes(account))

      patch "#{base}/document_forms/#{form.id}", params: { fields: [{ key: 'x', label: 'X', type: 'text' }] },
                                                 headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to include('telefone ou e-mail')
    end

    it 'gera link personalizado que abre o formulário para aquele cliente' do
      form = account.crm_document_forms.create!(Crm::Documents::FormTemplates.default_attributes(account))
      contact = account.contacts.create!(name: 'Paulo Reis')

      post "#{base}/document_forms/#{form.id}/links", params: { contact_id: contact.id, ttl_days: 3 },
                                                      headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:created)
      get URI(response.parsed_body['url']).path
      expect(response.body).to include('Olá, Paulo')
    end
  end

  describe 'document_submissions' do
    let(:form) { account.crm_document_forms.create!(Crm::Documents::FormTemplates.default_attributes(account)) }
    let!(:submission) do
      Crm::Documents::FormSubmitter.new(
        form: form, consent: '1', answers: { nome: 'Lia Costa', whatsapp: '21998887777', mensagem: 'oi' },
        files: { identidade: [crm_pdf_upload] }
      ).call.submission
    end

    it 'lista os novos envios com as respostas rotuladas' do
      get "#{base}/document_submissions", headers: admin.create_new_auth_token, as: :json

      row = response.parsed_body['payload'].first
      expect(row).to include('protocol' => submission.protocol, 'contact_name' => 'Lia Costa', 'verified' => false)
      expect(row['answers'].pluck('label')).to include('Nome completo', 'WhatsApp com DDD')
    end

    it 'verificar tira a marca de não verificado dos arquivos; spam arquiva os arquivos' do
      patch "#{base}/document_submissions/#{submission.id}", params: { verified: true },
                                                             headers: admin.create_new_auth_token, as: :json
      expect(submission.documents.first.reload.meta).not_to have_key('unverified')

      patch "#{base}/document_submissions/#{submission.id}", params: { review_status: 'spam' },
                                                             headers: admin.create_new_auth_token, as: :json
      expect(submission.reload.review_status).to eq('spam')
      expect(submission.documents.first.reload).to be_archived
    end

    it 'agente não vê envio de contato que não atende' do
      get "#{base}/document_submissions", headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['payload']).to eq([])
    end
  end
end
