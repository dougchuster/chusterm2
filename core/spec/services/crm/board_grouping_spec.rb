require 'rails_helper'

# F2.8 do PLANO-KANBAN-CRM-2026.md — agrupar por algo que não seja a etapa.
#
# O board sempre soube desenhar colunas de etapa. Agrupar por responsável, faixa
# de score, área ou origem é a mesma tela respondendo outra pergunta: "quem está
# sobrecarregado", "onde está o dinheiro", "de onde vêm os bons".
#
# A decisão que este serviço carrega: **só o agrupamento por etapa é movível**.
# Arrastar um card entre colunas de "faixa de score" não tem o que persistir —
# score é calculado, não escolhido. Dizer isso no servidor evita o board
# oferecer um arrasto que não salva nada.
RSpec.describe Crm::BoardGrouping do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Kanban', slug: 'kanban', kind: 'legal_intake') }
  let!(:novo) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0)
  end
  let!(:qualificado) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Qualificado', slug: 'qualificado', position: 1)
  end
  let(:ana) { create(:user, account: account) }

  def grouping(group_by)
    described_class.for(group_by, pipeline: pipeline, account: account)
  end

  def build_deal(title, stage: novo, **attrs)
    account.crm_deals.create!(
      { crm_pipeline: pipeline, crm_pipeline_stage: stage, title: title }.merge(attrs)
    )
  end

  def bucket_of(deal, group_by)
    account.crm_deals.where(id: deal.id).pick(Arel.sql(grouping(group_by).key_sql)).to_s
  end

  describe 'por etapa (o padrão)' do
    it 'makes one bucket per active stage, in board order' do
      expect(grouping('stage').buckets.map { |b| b[:name] }).to eq(%w[Novo Qualificado])
    end

    it 'leaves archived stages out' do
      qualificado.update!(archived_at: Time.current)

      expect(grouping('stage').buckets.map { |b| b[:name] }).to eq(['Novo'])
    end

    it 'carries what only a stage has: colour, WIP and expected duration' do
      novo.update!(color: '#2563eb', wip_limit: 5, expected_duration_hours: 48)

      bucket = grouping('stage').buckets.first
      expect(bucket[:color]).to eq('#2563eb')
      expect(bucket[:wip_limit]).to eq(5)
      expect(bucket[:expected_duration_hours]).to eq(48)
    end

    it 'is the only grouping a card can be dragged between' do
      expect(grouping('stage')).to be_movable
    end

    it 'places a deal in its own stage' do
      deal = build_deal('Meu', stage: qualificado)

      expect(bucket_of(deal, 'stage')).to eq(qualificado.id.to_s)
    end
  end

  describe 'por responsável' do
    it 'makes one bucket per agent of the account' do
      ana

      expect(grouping('owner').buckets.map { |b| b[:name] }).to include(ana.name)
    end

    # "Sem responsável" é uma coluna de verdade: é onde o trabalho não atribuído
    # se acumula, e é a pergunta que o board precisa responder.
    it 'keeps a column for the unassigned work' do
      expect(grouping('owner').buckets.map { |b| b[:id] }).to include('__unassigned')
    end

    it 'places an unowned deal in the unassigned column' do
      deal = build_deal('Sem dono')

      expect(bucket_of(deal, 'owner')).to eq('__unassigned')
    end

    it 'places an owned deal under its owner' do
      deal = build_deal('Da Ana', owner_id: ana.id)

      expect(bucket_of(deal, 'owner')).to eq(ana.id.to_s)
    end

    # Reatribuir por arrasto é uma feature, não um efeito colateral — e não é
    # esta tarefa.
    it 'cannot be dragged between, for now' do
      expect(grouping('owner')).not_to be_movable
    end
  end

  describe 'por faixa de score' do
    it 'uses the same bands the filter uses' do
      expect(grouping('score_band').buckets.map { |b| b[:id] })
        .to eq(%w[hot qualified medium cold])
    end

    {
      95 => 'hot',
      70 => 'qualified',
      45 => 'medium',
      10 => 'cold'
    }.each do |score, band|
      it "places a deal scoring #{score} in the #{band} band" do
        deal = build_deal("Score #{score}", score_total: score)

        expect(bucket_of(deal, 'score_band')).to eq(band)
      end
    end

    # Score é calculado, não escolhido: arrastar para outra faixa não teria o
    # que salvar.
    it 'cannot be dragged between' do
      expect(grouping('score_band')).not_to be_movable
    end
  end

  describe 'por área, origem e situação' do
    it 'groups by the legal area the deals actually have' do
      build_deal('Trabalhista', legal_area: 'trabalhista')
      build_deal('Cível', legal_area: 'civel')

      expect(grouping('legal_area').buckets.map { |b| b[:id] }).to include('trabalhista', 'civel')
    end

    # O escritório é full service: a lista de áreas vem dos dados, não de uma
    # constante que presume INSS.
    it 'does not invent an area the account never used' do
      build_deal('Trabalhista', legal_area: 'trabalhista')

      expect(grouping('legal_area').buckets.map { |b| b[:id] }).not_to include('previdenciario')
    end

    it 'keeps a column for deals with no area at all' do
      build_deal('Sem área')

      expect(grouping('legal_area').buckets.map { |b| b[:id] }).to include('__none')
    end

    it 'groups by source' do
      build_deal('Indicação', source: 'indicacao')

      expect(grouping('source').buckets.map { |b| b[:id] }).to include('indicacao')
    end

    # Situação operacional é lista fechada no modelo: mostrar todas mantém a
    # coluna vazia visível, que é informação.
    it 'shows every operational status the model allows' do
      expect(grouping('operational_status').buckets.map { |b| b[:id] })
        .to match_array(CrmDeal::OPERATIONAL_STATUSES)
    end
  end

  describe 'agrupamento desconhecido' do
    it 'falls back to the stage instead of blowing up the board' do
      expect(grouping('signo').group_by).to eq('stage')
    end

    it 'falls back when nothing was asked for' do
      expect(grouping(nil).group_by).to eq('stage')
    end
  end
end
