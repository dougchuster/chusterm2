require 'rails_helper'

# 2.7 do PLANO_17_09.md — dono unico (D3), etapas terminais (D2) e
# titulo contato + categoria (C6).
RSpec.describe CrmDeal do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Funil', slug: 'funil', kind: 'sales') }
  let!(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 1) }
  let!(:won_stage) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Ganho', slug: 'ganho', position: 9, terminal_outcome: 'won')
  end
  let!(:lost_stage) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Perdido', slug: 'perdido', position: 10, terminal_outcome: 'lost')
  end
  let(:contact) { create(:contact, account: account, name: 'Maria Silva') }
  let(:owner) { create(:user, account: account) }
  let(:loss_reason) { account.crm_loss_reasons.create!(name: 'Preço', slug: 'preco') }

  def create_deal(**attrs)
    account.crm_deals.create!(
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      contact: contact,
      title: 'Negócio',
      **attrs
    )
  end

  describe 'etapas terminais (D2)' do
    it 'mark_won! move o card para a etapa terminal won' do
      deal = create_deal
      deal.mark_won!
      expect(deal.reload.crm_pipeline_stage).to eq(won_stage)
    end

    it 'mark_lost! move o card para a etapa terminal lost' do
      deal = create_deal
      deal.mark_lost!(loss_reason_id: loss_reason.id)
      expect(deal.reload.crm_pipeline_stage).to eq(lost_stage)
    end

    it 'reopen! devolve o card para a primeira etapa aberta' do
      deal = create_deal
      deal.mark_lost!(loss_reason_id: loss_reason.id)
      deal.reopen!
      expect(deal.reload.crm_pipeline_stage).to eq(stage)
      expect(deal.status).to eq('open')
    end

    it 'pipeline sem etapa terminal mantém o card no lugar' do
      won_stage.destroy!
      deal = create_deal
      deal.mark_won!
      expect(deal.reload.crm_pipeline_stage).to eq(stage)
    end
  end

  describe 'dono único (D3)' do
    it 'assignee_id legado espelha no owner_id' do
      deal = create_deal(assignee_id: owner.id)
      expect(deal.owner_id).to eq(owner.id)
    end

    it 'owner_id espelha no assignee_id (leitores antigos)' do
      deal = create_deal(owner_id: owner.id)
      expect(deal.assignee_id).to eq(owner.id)
    end

    it 'não sobrescreve um assignee escolhido a dedo (DealOwnerAssigner :never)' do
      paralegal = create(:user, account: account)
      deal = create_deal(assignee_id: paralegal.id)
      deal.update!(owner_id: owner.id)
      expect(deal.reload.assignee_id).to eq(paralegal.id)
      expect(deal.owner_id).to eq(owner.id)
    end

    it 'não toca o crm_owner_id do contato (responsabilidade do assigner/router)' do
      deal = create_deal
      deal.update!(owner_id: owner.id)
      expect(contact.reload.crm_owner_id).to be_nil
    end
  end

  describe 'título contato + categoria (C6)' do
    it 'reconhece o título padrão da triagem' do
      deal = create_deal(title: 'Atendimento #53')
      expect(deal.default_title?).to be(true)
    end

    it 'retitle! usa o nome do contato' do
      deal = create_deal(title: 'Atendimento #53')
      deal.retitle!
      expect(deal.reload.title).to include('Maria Silva')
    end

    it 'não renomeia título personalizado' do
      deal = create_deal(title: 'Contrato do João')
      expect { deal.retitle! }.not_to(change { deal.reload.title })
    end
  end

  describe 'validação do terminal_outcome' do
    it 'rejeita outcome desconhecido' do
      stage = pipeline.crm_pipeline_stages.build(account: account, name: 'X', terminal_outcome: 'foo')
      expect(stage).not_to be_valid
    end
  end

  describe 'dispatch CAPI (B13)' do
    before { Rails.cache.clear }

    it 'enfileira CapiDispatchJob quando há conexão Meta ativa com dataset' do
      account.crm_external_connections.create!(
        provider: 'meta_ads', status: 'active', access_token: 't',
        metadata: { 'capi_dataset_id' => 'ds1' }
      )

      expect { create_deal }.to have_enqueued_job(Marketing::CapiDispatchJob)
    end

    it 'não enfileira quando não há conexão Meta configurada' do
      expect { create_deal }.not_to have_enqueued_job(Marketing::CapiDispatchJob)
    end

    it 'não enfileira quando a conexão Meta está inativa' do
      account.crm_external_connections.create!(
        provider: 'meta_ads', status: 'disconnected', access_token: 't',
        metadata: { 'capi_dataset_id' => 'ds1' }
      )

      expect { create_deal }.not_to have_enqueued_job(Marketing::CapiDispatchJob)
    end

    it 'não enfileira quando a conexão não tem capi_dataset_id' do
      account.crm_external_connections.create!(
        provider: 'meta_ads', status: 'active', access_token: 't', metadata: {}
      )

      expect { create_deal }.not_to have_enqueued_job(Marketing::CapiDispatchJob)
    end

    it 'não enfileira por conexão Meta de outra conta' do
      other = create(:account)
      other.crm_external_connections.create!(
        provider: 'meta_ads', status: 'active', access_token: 't',
        metadata: { 'capi_dataset_id' => 'ds1' }
      )

      expect { create_deal }.not_to have_enqueued_job(Marketing::CapiDispatchJob)
    end
  end
end
