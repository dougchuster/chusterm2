require 'rails_helper'

# F1.5 do PLANO-KANBAN-CRM-2026.md — o board pinta com **uma** requisicao.
#
# Hoje o front busca todos os negocios do pipeline pagina a pagina e monta as
# colunas em JavaScript. Este endpoint devolve, por etapa, o que o cabecalho da
# coluna precisa (contagem, soma, tempo medio, WIP) mais os primeiros N cards.
RSpec.describe 'CRM Board API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Kanban', position: 1, is_default: true) }
  let!(:novo) do
    CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo', position: 1)
  end
  let!(:qualificado) do
    CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', position: 2)
  end

  def create_deal!(title:, stage: novo, **attrs)
    CrmDeal.create!(
      { account: account, crm_pipeline: pipeline, crm_pipeline_stage: stage, title: title }.merge(attrs)
    )
  end

  def board!(params = {})
    get "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/board",
        params: params, headers: headers, as: :json
    response.parsed_body
  end

  # F2.8: `id` e a chave do balde (texto), porque a coluna nem sempre e uma
  # etapa. Quando e, `stage_id` carrega a etapa de verdade.
  def column_for(body, stage)
    body['columns'].find { |column| column['stage_id'] == stage.id }
  end

  describe 'the shape of the answer' do
    it 'returns one column per active stage, in board order' do
      body = board!

      expect(response).to have_http_status(:success)
      expect(body['columns'].pluck('stage_id')).to eq([novo.id, qualificado.id])
      expect(body['pipeline']['id']).to eq(pipeline.id)
    end

    it 'answers with an empty column instead of omitting it' do
      body = board!

      column = column_for(body, qualificado)
      expect(column['count']).to eq(0)
      expect(column['deals']).to eq([])
      expect(column['sum_value_cents']).to eq(0)
    end
  end

  describe 'column aggregates' do
    it 'counts and sums the whole column, not only the cards it sends' do
      3.times { |i| create_deal!(title: "Novo #{i}", value_estimate_cents: 100_000) }
      create_deal!(title: 'Qualificado', stage: qualificado, value_estimate_cents: 900_000)

      body = board!({ per_column: 1 })

      column = column_for(body, novo)
      expect(column['count']).to eq(3)
      expect(column['sum_value_cents']).to eq(300_000)
      expect(column['deals'].size).to eq(1)
    end

    # Sem `stage_entered_at`, a resposta certa para quem nunca se moveu e a data
    # de criacao — nao zero, nem nulo.
    it 'measures the average time in stage from the creation date when the deal never moved' do
      create_deal!(title: 'Parado', created_at: 4.days.ago)
      create_deal!(title: 'Recente', created_at: 2.days.ago)

      column = column_for(board!, novo)

      expect(column['avg_days_in_stage']).to be_within(0.1).of(3.0)
    end

    it 'measures from stage_entered_at once the deal has moved' do
      create_deal!(title: 'Movido', created_at: 30.days.ago, stage_entered_at: 2.days.ago)

      column = column_for(board!, novo)

      expect(column['avg_days_in_stage']).to be_within(0.1).of(2.0)
    end

    it 'reports nil average for an empty column instead of zero' do
      expect(column_for(board!, novo)['avg_days_in_stage']).to be_nil
    end
  end

  describe 'WIP limit' do
    it 'reports no limit when the stage has none' do
      create_deal!(title: 'Um')

      column = column_for(board!, novo)

      expect(column['wip_limit']).to be_nil
      expect(column['over_wip']).to be(false)
    end

    it 'flags the column that went over its limit' do
      novo.update!(wip_limit: 2)
      3.times { |i| create_deal!(title: "Novo #{i}") }

      column = column_for(board!, novo)

      expect(column['wip_limit']).to eq(2)
      expect(column['over_wip']).to be(true)
    end

    it 'does not flag a column sitting exactly on the limit' do
      novo.update!(wip_limit: 2)
      2.times { |i| create_deal!(title: "Novo #{i}") }

      expect(column_for(board!, novo)['over_wip']).to be(false)
    end
  end

  # Achado HIGH da revisao da F1.5. `mark_won!`/`mark_lost!` nao tiram o card da
  # etapa: um negocio ganho ha tres meses continua morando em "Qualificado".
  # Conta-lo como trabalho em andamento fazia o teto de WIP disparar sozinho e o
  # tempo medio da coluna virar ficcao. Filtrar `status=open` no board inteiro
  # seria pior: esvaziaria as colunas Ganho e Perdido de um funil que as tenha.
  describe 'closed deals that never left the column' do
    it 'counts them in the column total, because the cards are still sitting there' do
      create_deal!(title: 'Aberto')
      create_deal!(title: 'Ganho', status: 'won', closed_at: 1.day.ago)

      column = column_for(board!, novo)

      expect(column['count']).to eq(2)
      expect(column['deals'].pluck('title')).to contain_exactly('Aberto', 'Ganho')
    end

    it 'leaves them out of the work-in-progress count' do
      create_deal!(title: 'Aberto')
      create_deal!(title: 'Ganho', status: 'won', closed_at: 1.day.ago)
      create_deal!(title: 'Perdido', status: 'lost', closed_at: 1.day.ago)

      expect(column_for(board!, novo)['open_count']).to eq(1)
    end

    it 'does not let them trip the WIP limit' do
      novo.update!(wip_limit: 2)
      create_deal!(title: 'Aberto')
      3.times { |i| create_deal!(title: "Ganho #{i}", status: 'won', closed_at: 1.day.ago) }

      column = column_for(board!, novo)

      expect(column['count']).to eq(4)
      expect(column['over_wip']).to be(false)
    end

    it 'does not let a deal closed months ago inflate the average age' do
      create_deal!(title: 'Aberto', created_at: 2.days.ago)
      create_deal!(title: 'Ganho', status: 'won', created_at: 200.days.ago, closed_at: 190.days.ago)

      expect(column_for(board!, novo)['avg_days_in_stage']).to be_within(0.1).of(2.0)
    end

    it 'reports nil average for a column with only closed deals' do
      create_deal!(title: 'Ganho', status: 'won', closed_at: 1.day.ago)

      column = column_for(board!, novo)

      expect(column['avg_days_in_stage']).to be_nil
      expect(column['open_count']).to eq(0)
    end
  end

  describe 'the cards it sends' do
    it 'orders by position, leaving the ones the backfill has not reached at the end' do
      create_deal!(title: 'Sem posicao', position: nil, created_at: 1.day.ago)
      create_deal!(title: 'Terceiro', position: 3000)
      create_deal!(title: 'Primeiro', position: 1000)

      column = column_for(board!, novo)

      expect(column['deals'].pluck('title')).to eq(['Primeiro', 'Terceiro', 'Sem posicao'])
    end

    it 'sends 25 cards per column by default' do
      30.times { |i| create_deal!(title: "Negocio #{i}", position: (i + 1) * 1000) }

      column = column_for(board!, novo)

      expect(column['deals'].size).to eq(25)
      expect(column['count']).to eq(30)
    end

    it 'caps how many cards a client can ask for' do
      body = board!({ per_column: 5000 })

      expect(body['meta']['per_column']).to eq(100)
    end

    it 'serializes the card with what the board needs to paint it' do
      create_deal!(title: 'Com dados', position: 1000, value_estimate_cents: 250_000)

      card = column_for(board!, novo)['deals'].first

      expect(card).to include('id', 'title', 'position', 'crm_pipeline_stage_id', 'value_estimate_cents')
    end
  end

  describe 'filters' do
    it 'honours the same filters as the deals index' do
      create_deal!(title: 'Caro', value_estimate_cents: 5_000_000)
      create_deal!(title: 'Barato', value_estimate_cents: 100)

      column = column_for(board!({ value_min: 1_000_000 }), novo)

      expect(column['deals'].pluck('title')).to eq(['Caro'])
      expect(column['count']).to eq(1)
    end

    it 'keeps the aggregates consistent with the filter, not with the whole column' do
      create_deal!(title: 'Caro', value_estimate_cents: 5_000_000)
      create_deal!(title: 'Barato', value_estimate_cents: 100)

      column = column_for(board!({ value_min: 1_000_000 }), novo)

      expect(column['sum_value_cents']).to eq(5_000_000)
    end
  end

  describe 'scoping' do
    it 'refuses a pipeline from another account' do
      vizinha = create(:account)
      alheio = CrmPipeline.create!(account: vizinha, name: 'Da vizinha', position: 1)

      get "/api/v1/accounts/#{account.id}/crm/pipelines/#{alheio.id}/board", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'leaves out archived stages' do
      qualificado.update!(archived_at: Time.current)

      expect(board!['columns'].pluck('stage_id')).to eq([novo.id])
    end
  end

  # Achado MEDIUM da revisao: a migration criou `wip_limit`, o board le, mas nao
  # havia como gravar por nenhuma superficie da aplicacao — so pelo console.
  describe 'setting the WIP limit through the stages API' do
    it 'accepts wip_limit on update and echoes it back' do
      patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{novo.id}",
            params: { stage: { wip_limit: 7 } }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['wip_limit']).to eq(7)
      expect(novo.reload.wip_limit).to eq(7)
    end

    it 'lets the limit be cleared back to no limit' do
      novo.update!(wip_limit: 7)

      patch "/api/v1/accounts/#{account.id}/crm/pipelines/#{pipeline.id}/stages/#{novo.id}",
            params: { stage: { wip_limit: nil } }, headers: headers, as: :json

      expect(novo.reload.wip_limit).to be_nil
    end
  end

  # F1.6 do PLANO-KANBAN-CRM-2026.md — rolar dentro da coluna.
  #
  # O board manda os primeiros 25; a coluna busca o resto pelo `index`. Sem
  # ordenar igual, a pagina 2 nao continua de onde a coluna parou: vem cartas
  # repetidas e cartas puladas.
  describe 'GET /crm/deals paginando dentro de uma coluna' do
    def page!(params)
      get "/api/v1/accounts/#{account.id}/crm/deals", params: params, headers: headers, as: :json
      response.parsed_body
    end

    it 'continues the board order across pages instead of restarting it' do
      30.times { |i| create_deal!(title: format('Negocio %02d', i), position: (i + 1) * 1000) }

      primeira = page!({ stage_id: novo.id, order: 'board', per_page: 25 })
      segunda = page!({ stage_id: novo.id, order: 'board', per_page: 25, page: 2 })

      expect(primeira['data'].first['title']).to eq('Negocio 00')
      expect(segunda['data'].pluck('title')).to eq(['Negocio 25', 'Negocio 26', 'Negocio 27', 'Negocio 28', 'Negocio 29'])
      expect((primeira['data'].pluck('id') & segunda['data'].pluck('id'))).to be_empty
    end

    it 'starts exactly where the board endpoint stopped' do
      30.times { |i| create_deal!(title: format('Negocio %02d', i), position: (i + 1) * 1000) }

      do_board = column_for(board!, novo)['deals'].pluck('title')
      resto = page!({ stage_id: novo.id, order: 'board', per_page: 25, page: 2 })['data'].pluck('title')

      expect(do_board.size).to eq(25)
      expect(do_board + resto).to eq((0..29).map { |i| format('Negocio %02d', i) })
    end

    it 'keeps the deals waiting for the backfill at the end of the column' do
      create_deal!(title: 'Sem posicao', position: nil, created_at: 10.days.ago)
      create_deal!(title: 'Com posicao', position: 1000)

      titles = page!({ stage_id: novo.id, order: 'board' })['data'].pluck('title')

      expect(titles).to eq(['Com posicao', 'Sem posicao'])
    end

    it 'reports the column total, so the client knows when to stop scrolling' do
      30.times { |i| create_deal!(title: "Negocio #{i}", position: (i + 1) * 1000) }
      create_deal!(title: 'De outra coluna', stage: qualificado)

      meta = page!({ stage_id: novo.id, order: 'board', per_page: 25 })['meta']

      expect(meta['total']).to eq(30)
      expect(meta['total_pages']).to eq(2)
    end

    # A ordenacao antiga continua sendo o padrao: `AllLeads` e a exportacao
    # dependem dela, e nao e trabalho desta fase mexer nelas.
    it 'still defaults to newest-first when no order is asked for' do
      create_deal!(title: 'Antigo', position: 1000, created_at: 10.days.ago)
      create_deal!(title: 'Recente', position: 2000, created_at: 1.day.ago)

      expect(page!({ stage_id: novo.id })['data'].pluck('title')).to eq(%w[Recente Antigo])
    end

    it 'ignores an order it does not know instead of failing the request' do
      create_deal!(title: 'Antigo', position: 1000, created_at: 10.days.ago)
      create_deal!(title: 'Recente', position: 2000, created_at: 1.day.ago)

      body = page!({ stage_id: novo.id, order: 'drop table' })

      expect(response).to have_http_status(:success)
      expect(body['data'].pluck('title')).to eq(%w[Recente Antigo])
    end
  end

  # F2.8 do PLANO-KANBAN-CRM-2026.md — a mesma tela respondendo outra pergunta.
  describe 'agrupar por outra coisa que nao a etapa' do
    it 'defaults to grouping by stage' do
      body = board!

      expect(body['meta']['group_by']).to eq('stage')
      expect(body['meta']['movable']).to be(true)
    end

    it 'groups by owner when asked' do
      owner = create(:user, account: account, role: :agent)
      create_deal!(title: 'Da pessoa', owner_id: owner.id)
      create_deal!(title: 'De ninguem')

      body = board!({ group_by: 'owner' })

      columns = body['columns'].index_by { |column| column['id'] }
      expect(columns[owner.id.to_s]['count']).to eq(1)
      expect(columns['__unassigned']['count']).to eq(1)
    end

    # Score e calculado, nao escolhido: arrastar entre faixas nao salvaria nada,
    # e o board precisa saber disso para nao oferecer o arrasto.
    it 'says a non-stage grouping cannot be dragged between' do
      body = board!({ group_by: 'score_band' })

      expect(body['meta']['movable']).to be(false)
      expect(body['columns'].pluck('stage_id').compact).to be_empty
    end

    it 'puts each deal in its score band' do
      create_deal!(title: 'Quente', score_total: 90)
      create_deal!(title: 'Frio', score_total: 10)

      columns = board!({ group_by: 'score_band' })['columns'].index_by { |c| c['id'] }

      expect(columns['hot']['deals'].pluck('title')).to eq(['Quente'])
      expect(columns['cold']['deals'].pluck('title')).to eq(['Frio'])
    end

    it 'aggregates money and count per group, not per stage' do
      owner = create(:user, account: account, role: :agent)
      create_deal!(title: 'Um', owner_id: owner.id, value_estimate_cents: 100_000)
      create_deal!(title: 'Dois', owner_id: owner.id, value_estimate_cents: 300_000,
                   stage: qualificado)

      column = board!({ group_by: 'owner' })['columns'].find { |c| c['id'] == owner.id.to_s }

      expect(column['count']).to eq(2)
      expect(column['sum_value_cents']).to eq(400_000)
    end

    # Colunas de agrupamento que nao sao etapa nao tem cor, prazo nem teto —
    # inventar um faria o cabecalho mentir.
    it 'leaves stage-only fields empty on a non-stage grouping' do
      create_deal!(title: 'Um', legal_area: 'trabalhista')

      column = board!({ group_by: 'legal_area' })['columns'].first

      expect(column['color']).to be_nil
      expect(column['wip_limit']).to be_nil
      expect(column['expected_duration_hours']).to be_nil
    end

    it 'honours the filters while grouping' do
      owner = create(:user, account: account, role: :agent)
      create_deal!(title: 'Caro', owner_id: owner.id, value_estimate_cents: 5_000_000)
      create_deal!(title: 'Barato', owner_id: owner.id, value_estimate_cents: 100)

      column = board!({ group_by: 'owner', value_min: 1_000_000 })['columns']
               .find { |c| c['id'] == owner.id.to_s }

      expect(column['deals'].pluck('title')).to eq(['Caro'])
      expect(column['count']).to eq(1)
    end

    it 'falls back to the stage when the grouping is unknown' do
      body = board!({ group_by: 'signo' })

      expect(body['meta']['group_by']).to eq('stage')
    end
  end
end
