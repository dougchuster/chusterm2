require 'rails_helper'

# F1.7 do PLANO-KANBAN-CRM-2026.md — o board em tempo real.
#
# **Divergencia entre plano e codigo, resolvida com o dono do produto em
# 2026-08-28:** o plano pede um `CrmBoardChannel` novo, mas o transporte ja
# existe e roda (`ActionCableListener#crm_deal_*` -> room `account_{id}` ->
# `RoomChannel#ensure_stream` -> `actionCable.js`). Criar um segundo canal seria
# duplicar o que ja esta em producao. O que faltava era o **conteudo** do
# evento: sem `position` o board nao sabe onde encaixar o card, e sem a etapa
# anterior nao sabe de qual coluna tirar.
RSpec.describe ActionCableListener do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban', slug: 'kanban', kind: 'legal_intake') }
  let(:novo) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0) }
  let(:qualificado) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Qualificado', slug: 'qualificado', position: 1)
  end

  def build_deal(title, stage: novo, **attrs)
    account.crm_deals.create!(
      { crm_pipeline: pipeline, crm_pipeline_stage: stage, title: title }.merge(attrs)
    )
  end

  describe 'CrmDeal#push_event_data' do
    it 'carries the position, so the other session can place the card' do
      deal = build_deal('Com posicao', position: 1500)

      expect(deal.push_event_data[:position]).to eq(1500)
    end

    it 'carries when the deal entered the stage, for the rotting signal' do
      entrou = 3.days.ago
      deal = build_deal('Parado', stage_entered_at: entrou)

      expect(deal.push_event_data[:stage_entered_at]).to be_within(1.second).of(entrou)
    end

    it 'falls back to the creation date for a deal that never moved' do
      deal = build_deal('Novo em folha', created_at: 2.days.ago)

      expect(deal.push_event_data[:stage_entered_at]).to be_within(1.second).of(deal.created_at)
    end

    it 'keeps carrying what the board already used' do
      deal = build_deal('Completo', position: 1000)

      expect(deal.push_event_data.keys).to include(
        :id, :account_id, :title, :status, :crm_pipeline_id, :crm_pipeline_stage_id, :updated_at
      )
    end
  end

  describe 'the stage the card came from' do
    it 'reports the previous stage when the deal moved' do
      deal = build_deal('Movido')

      expect(Rails.configuration.dispatcher).to receive(:dispatch) do |event, _time, payload|
        next unless event == Events::Types::CRM_DEAL_UPDATED

        expect(payload[:previous_stage_id]).to eq(novo.id)
        expect(payload[:deal].crm_pipeline_stage_id).to eq(qualificado.id)
      end.at_least(:once)

      deal.update!(crm_pipeline_stage_id: qualificado.id)
    end

    it 'reports no previous stage when only the position changed' do
      deal = build_deal('Reordenado', position: 1000)

      expect(Rails.configuration.dispatcher).to receive(:dispatch) do |event, _time, payload|
        next unless event == Events::Types::CRM_DEAL_UPDATED

        expect(payload[:previous_stage_id]).to be_nil
      end.at_least(:once)

      deal.update!(position: 2000)
    end
  end

  describe 'what reaches the other session' do
    let(:listener) { described_class.instance }

    def broadcast_payload_for(_deal, event_name, extra = {})
      payload = nil
      allow(ActionCableBroadcastJob).to receive(:perform_later) do |_tokens, name, data|
        payload = data if name == event_name
      end
      yield(listener, extra)
      payload
    end

    it 'broadcasts the enriched deal to the account room on update' do
      deal = build_deal('Movido', position: 1000)
      event = Events::Base.new(
        Events::Types::CRM_DEAL_UPDATED, Time.zone.now,
        deal: deal, changed_attributes: ['position'], previous_stage_id: novo.id
      )

      payload = broadcast_payload_for(deal, Events::Types::CRM_DEAL_UPDATED) do |l, _|
        l.crm_deal_updated(event)
      end

      expect(payload[:position]).to eq(1000)
      expect(payload[:previous_stage_id]).to eq(novo.id)
      expect(payload[:account_id]).to eq(account.id)
    end

    it 'broadcasts to the account room, which every agent of the account already streams' do
      deal = build_deal('Novo', position: 1000)
      event = Events::Base.new(Events::Types::CRM_DEAL_CREATED, Time.zone.now, deal: deal)

      tokens = nil
      allow(ActionCableBroadcastJob).to receive(:perform_later) { |t, _, _| tokens = t }
      listener.crm_deal_created(event)

      expect(tokens).to eq(["account_#{account.id}"])
    end
  end
end
