require 'rails_helper'

# F1.2 do PLANO-KANBAN-CRM-2026.md — backfill de `crm_deals.position`.
#
# A coluna nasceu NULL na F1.1. Este job preenche em lotes, por etapa, com
# ROW_NUMBER() * 1000 ordenado por created_at DESC — exatamente a ordem que o
# board ja mostra hoje (`DealsController#index` faz `order(created_at: :desc)`).
#
# Invariante central: **o backfill nao pode mudar o que o atendente ve.** Deal
# ja posicionado a mao nao se mexe; deal sem posicao (que o board ja joga para o
# fim via NULLS LAST) entra abaixo dos posicionados.
RSpec.describe Crm::BackfillDealPositionsJob do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban Teste', slug: 'kanban-teste', kind: 'legal_intake') }
  let(:stage) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
  end

  # A etapa ja carrega conta e pipeline, entao ela sozinha define onde o
  # negocio nasce ? inclusive quando o teste precisa de outra conta.
  def build_deal(title, created_at:, stage: self.stage, position: nil)
    stage.account.crm_deals.create!(
      crm_pipeline: stage.crm_pipeline,
      crm_pipeline_stage: stage,
      title: title,
      position: position,
      created_at: created_at
    )
  end

  def positions_by_title(scope = account.crm_deals)
    scope.pluck(:title, :position).to_h
  end

  describe 'numbering inside a stage' do
    it 'numbers deals newest-first in steps of 1000' do
      oldest = build_deal('Mais antigo', created_at: 3.days.ago)
      middle = build_deal('Do meio', created_at: 2.days.ago)
      newest = build_deal('Mais novo', created_at: 1.day.ago)

      described_class.perform_now

      expect(newest.reload.position).to eq(1000)
      expect(middle.reload.position).to eq(2000)
      expect(oldest.reload.position).to eq(3000)
    end

    it 'preserves the order the board already renders (created_at desc)' do
      build_deal('Mais antigo', created_at: 3.days.ago)
      build_deal('Do meio', created_at: 2.days.ago)
      build_deal('Mais novo', created_at: 1.day.ago)

      before_backfill = account.crm_deals.order(created_at: :desc).pluck(:title)
      described_class.perform_now
      after_backfill = account.crm_deals.order(:position).pluck(:title)

      expect(after_backfill).to eq(before_backfill)
    end

    it 'leaves a gap wide enough for the fractional inserts of F1.3' do
      build_deal('A', created_at: 2.days.ago)
      build_deal('B', created_at: 1.day.ago)

      described_class.perform_now

      positions = account.crm_deals.order(:position).pluck(:position)
      expect(positions.each_cons(2).map { |a, b| b - a }).to all(eq(1000))
    end

    it 'restarts the numbering in every stage' do
      other_stage = pipeline.crm_pipeline_stages.create!(
        account: account, name: 'Qualificacao', slug: 'qualificacao', position: 1
      )
      build_deal('Coluna A', created_at: 1.day.ago)
      build_deal('Coluna B', created_at: 1.day.ago, stage: other_stage)

      described_class.perform_now

      expect(positions_by_title).to eq('Coluna A' => 1000, 'Coluna B' => 1000)
    end

    it 'breaks created_at ties deterministically instead of leaving duplicate positions' do
      moment = 1.day.ago
      build_deal('Empate 1', created_at: moment)
      build_deal('Empate 2', created_at: moment)
      build_deal('Empate 3', created_at: moment)

      described_class.perform_now

      positions = account.crm_deals.pluck(:position)
      expect(positions.uniq.size).to eq(3)
    end
  end

  describe 'idempotency' do
    it 'produces the same positions when run twice' do
      build_deal('A', created_at: 2.days.ago)
      build_deal('B', created_at: 1.day.ago)

      described_class.perform_now
      first_run = positions_by_title
      described_class.perform_now

      expect(positions_by_title).to eq(first_run)
    end

    it 'reports that a second run had nothing to do' do
      build_deal('A', created_at: 1.day.ago)

      described_class.perform_now
      expect(described_class.perform_now).to eq(0)
    end

    it 'never moves a deal that already has a position' do
      curated = build_deal('Escolhido a mao', created_at: 1.day.ago, position: 7)

      described_class.perform_now

      expect(curated.reload.position).to eq(7)
    end

    it 'appends unpositioned deals below the positioned ones, where NULLS LAST already puts them' do
      curated = build_deal('Curado', created_at: 5.days.ago, position: 1000)
      newer = build_deal('Novo sem posicao', created_at: 1.day.ago)

      described_class.perform_now

      expect(curated.reload.position).to eq(1000)
      expect(newer.reload.position).to eq(2000)
      expect(account.crm_deals.order(:position).pluck(:title)).to eq(['Curado', 'Novo sem posicao'])
    end
  end

  describe 'batching' do
    it 'completes a stage that needs more than one batch, with no gaps or repeats' do
      5.times { |i| build_deal("Deal #{i}", created_at: (5 - i).days.ago) }

      described_class.perform_now(batch_size: 2)

      expect(account.crm_deals.order(:position).pluck(:position))
        .to eq([1000, 2000, 3000, 4000, 5000].map { |n| BigDecimal(n) })
    end

    it 'resumes correctly when an earlier batch already ran' do
      5.times { |i| build_deal("Deal #{i}", created_at: (5 - i).days.ago) }

      described_class.perform_now(batch_size: 2)
      described_class.perform_now(batch_size: 2)

      titles = account.crm_deals.order(:position).pluck(:title)
      expect(titles).to eq(account.crm_deals.order(created_at: :desc).pluck(:title))
    end

    it 'returns how many deals it positioned' do
      3.times { |i| build_deal("Deal #{i}", created_at: (3 - i).days.ago) }

      expect(described_class.perform_now).to eq(3)
    end
  end

  describe 'scoping' do
    let(:other_account) { create(:account) }
    let(:other_pipeline) do
      other_account.crm_pipelines.create!(name: 'Outro', slug: 'outro', kind: 'legal_intake')
    end
    let(:other_stage) do
      other_pipeline.crm_pipeline_stages.create!(account: other_account, name: 'Novo', slug: 'novo', position: 0)
    end

    it 'positions every account when no account is given' do
      mine = build_deal('Meu', created_at: 1.day.ago)
      theirs = build_deal('Deles', created_at: 1.day.ago, stage: other_stage)

      described_class.perform_now

      expect(mine.reload.position).to eq(1000)
      expect(theirs.reload.position).to eq(1000)
    end

    it 'touches only the requested account when one is given' do
      mine = build_deal('Meu', created_at: 1.day.ago)
      theirs = build_deal('Deles', created_at: 1.day.ago, stage: other_stage)

      described_class.perform_now(account_id: account.id)

      expect(mine.reload.position).to eq(1000)
      expect(theirs.reload.position).to be_nil
    end
  end

  # A razao de o UPDATE ser SQL cru: `update_all`/`save` passariam pelo
  # `after_update_commit :dispatch_updated_event` do CrmDeal e o backfill viraria
  # uma enxurrada de eventos no barramento do board.
  describe 'staying out of the realtime bus' do
    it 'does not dispatch a deal-updated event for the deals it positions' do
      build_deal('A', created_at: 2.days.ago)
      build_deal('B', created_at: 1.day.ago)

      expect(Rails.configuration.dispatcher)
        .not_to receive(:dispatch).with(Events::Types::CRM_DEAL_UPDATED, any_args)

      described_class.perform_now
    end

    it 'leaves updated_at untouched, so nothing downstream reads the backfill as activity' do
      deal = build_deal('A', created_at: 2.days.ago)
      touched_at = deal.reload.updated_at

      described_class.perform_now

      expect(deal.reload.updated_at).to eq(touched_at)
    end
  end

  # Achados CRITICAL e HIGH da revisao da F1.2.
  describe 'concurrency' do
    # O pool do RSpec entrega sempre a mesma conexao dentro da transacao do
    # teste, e lock consultivo e por sessao — na mesma sessao ele nunca
    # conflita. Para simular a outra execucao e preciso uma conexao de verdade,
    # fora do pool.
    def with_foreign_advisory_lock(key)
      config = ActiveRecord::Base.connection_db_config.configuration_hash
      other_session = PG.connect(
        host: config[:host] || 'localhost',
        port: config[:port] || 5432,
        dbname: config[:database],
        user: config[:username],
        password: config[:password]
      )
      other_session.exec("SELECT pg_advisory_lock(#{key})")
      yield
    ensure
      other_session&.close
    end

    it 'skips a stage another run is already positioning instead of racing it' do
      build_deal('A', created_at: 1.day.ago)
      key = described_class.new.advisory_lock_key(stage.id)

      with_foreign_advisory_lock(key) do
        expect(described_class.perform_now).to eq(0)
      end

      expect(account.crm_deals.where(position: nil).count).to eq(1)
    end

    it 'positions the stage normally once the other run releases the lock' do
      build_deal('A', created_at: 1.day.ago)
      key = described_class.new.advisory_lock_key(stage.id)

      with_foreign_advisory_lock(key) { described_class.perform_now }

      expect(described_class.perform_now).to eq(1)
    end

    it 'gives each stage its own lock key' do
      other_stage = pipeline.crm_pipeline_stages.create!(
        account: account, name: 'Qualificacao', slug: 'qualificacao', position: 1
      )
      job = described_class.new

      expect(job.advisory_lock_key(stage.id)).not_to eq(job.advisory_lock_key(other_stage.id))
    end

    # A corrida real acontece dentro de um unico statement SQL e nao e
    # reproduzivel em processo. O que da para fixar por teste e que a escrita
    # final revalida o mesmo predicado do snapshot do CTE — sem isso, o UPDATE
    # gravaria por cima de um card que outra transacao acabou de mover ou
    # reposicionar, em silencio.
    it 'revalidates the snapshot predicate in the UPDATE, not only in the CTE' do
      sql = described_class.new.send(:batch_sql, stage.id, 10, 0)
      update_clause = sql[/UPDATE crm_deals.*/m]

      expect(update_clause).to include('crm_deals.position IS NULL')
      expect(update_clause).to include("crm_deals.crm_pipeline_stage_id = #{stage.id}")
    end
  end
end
