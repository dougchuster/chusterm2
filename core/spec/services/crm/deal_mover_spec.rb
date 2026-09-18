require 'rails_helper'

# F1.3 do PLANO-KANBAN-CRM-2026.md — mover passa a significar duas coisas:
# trocar de etapa (como sempre) e reordenar dentro da coluna (novo). As duas
# gravam `position`; so a primeira dispara automacao.
RSpec.describe Crm::DealMover do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban Teste', slug: 'kanban-teste', kind: 'legal_intake') }
  let(:origem) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
  end
  let(:destino) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Qualificacao', slug: 'qualificacao', position: 1)
  end

  def build_deal(title, stage:, **attrs)
    account.crm_deals.create!(
      { crm_pipeline: pipeline, crm_pipeline_stage: stage, title: title }.merge(attrs)
    )
  end

  describe 'moving to another stage' do
    it 'writes a position in the destination column' do
      build_deal('Ja estava la', stage: destino, position: 1000)
      deal = build_deal('Movido', stage: origem, position: 1000)

      described_class.new(deal: deal, stage_id: destino.id).perform

      expect(deal.reload.crm_pipeline_stage_id).to eq(destino.id)
      expect(deal.position).to eq(0)
    end

    it 'honours the neighbours the client reports' do
      topo = build_deal('Topo', stage: destino, position: 1000)
      fundo = build_deal('Fundo', stage: destino, position: 2000)
      deal = build_deal('Movido', stage: origem, position: 1000)

      described_class.new(deal: deal, stage_id: destino.id, after_id: topo.id, before_id: fundo.id).perform

      expect(deal.reload.position).to eq(1500)
    end

    it 'stamps when the deal entered the destination stage' do
      deal = build_deal('Movido', stage: origem, position: 1000, stage_entered_at: 10.days.ago)

      described_class.new(deal: deal, stage_id: destino.id).perform

      expect(deal.reload.stage_entered_at).to be_within(5.seconds).of(Time.current)
    end

    it 'still audits the stage change' do
      deal = build_deal('Movido', stage: origem, position: 1000)

      described_class.new(deal: deal, stage_id: destino.id).perform

      expect(account.crm_audit_events.where(action: 'deal_stage_changed').count).to eq(1)
    end

    it 'still runs the stage automation' do
      deal = build_deal('Movido', stage: origem, position: 1000)
      automation = instance_double(Crm::StageAutomation, perform: true)
      allow(Crm::StageAutomation).to receive(:new).and_return(automation)

      described_class.new(deal: deal, stage_id: destino.id).perform

      expect(automation).to have_received(:perform)
    end
  end

  # Arrastar um card tres posicoes para cima nao e "entrar na etapa". Disparar
  # `stage_entered` a cada reordenacao mandaria mensagem para o cliente, criaria
  # atividade e trocaria o dono — de novo, a cada arrasto.
  describe 'reordering inside the same stage' do
    it 'writes the new position' do
      topo = build_deal('Topo', stage: origem, position: 1000)
      fundo = build_deal('Fundo', stage: origem, position: 2000)
      deal = build_deal('Movido', stage: origem, position: 3000)

      described_class.new(deal: deal, stage_id: origem.id, after_id: topo.id, before_id: fundo.id).perform

      expect(deal.reload.position).to eq(1500)
      expect(deal.crm_pipeline_stage_id).to eq(origem.id)
    end

    it 'does not run the stage automation' do
      deal = build_deal('Movido', stage: origem, position: 1000)

      expect(Crm::StageAutomation).not_to receive(:new)

      described_class.new(deal: deal, stage_id: origem.id).perform
    end

    it 'does not audit a stage change that did not happen' do
      deal = build_deal('Movido', stage: origem, position: 1000)

      described_class.new(deal: deal, stage_id: origem.id).perform

      expect(account.crm_audit_events.where(action: 'deal_stage_changed')).to be_empty
    end

    it 'does not block on required fields the deal is already sitting with' do
      origem.update!(required_fields: ['legal_area'])
      deal = build_deal('Movido', stage: origem, position: 1000)

      expect { described_class.new(deal: deal, stage_id: origem.id).perform }.not_to raise_error
    end

    # Arrastar um card tres posicoes para cima nao reinicia o relogio: ele
    # continua parado ha tres dias, e o rotting da F2.5 tem que continuar
    # gritando.
    it 'does not restart the stage clock when only reordering' do
      entrou_em = 3.days.ago
      deal = build_deal('Movido', stage: origem, position: 1000, stage_entered_at: entrou_em)

      described_class.new(deal: deal, stage_id: origem.id).perform

      expect(deal.reload.stage_entered_at).to be_within(1.second).of(entrou_em)
    end

    it 'does not treat the moved deal as its own neighbour' do
      deal = build_deal('Sozinho na coluna', stage: origem, position: 1000)

      described_class.new(deal: deal, stage_id: origem.id).perform

      expect(deal.reload.position).to eq(1000)
    end
  end

  # Sem o lock, dois atendentes arrastando para a mesma coluna leem os mesmos
  # vizinhos e gravam o mesmo ponto medio. Como `position` nao tem indice unico,
  # a colisao passaria em silencio.
  describe 'two attendants dragging into the same column' do
    it 'serialises the write behind the destination column lock' do
      deal = build_deal('Movido', stage: origem, position: 1000)

      expect(Crm::StageAdvisoryLock).to receive(:lock!).with(destino.id).and_call_original

      described_class.new(deal: deal, stage_id: destino.id).perform
    end

    it 'shares the lock key with the F1.2 backfill, which also renumbers columns' do
      expect(Crm::StageAdvisoryLock.key_for(destino.id))
        .to eq(Crm::BackfillDealPositionsJob.new.advisory_lock_key(destino.id))
    end
  end

  # Achado HIGH da revisao: "mover em massa" nao informa vizinhos, entao cada
  # negocio cai no topo da coluna de destino. Enquanto o topo bisseccionava, 100
  # negocios disparavam 4 rebalanceamentos de coluna inteira dentro de uma
  # requisicao HTTP.
  describe 'bulk move into the same stage' do
    it 'keeps a full gap between every card, without triggering a rebalance' do
      veterano = build_deal('Ja estava la', stage: destino, position: 1000)
      movidos = Array.new(40) { |i| build_deal("Bulk #{i}", stage: origem, position: (i + 1) * 1000) }

      movidos.each { |deal| described_class.new(deal: deal, stage_id: destino.id).perform }

      posicoes = destino.crm_deals.order(:position).pluck(:position)
      # Rebalanceamento renumeraria a coluna inteira: o veterano sairia de 1000.
      expect(veterano.reload.position).to eq(1000)
      expect(posicoes.uniq.size).to eq(41)
      expect(posicoes.each_cons(2).map { |a, b| b - a }).to all(eq(1000))
    end
  end

  describe 'validation' do
    it 'still refuses a stage from another pipeline' do
      other_pipeline = account.crm_pipelines.create!(name: 'Outro', slug: 'outro', kind: 'legal_intake')
      stranger = other_pipeline.crm_pipeline_stages.create!(
        account: account, name: 'Novo', slug: 'novo-outro', position: 0
      )
      deal = build_deal('Movido', stage: origem, position: 1000)

      expect { described_class.new(deal: deal, stage_id: stranger.id).perform }
        .to raise_error(ArgumentError, /pipeline/i)
    end

    it 'still refuses a stage change with required fields missing' do
      destino.update!(required_fields: ['legal_area'])
      deal = build_deal('Movido', stage: origem, position: 1000)

      expect { described_class.new(deal: deal, stage_id: destino.id).perform }
        .to raise_error(ArgumentError, /obrigatorios/i)
    end
  end

  # Check-up 2026-09-18: arrastar para "Ganho"/"Perdido" deixava o negocio open.
  describe 'moving into and out of terminal stages (D2)' do
    let(:ganho) do
      pipeline.crm_pipeline_stages.create!(account: account, name: 'Ganho', slug: 'ganho', position: 8, terminal_outcome: 'won')
    end
    let(:perdido) do
      pipeline.crm_pipeline_stages.create!(account: account, name: 'Perdido', slug: 'perdido', position: 9, terminal_outcome: 'lost')
    end

    it 'closes the deal as won when dropped on the won column' do
      deal = build_deal('A', stage: origem)

      described_class.new(deal: deal, stage_id: ganho.id).perform

      expect(deal.reload).to have_attributes(status: 'won', crm_pipeline_stage_id: ganho.id)
      expect(deal.closed_at).to be_present
    end

    it 'closes the deal as lost (reason can be filled later) when dropped on the lost column' do
      deal = build_deal('B', stage: origem)

      described_class.new(deal: deal, stage_id: perdido.id).perform

      expect(deal.reload.status).to eq('lost')
    end

    it 'reopens the deal when dragged back to a regular column' do
      ganho
      deal = build_deal('C', stage: origem)
      deal.mark_won!

      described_class.new(deal: deal, stage_id: destino.id).perform

      expect(deal.reload).to have_attributes(status: 'open', closed_at: nil, crm_pipeline_stage_id: destino.id)
    end

    it 'does not double-write when mark_won! already set the status' do
      ganho
      deal = build_deal('D', stage: origem)

      expect { deal.mark_won! }.to change { CrmAuditEvent.where(action: 'deal_marked_won').count }.by(1)
      expect(deal.reload.crm_pipeline_stage_id).to eq(ganho.id)
    end
  end
end
