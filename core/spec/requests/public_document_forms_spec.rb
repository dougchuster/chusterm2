require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §8.7 — página pública do formulário.
RSpec.describe 'Formulário público de documentos', type: :request do
  let(:account) { create(:account, name: 'Imobiliária Horizonte') }
  let!(:form) do
    crm_documents_enable!(account, preset: 'geral')
    account.crm_document_forms.create!(Crm::Documents::FormTemplates.default_attributes(account))
  end
  let(:verifier) { Rails.application.message_verifier(:crm_document_form) }
  let(:answers) { { nome: 'Carla Dias', whatsapp: '11 91234-5678', mensagem: 'Quero alugar' } }

  def started(seconds_ago = 30)
    verifier.generate((Time.current - seconds_ago).to_i, purpose: :crm_document_form, expires_in: 12.hours)
  end

  def post_form(path: "/f/#{form.public_token}", **params)
    defaults = { answers: answers, consent: '1', started_at: started,
                 files: { identidade: [crm_pdf_upload('rg.pdf')] } }
    post path, params: defaults.merge(params)
  end

  describe 'GET /f/:token' do
    it 'mostra o formulário com os campos e documentos definidos pela conta' do
      get "/f/#{form.public_token}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Imobiliária Horizonte', 'WhatsApp com DDD', 'Documento com foto (RG ou CNH)')
      expect(response.headers['X-Frame-Options']).to eq('DENY')
      expect(response.headers['X-Robots-Tag']).to include('noindex')
    end

    it 'responde 404 para link desconhecido, formulário desativado ou módulo desligado' do
      get '/f/naoexiste'
      expect(response).to have_http_status(:not_found)

      form.update!(active: false)
      get "/f/#{form.public_token}"
      expect(response).to have_http_status(:not_found)

      form.update!(active: true)
      Crm::Documents::Feature.disable!(account)
      get "/f/#{form.public_token}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /f/:token' do
    it 'grava o envio e mostra o protocolo' do
      post_form

      expect(response).to have_http_status(:ok)
      submission = CrmDocumentSubmission.last
      expect(response.body).to include(submission.protocol, 'Recebemos')
      expect(submission.contact.phone_number).to eq('+5511912345678')
      expect(submission.documents.count).to eq(1)
    end

    it 'mostra os erros e mantém o que foi digitado' do
      post_form(answers: answers.merge(whatsapp: '123'), consent: '0')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('Telefone inválido', 'Confirme a autorização', 'Carla Dias')
      expect(CrmDocumentSubmission.count).to eq(0)
    end

    it 'finge sucesso para robô (campo-isca) sem gravar nada' do
      post_form(website: 'http://spam.example')

      expect(response.body).to include('Recebemos')
      expect(CrmDocumentSubmission.count).to eq(0)
    end

    it 'finge sucesso para envio rápido demais sem gravar nada' do
      post_form(started_at: started(1))

      expect(CrmDocumentSubmission.count).to eq(0)
    end

    it 'pede para enviar de novo quando a página expirou' do
      post_form(started_at: 'adulterado')

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('ficou aberta por muito tempo')
    end
  end

  describe 'link personalizado /l/:token' do
    let(:contact) { account.contacts.create!(name: 'Roberto Alves', phone_number: '+5511900001111') }
    let!(:issued) { CrmDocumentFormLink.issue!(form: form, contact: contact) }

    it 'cumprimenta o cliente e não pede identificação' do
      get "/l/#{issued.last}"

      expect(response.body).to include('Olá, Roberto')
      expect(response.body).not_to include('WhatsApp com DDD')
      expect(issued.first.reload.access_count).to eq(1)
    end

    it 'grava o envio verificado no contato do link' do
      post_form(path: "/l/#{issued.last}", answers: { mensagem: 'segue' })

      expect(CrmDocumentSubmission.last).to have_attributes(contact_id: contact.id, verified: true)
    end

    it 'recusa link expirado ou revogado' do
      issued.first.update!(revoked_at: Time.current)

      get "/l/#{issued.last}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
