require 'rails_helper'

# F1.1 do PLANO-KANBAN-CRM-2026.md — ordenacao fracionaria dentro da coluna.
# A coluna precisa aguentar insercoes sucessivas pelo ponto medio entre dois
# vizinhos sem reescrever a coluna inteira.
RSpec.describe CrmDeal do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban Teste', slug: 'kanban-teste', kind: 'legal_intake') }
  let(:stage) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
  end

  def build_deal(title, position: nil)
    account.crm_deals.create!(
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      title: title,
      position: position
    )
  end

  describe 'the position column' do
    let(:column) { described_class.columns_hash['position'] }

    it 'exposes a position column' do
      expect(column).to be_present
    end

    it 'stores position as a decimal with room for fractional ordering' do
      expect(column.type).to eq(:decimal)
      expect([column.precision, column.scale]).to eq([20, 10])
    end

    it 'allows a null position so the backfill can run in batches' do
      expect(column.null).to be(true)
    end

    it 'indexes the column together with the stage that scopes the board query' do
      index = ActiveRecord::Base.connection
                                .indexes(:crm_deals)
                                .find { |i| i.columns == %w[crm_pipeline_stage_id position] }

      expect(index).to be_present
    end
  end

  describe 'fractional ordering' do
    it 'round-trips a position with ten decimal places' do
      deal = build_deal('Precisao', position: BigDecimal('1000.0000000001'))

      expect(deal.reload.position).to eq(BigDecimal('1000.0000000001'))
    end

    it 'keeps deals ordered by position inside the stage' do
      last = build_deal('Ultimo', position: 2000)
      first = build_deal('Primeiro', position: 1000)
      middle = build_deal('Meio', position: 1500)

      ordered = account.crm_deals.by_stage(stage.id).order(:position).pluck(:title)

      expect(ordered).to eq([first.title, middle.title, last.title])
      expect(last.position).to eq(2000)
    end

    it 'survives 30 successive midpoint insertions between the same two neighbours' do
      low = BigDecimal(1000)
      high = BigDecimal(1001)
      build_deal('Base baixa', position: low)
      build_deal('Base alta', position: high)

      30.times do |i|
        midpoint = (low + high) / 2
        expect(midpoint).to be > low
        expect(midpoint).to be < high

        build_deal("Intercalado #{i}", position: midpoint)
        high = midpoint
      end

      positions = account.crm_deals.by_stage(stage.id).order(:position).pluck(:position)
      expect(positions.uniq.size).to eq(positions.size)
    end

    # Este teste NAO descreve um caminho feliz: ele fixa o teto do esquema.
    # Com escala 10, cabem floor(log2(gap / 1e-10)) bisseccoes entre dois
    # vizinhos. Para gap = 1 isso da 33. Passado o teto o ponto medio arredonda
    # para um valor que ja existe — e como nao ha indice unico em `position`, a
    # colisao seria silenciosa e o usuario perderia a capacidade de reordenar
    # naquele ponto da fila. E por isso que F1.3 precisa reequilibrar a coluna
    # antes de chegar aqui. Se alguem mudar a escala, este teste avisa.
    it 'exhausts the fractional gap after at most 40 midpoints, which is why rebalancing is required' do
      low = BigDecimal(1000)
      high = BigDecimal(1001)
      build_deal('Base baixa', position: low)
      build_deal('Base alta', position: high)

      collided_at = (1..40).find do |i|
        persisted = build_deal("Intercalado #{i}", position: (low + high) / 2).reload.position
        collided = persisted <= low || persisted >= high
        high = persisted
        collided
      end

      expect(collided_at).to be_between(30, 40).inclusive
    end

    it 'allows the same position in different stages, since the index is not unique' do
      other_stage = pipeline.crm_pipeline_stages.create!(
        account: account, name: 'Qualificacao', slug: 'qualificacao', position: 1
      )
      build_deal('Primeiro da coluna A', position: 1000)

      twin = account.crm_deals.create!(
        crm_pipeline: pipeline,
        crm_pipeline_stage: other_stage,
        title: 'Primeiro da coluna B',
        position: 1000
      )

      expect(twin.reload.position).to eq(1000)
    end
  end

  # A F1.2 preenche `position` em lotes. Enquanto o job nao termina, a coluna
  # convive com valores e NULLs — e o board precisa continuar legivel.
  describe 'ordering while the backfill is still running' do
    it 'puts deals without a position last in ascending order' do
      build_deal('Sem posicao', position: nil)
      build_deal('Com posicao', position: 1000)

      ordered = account.crm_deals.by_stage(stage.id).order(:position).pluck(:title)

      expect(ordered).to eq(['Com posicao', 'Sem posicao'])
    end

    it 'keeps deals without a position out of the way when ordering descending' do
      build_deal('Sem posicao', position: nil)
      build_deal('Com posicao', position: 1000)

      ordered = account.crm_deals
                       .by_stage(stage.id)
                       .order(Arel.sql('position DESC NULLS LAST'))
                       .pluck(:title)

      expect(ordered).to eq(['Com posicao', 'Sem posicao'])
    end
  end
end
