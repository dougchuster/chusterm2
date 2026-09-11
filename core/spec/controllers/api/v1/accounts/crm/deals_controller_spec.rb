require 'rails_helper'

RSpec.describe 'CRM Deals API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Pipeline Jurídico', position: 1, is_default: true) }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo atendimento', position: 1) }
  let(:qualified_stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', position: 2) }

  def create_deal!(title:, stage: self.stage, **attrs)
    CrmDeal.create!(
      {
        account: account,
        crm_pipeline: pipeline,
        crm_pipeline_stage: stage,
        title: title
      }.merge(attrs)
    )
  end

  describe 'POST /api/v1/accounts/:account_id/crm/deals' do
    it 'creates a lead with a simple contact payload' do
      post "/api/v1/accounts/#{account.id}/crm/deals",
           params: {
             title: 'Revisão de benefício',
             crm_pipeline_id: pipeline.id,
             crm_pipeline_stage_id: stage.id,
             contact_name: 'Maria Silva',
             contact_phone_number: '61999999999',
             contact_email: 'maria@example.com',
             source: 'indicacao',
             source_detail: 'Cliente antigo'
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      deal = account.crm_deals.last
      expect(deal.title).to eq('Revisão de benefício')
      expect(deal.source_detail).to eq('Cliente antigo')
      expect(deal.contact.name).to eq('Maria Silva')
      expect(deal.contact.phone_number).to eq('+5561999999999')
      expect(deal.contact.email).to eq('maria@example.com')
      expect(deal.contact).to be_lead
    end

    it 'accepts a current-account conversation primary key even when another display id collides' do
      target = create(:conversation, account: account)
      decoy = create(:conversation, account: account)
      target.update_column(:display_id, target.id + 100_000) # rubocop:disable Rails/SkipsModelValidations
      decoy.update_column(:display_id, target.id) # rubocop:disable Rails/SkipsModelValidations

      post "/api/v1/accounts/#{account.id}/crm/deals",
           params: {
             title: 'Contrato por PK',
             crm_pipeline_id: pipeline.id,
             crm_pipeline_stage_id: stage.id,
             conversation_id: target.id
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_deals.last.conversation).to eq(target)
      expect(account.crm_deals.last.conversation).not_to eq(decoy)
    end

    it 'rejects another account conversation primary key without creating a link' do
      foreign_conversation = create(:conversation, account: create(:account))

      expect do
        post "/api/v1/accounts/#{account.id}/crm/deals",
             params: {
               title: 'Tentativa entre contas',
               crm_pipeline_id: pipeline.id,
               crm_pipeline_stage_id: stage.id,
               conversation_id: foreign_conversation.id
             },
             headers: headers,
             as: :json
      end.not_to change(account.crm_deals, :count)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq('error' => 'Conversation not found')
    end

    it 'does not interpret a matching display id when its numeric value is a foreign primary key' do
      foreign_conversation = create(:conversation, account: create(:account))
      local_conversation = create(:conversation, account: account)
      local_conversation.update_column(:display_id, foreign_conversation.id) # rubocop:disable Rails/SkipsModelValidations

      expect do
        post "/api/v1/accounts/#{account.id}/crm/deals",
             params: {
               title: 'Display id não é FK',
               crm_pipeline_id: pipeline.id,
               crm_pipeline_stage_id: stage.id,
               conversation_id: local_conversation.display_id
             },
             headers: headers,
             as: :json
      end.not_to change(account.crm_deals, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects foreign pipeline, stage, contact, inbox, team and user references' do
      foreign_account = create(:account)
      foreign_pipeline = CrmPipeline.create!(account: foreign_account, name: 'Pipeline externo', position: 1)
      foreign_stage = CrmPipelineStage.create!(
        account: foreign_account,
        crm_pipeline: foreign_pipeline,
        name: 'Etapa externa',
        position: 1
      )
      foreign_user = create(:user, account: foreign_account)
      foreign_references = {
        crm_pipeline_id: foreign_pipeline.id,
        crm_pipeline_stage_id: foreign_stage.id,
        contact_id: create(:contact, account: foreign_account).id,
        inbox_id: create(:inbox, account: foreign_account).id,
        team_id: create(:team, account: foreign_account).id,
        owner_id: foreign_user.id,
        assignee_id: foreign_user.id
      }

      foreign_references.each do |attribute, foreign_id|
        request_params = {
          title: "Tentativa #{attribute}",
          crm_pipeline_id: pipeline.id,
          crm_pipeline_stage_id: stage.id
        }.merge(attribute => foreign_id)

        expect do
          post "/api/v1/accounts/#{account.id}/crm/deals",
               params: request_params,
               headers: headers,
               as: :json
        end.not_to change(account.crm_deals, :count)

        expect(response).to have_http_status(:not_found)
      end
    end

    it 'strips the reserved captain_triage key from custom_fields' do
      post "/api/v1/accounts/#{account.id}/crm/deals",
           params: {
             title: 'Tentativa de inflar score',
             crm_pipeline_id: pipeline.id,
             crm_pipeline_stage_id: stage.id,
             custom_fields: {
               'captain_triage' => { 'economic_potential' => 'high' },
               'origin_note' => 'indicação'
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      custom_fields = account.crm_deals.last.custom_fields
      expect(custom_fields).not_to have_key('captain_triage')
      expect(custom_fields['origin_note']).to eq('indicação')
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/deals/:id' do
    it 'rejects a foreign conversation and preserves the existing link without leaking its messages' do
      local_conversation = create(:conversation, account: account)
      foreign_conversation = create(:conversation, account: create(:account))
      secret = 'FOREIGN-CONVERSATION-SECRET'
      create(
        :message,
        account: foreign_conversation.account,
        conversation: foreign_conversation,
        inbox: foreign_conversation.inbox,
        content: secret
      )
      deal = create_deal!(title: 'Lead protegido', conversation: local_conversation)

      patch "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}",
            params: { conversation_id: foreign_conversation.id, title: 'Alteração bloqueada' },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(deal.reload).to have_attributes(
        conversation_id: local_conversation.id,
        title: 'Lead protegido'
      )

      get "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}", headers: headers, as: :json
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(secret)
    end

    it 'strips the reserved captain_triage key from custom_fields' do
      deal = create_deal!(title: 'Lead com triagem', custom_fields: { 'existing' => 'value' })

      patch "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}",
            params: {
              custom_fields: {
                'captain_triage' => { 'economic_potential' => 'high', 'data_quality' => 'sufficient' },
                'notes' => 'cliente pediu retorno'
              }
            },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:success)
      custom_fields = deal.reload.custom_fields
      expect(custom_fields).not_to have_key('captain_triage')
      expect(custom_fields['notes']).to eq('cliente pediu retorno')
    end
  end

  describe 'GET /api/v1/accounts/:account_id/crm/deals' do
    it 'returns the internal and display conversation ids explicitly' do
      conversation = create(:conversation, account: account)
      conversation.update_column(:display_id, conversation.id + 100_000) # rubocop:disable Rails/SkipsModelValidations
      create_deal!(title: 'Contrato de identificadores', conversation: conversation)

      get "/api/v1/accounts/#{account.id}/crm/deals",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      deal = response.parsed_body['data'].first
      expect(deal).to include(
        'conversation_id' => conversation.id,
        'conversation_display_id' => conversation.display_id
      )
    end

    it 'returns contact avatar fields for Kanban cards' do
      contact = create(
        :contact,
        account: account,
        name: 'Ricardo Reichert',
        additional_attributes: { 'avatar_url' => 'https://cdn.test/ricardo.jpg' }
      )
      create_deal!(title: 'Atendimento #62', contact: contact)

      get "/api/v1/accounts/#{account.id}/crm/deals",
          params: { pipeline_id: pipeline.id },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      deal = response.parsed_body['data'].first
      expect(deal).to include(
        'contact_name' => 'Ricardo Reichert',
        'contact_thumbnail' => 'https://cdn.test/ricardo.jpg',
        'contact_avatar_url' => 'https://cdn.test/ricardo.jpg'
      )
    end
  end

  describe 'deal outcome actions' do
    let(:deal) { create_deal!(title: 'Negócio em negociação') }
    let(:loss_reason) do
      CrmLossReason.create!(
        account: account,
        name: 'Sem retorno do cliente',
        slug: 'sem_retorno_do_cliente'
      )
    end

    it 'marks a deal as lost with its reason and note' do
      post "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/mark_lost",
           params: { loss_reason_id: loss_reason.id, note: 'Tentativas encerradas.' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'status' => 'lost',
        'crm_loss_reason_id' => loss_reason.id,
        'lost_reason_note' => 'Tentativas encerradas.'
      )
      expect(response.parsed_body['loss_reason']).to include(
        'id' => loss_reason.id,
        'name' => 'Sem retorno do cliente'
      )
      expect(deal.reload.closed_at).to be_present
    end

    it 'clears the previous loss when the deal is reopened' do
      deal.mark_lost!(
        loss_reason_id: loss_reason.id,
        note: 'Tentativas encerradas.',
        actor: admin
      )

      post "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/reopen",
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'status' => 'open',
        'crm_loss_reason_id' => nil,
        'lost_reason_note' => nil,
        'closed_at' => nil
      )
    end

    it 'marks an open deal as won' do
      post "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/mark_won",
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['status']).to eq('won')
      expect(deal.reload.closed_at).to be_present
    end

    it 'requires an active loss reason from the current account' do
      post "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/mark_lost",
           params: { note: 'Sem motivo selecionado.' },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Selecione um motivo de perda válido.')
      expect(deal.reload.status).to eq('open')
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/deals/bulk_action' do
    it 'permanently deletes selected leads' do
      first_deal = create_deal!(title: 'Lead 1')
      second_deal = create_deal!(title: 'Lead 2')
      kept_deal = create_deal!(title: 'Lead mantido')

      post "/api/v1/accounts/#{account.id}/crm/deals/bulk_action",
           params: {
             bulk_action: 'destroy',
             deal_ids: [first_deal.id, second_deal.id]
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('requested' => 2, 'processed' => 2)
      expect(account.crm_deals.where(id: [first_deal.id, second_deal.id])).to be_empty
      expect(account.crm_deals.exists?(kept_deal.id)).to be(true)
    end

    it 'deletes every lead matching the submitted filters' do
      matching_deal = create_deal!(title: 'Lead previdenciário', legal_area: 'previdenciario', urgency_level: 'alta')
      other_area_deal = create_deal!(title: 'Lead trabalhista', legal_area: 'trabalhista', urgency_level: 'alta')
      other_stage_deal = create_deal!(
        title: 'Lead qualificado',
        stage: qualified_stage,
        legal_area: 'previdenciario',
        urgency_level: 'alta'
      )

      post "/api/v1/accounts/#{account.id}/crm/deals/bulk_action",
           params: {
             bulk_action: 'destroy',
             select_all: true,
             filters: {
               pipeline_id: pipeline.id,
               stage_id: stage.id,
               legal_area: 'previdenciario',
               urgency: 'alta'
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('requested' => 1, 'processed' => 1)
      expect(account.crm_deals.exists?(matching_deal.id)).to be(false)
      expect(account.crm_deals.exists?(other_area_deal.id)).to be(true)
      expect(account.crm_deals.exists?(other_stage_deal.id)).to be(true)
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/crm/deals/purge_orphans' do
    it 'purges a legacy cross-account reference but preserves current-account links' do
      local_conversation = create(:conversation, account: account)
      foreign_conversation = create(:conversation, account: create(:account))
      valid_deal = create_deal!(title: 'Vínculo válido', conversation: local_conversation)
      corrupt_deal = create_deal!(title: 'Vínculo legado inválido')
      corrupt_deal.update_column(:conversation_id, foreign_conversation.id) # rubocop:disable Rails/SkipsModelValidations

      delete "/api/v1/accounts/#{account.id}/crm/deals/purge_orphans",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['purged']).to eq(1)
      expect(account.crm_deals.exists?(corrupt_deal.id)).to be(false)
      expect(account.crm_deals.exists?(valid_deal.id)).to be(true)
    end
  end

  # F1.3 do PLANO-KANBAN-CRM-2026.md
  describe 'POST/PATCH /api/v1/accounts/:account_id/crm/deals/:id/move' do
    def move!(deal, params, verb: :post)
      send(
        verb,
        "/api/v1/accounts/#{account.id}/crm/deals/#{deal.id}/move",
        params: params, headers: headers, as: :json
      )
    end

    it 'moves the deal and returns the position the server chose' do
      deal = create_deal!(title: 'Movido')

      move!(deal, { stage_id: qualified_stage.id })

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['crm_pipeline_stage_id']).to eq(qualified_stage.id)
      expect(response.parsed_body['position']).to be_present
      expect(deal.reload.position).to be_present
    end

    it 'accepts PATCH as well as POST' do
      deal = create_deal!(title: 'Movido')

      move!(deal, { stage_id: qualified_stage.id }, verb: :patch)

      expect(response).to have_http_status(:success)
      expect(deal.reload.crm_pipeline_stage_id).to eq(qualified_stage.id)
    end

    it 'places the deal between the neighbours the client reports' do
      topo = create_deal!(title: 'Topo', stage: qualified_stage, position: 1000)
      fundo = create_deal!(title: 'Fundo', stage: qualified_stage, position: 2000)
      deal = create_deal!(title: 'Movido')

      move!(deal, { stage_id: qualified_stage.id, after_id: topo.id, before_id: fundo.id })

      expect(response).to have_http_status(:success)
      expect(deal.reload.position).to eq(1500)
    end

    it 'reorders inside the same column without changing the stage' do
      topo = create_deal!(title: 'Topo', position: 1000)
      fundo = create_deal!(title: 'Fundo', position: 2000)
      deal = create_deal!(title: 'Movido', position: 3000)

      move!(deal, { stage_id: stage.id, after_id: topo.id, before_id: fundo.id })

      expect(response).to have_http_status(:success)
      expect(deal.reload.position).to eq(1500)
      expect(deal.crm_pipeline_stage_id).to eq(stage.id)
    end

    it 'refuses neighbours reported in the wrong order' do
      topo = create_deal!(title: 'Topo', stage: qualified_stage, position: 1000)
      fundo = create_deal!(title: 'Fundo', stage: qualified_stage, position: 2000)
      deal = create_deal!(title: 'Movido')

      move!(deal, { stage_id: qualified_stage.id, after_id: fundo.id, before_id: topo.id })

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'still answers 404 for a stage that does not belong to the account' do
      deal = create_deal!(title: 'Movido')

      move!(deal, { stage_id: 0 })

      expect(response).to have_http_status(:not_found)
    end
  end

  # F1.4 do PLANO-KANBAN-CRM-2026.md — o board para de filtrar em JavaScript.
  describe 'GET /api/v1/accounts/:account_id/crm/deals com filtros da F1.4' do
    def index!(params)
      get "/api/v1/accounts/#{account.id}/crm/deals", params: params, headers: headers, as: :json
      response.parsed_body['data'].pluck('title').sort
    end

    it 'accepts a list of stages in the query string' do
      create_deal!(title: 'No novo')
      create_deal!(title: 'No qualificado', stage: qualified_stage)

      expect(index!({ stage_id: [qualified_stage.id] })).to eq(['No qualificado'])
    end

    it 'filters by value range' do
      create_deal!(title: 'Barato', value_estimate_cents: 100_000)
      create_deal!(title: 'Caro', value_estimate_cents: 5_000_000)

      expect(index!({ value_min: 1_000_000 })).to eq(['Caro'])
    end

    it 'filters the deals with no next action, which is the alarming state of the board' do
      com = create_deal!(title: 'Com proxima acao')
      com.crm_activities.create!(account: account, kind: 'follow_up', title: 'Ligar')
      create_deal!(title: 'Sem proxima acao')

      expect(index!({ has_pending_activity: false })).to eq(['Sem proxima acao'])
    end

    it 'searches the legal area through q' do
      create_deal!(title: 'Um', legal_area: 'trabalhista')
      create_deal!(title: 'Dois', legal_area: 'civel')

      expect(index!({ q: 'trabalhista' })).to eq(['Um'])
    end

    it 'reports the filtered total in meta, not the pipeline total' do
      create_deal!(title: 'Barato', value_estimate_cents: 100_000)
      create_deal!(title: 'Caro', value_estimate_cents: 5_000_000)

      get "/api/v1/accounts/#{account.id}/crm/deals",
          params: { value_min: 1_000_000 }, headers: headers, as: :json

      expect(response.parsed_body['meta']['total']).to eq(1)
    end
  end

  # Achado HIGH da revisao da F1.4: o controller mantinha a propria lista de
  # chaves que aceitam array, e ela divergiu das que o servico aceita. Filtrar o
  # board por duas dispositions e clicar em Exportar descartava a chave inteira
  # em silencio — o CSV saía com negocios que o atendente tinha excluido da tela.
  describe 'POST /api/v1/accounts/:account_id/crm/deals/export' do
    it 'hands the export job the same list filters the board used' do
      allow(Crm::DealsExportJob).to receive(:perform_later)

      post "/api/v1/accounts/#{account.id}/crm/deals/export",
           params: { disposition_reason: %w[spam duplicated], stage_id: [stage.id] },
           headers: headers, as: :json

      expect(response).to have_http_status(:accepted)
      expect(Crm::DealsExportJob).to have_received(:perform_later) do |_account_id, _user_id, filters|
        expect(filters['disposition_reason']).to eq(%w[spam duplicated])
        expect(filters['stage_id']).to eq([stage.id])
      end
    end

    it 'does not smuggle routing params into the filters' do
      allow(Crm::DealsExportJob).to receive(:perform_later)

      post "/api/v1/accounts/#{account.id}/crm/deals/export",
           params: { q: 'revisao' }, headers: headers, as: :json

      expect(Crm::DealsExportJob).to have_received(:perform_later) do |_account_id, _user_id, filters|
        expect(filters.keys).to contain_exactly('q')
      end
    end
  end
end
