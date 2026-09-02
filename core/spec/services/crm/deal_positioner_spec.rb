require 'rails_helper'

# F1.3 do PLANO-KANBAN-CRM-2026.md — o servidor calcula a posicao, o cliente so
# diz entre quais vizinhos o card caiu.
#
# Convencao dos parametros, e ela e a fonte de confusao mais provavel deste
# codigo: `after_id` e o negocio que fica **acima** do card movido (posicao
# menor), `before_id` e o que fica **abaixo** (posicao maior). Le-se "coloque
# depois de A e antes de B".
RSpec.describe Crm::DealPositioner do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban Teste', slug: 'kanban-teste', kind: 'legal_intake') }
  let(:stage) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
  end

  def build_deal(title, position: nil, stage: self.stage)
    stage.account.crm_deals.create!(
      crm_pipeline: stage.crm_pipeline,
      crm_pipeline_stage: stage,
      title: title,
      position: position
    )
  end

  def position_for(before_id: nil, after_id: nil)
    described_class.new(stage: stage, before_id: before_id, after_id: after_id).call
  end

  describe 'without neighbours' do
    it 'puts the card on top of an empty column' do
      expect(position_for).to eq(1000)
    end

    # Um card que acabou de entrar na etapa e o que pede atencao. E o mesmo
    # lugar que o board de hoje (ordenado por created_at desc) daria a ele.
    it 'puts the card on top of a column that already has cards' do
      build_deal('Primeiro', position: 1000)

      expect(position_for).to eq(0)
    end

    # Bisseccionar o topo (dividir o minimo por dois) esgota a escala em ~20
    # movimentos e transforma um "mover em massa" numa cascata de
    # rebalanceamentos. Andar um gap cheio nunca perde precisao, e a coluna nao
    # tem piso — posicao negativa e legitima.
    it 'walks a full gap above the first card instead of bisecting, even past zero' do
      build_deal('Colado no zero', position: BigDecimal('0.5'))

      expect(position_for).to eq(BigDecimal('-999.5'))
    end

    it 'keeps successive top drops a full gap apart, so the scale never runs out' do
      build_deal('Primeiro', position: 1000)

      posicoes = Array.new(30) do
        posicao = position_for
        build_deal("Topo #{posicao.to_i}", position: posicao)
        posicao
      end

      expect(posicoes.each_cons(2).map { |a, b| a - b }).to all(eq(1000))
      expect(posicoes.uniq.size).to eq(30)
    end

    it 'ignores deals still waiting for the backfill' do
      build_deal('Sem posicao', position: nil)
      build_deal('Com posicao', position: 1000)

      expect(position_for).to eq(0)
    end
  end

  describe 'with one neighbour' do
    it 'drops the card between the given predecessor and whatever follows it' do
      above = build_deal('Acima', position: 1000)
      build_deal('Abaixo', position: 2000)

      expect(position_for(after_id: above.id)).to eq(1500)
    end

    it 'drops the card below the last one when nothing follows the predecessor' do
      last = build_deal('Ultimo', position: 1000)

      expect(position_for(after_id: last.id)).to eq(2000)
    end

    it 'drops the card between the given successor and whatever precedes it' do
      build_deal('Acima', position: 1000)
      below = build_deal('Abaixo', position: 2000)

      expect(position_for(before_id: below.id)).to eq(1500)
    end

    it 'drops the card above the first one when nothing precedes the successor' do
      first = build_deal('Primeiro', position: 1000)

      expect(position_for(before_id: first.id)).to eq(0)
    end
  end

  describe 'with both neighbours' do
    # Achado no bench de 200 reordenacoes: 27 posicoes duplicadas. O cliente
    # continua informando o mesmo par de vizinhos porque a tela dele nao viu os
    # cards que entraram no meio, e o ponto medio de 1000 e 2000 e sempre 1500.
    it 'never lands on top of a card that entered between the reported neighbours' do
      topo = build_deal('Topo', position: 1000)
      fundo = build_deal('Fundo', position: 2000)

      posicoes = Array.new(20) do |i|
        posicao = position_for(after_id: topo.id, before_id: fundo.id)
        build_deal("Intercalado #{i}", position: posicao)
        posicao
      end

      expect(posicoes.uniq.size).to eq(posicoes.size)
      expect(stage.crm_deals.pluck(:position).uniq.size).to eq(22)
    end

    it 'keeps the card right below the anchor the user aimed at' do
      topo = build_deal('Topo', position: 1000)
      fundo = build_deal('Fundo', position: 2000)
      build_deal('Entrou no meio', position: 1500)

      expect(position_for(after_id: topo.id, before_id: fundo.id)).to eq(1250)
    end

    it 'lands on the midpoint' do
      above = build_deal('Acima', position: 1000)
      below = build_deal('Abaixo', position: 2000)

      expect(position_for(after_id: above.id, before_id: below.id)).to eq(1500)
    end

    it 'rejects neighbours given in the wrong order instead of guessing' do
      above = build_deal('Acima', position: 1000)
      below = build_deal('Abaixo', position: 2000)

      expect { position_for(after_id: below.id, before_id: above.id) }
        .to raise_error(ArgumentError, /ordem/i)
    end

    it 'rejects a neighbour from another stage' do
      other_stage = pipeline.crm_pipeline_stages.create!(
        account: account, name: 'Qualificacao', slug: 'qualificacao', position: 1
      )
      stranger = build_deal('De outra coluna', position: 1000, stage: other_stage)

      expect { position_for(after_id: stranger.id) }
        .to raise_error(ArgumentError, /etapa/i)
    end

    it 'ignores a neighbour id that does not exist' do
      build_deal('Primeiro', position: 1000)

      expect(position_for(after_id: 0)).to eq(0)
    end
  end

  # F1.3-a: sem isso, reordenar o topo da coluna todo dia acaba com a precisao
  # da escala e a colisao e silenciosa.
  describe 'rebalancing (F1.3-a)' do
    it 'renumbers the column when the neighbours got too close to bisect' do
      above = build_deal('Acima', position: BigDecimal('1000.0000000001'))
      below = build_deal('Abaixo', position: BigDecimal('1000.0000000002'))
      bottom = build_deal('Fundo', position: 5000)

      result = position_for(after_id: above.id, before_id: below.id)

      expect(above.reload.position).to eq(1000)
      expect(below.reload.position).to eq(2000)
      expect(bottom.reload.position).to eq(3000)
      expect(result).to eq(1500)
    end

    it 'keeps the column order intact while renumbering' do
      titles = %w[A B C]
      a = build_deal('A', position: BigDecimal('10.0000000001'))
      b = build_deal('B', position: BigDecimal('10.0000000002'))
      build_deal('C', position: 900)

      position_for(after_id: a.id, before_id: b.id)

      expect(stage.crm_deals.order(:position).pluck(:title)).to eq(titles)
    end

    it 'leaves deals of other stages untouched' do
      other_stage = pipeline.crm_pipeline_stages.create!(
        account: account, name: 'Qualificacao', slug: 'qualificacao', position: 1
      )
      untouched = build_deal('De outra coluna', position: BigDecimal('42.5'), stage: other_stage)
      above = build_deal('Acima', position: BigDecimal('1000.0000000001'))
      below = build_deal('Abaixo', position: BigDecimal('1000.0000000002'))

      position_for(after_id: above.id, before_id: below.id)

      expect(untouched.reload.position).to eq(BigDecimal('42.5'))
    end

    it 'does not renumber a column whose gap is still comfortable' do
      above = build_deal('Acima', position: 1000)
      below = build_deal('Abaixo', position: 2000)

      position_for(after_id: above.id, before_id: below.id)

      expect(above.reload.position).to eq(1000)
      expect(below.reload.position).to eq(2000)
    end
  end
end
