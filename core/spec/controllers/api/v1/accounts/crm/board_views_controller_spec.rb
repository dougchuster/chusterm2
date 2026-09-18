require 'rails_helper'

# F2.7 do PLANO-KANBAN-CRM-2026.md — "menu de visões com minhas e da equipe".
#
# O que este arquivo protege não é CRUD: é quem enxerga e quem pode apagar. Uma
# visão compartilhada é da equipe para **usar**, não para qualquer um mexer.
RSpec.describe 'CRM Board Views API', type: :request do
  let(:account) { create(:account) }
  let(:ana) { create(:user, account: account, role: :agent) }
  let(:bruno) { create(:user, account: account, role: :agent) }
  let(:headers) { ana.create_new_auth_token }
  let(:bruno_headers) { bruno.create_new_auth_token }

  def create_view!(user:, name:, **attrs)
    account.crm_board_views.create!(
      { user: user, name: name, filters: { 'score_min' => 80 } }.merge(attrs)
    )
  end

  describe 'GET /api/v1/accounts/:account_id/crm/board_views' do
    it 'lists my views and what the team shared' do
      minha = create_view!(user: ana, name: 'Meus quentes')
      da_equipe = create_view!(user: bruno, name: 'Sem próxima ação', is_shared: true)
      create_view!(user: bruno, name: 'Privada do Bruno')

      get "/api/v1/accounts/#{account.id}/crm/board_views", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to contain_exactly(minha.id, da_equipe.id)
    end

    # O menu separa "minhas" de "da equipe": o front precisa saber qual é qual
    # sem comparar ids de usuário.
    it 'says which ones are mine' do
      create_view!(user: ana, name: 'Minha')
      create_view!(user: bruno, name: 'Da equipe', is_shared: true)

      get "/api/v1/accounts/#{account.id}/crm/board_views", headers: headers, as: :json

      mine = response.parsed_body.index_by { |view| view['name'] }
      expect(mine['Minha']['is_mine']).to be(true)
      expect(mine['Da equipe']['is_mine']).to be(false)
    end

    it 'keeps the order the attendant arranged' do
      create_view!(user: ana, name: 'C', position: 3)
      create_view!(user: ana, name: 'A', position: 1)
      create_view!(user: ana, name: 'B', position: 2)

      get "/api/v1/accounts/#{account.id}/crm/board_views", headers: headers, as: :json

      expect(response.parsed_body.pluck('name')).to eq(%w[A B C])
    end

    it 'never leaks a view from another account' do
      vizinha = create(:account)
      outro = create(:user, account: vizinha)
      vizinha.crm_board_views.create!(user: outro, name: 'Da vizinha', is_shared: true, filters: {})

      get "/api/v1/accounts/#{account.id}/crm/board_views", headers: headers, as: :json

      expect(response.parsed_body).to be_empty
    end

    # 6.3 — relatórios salvos vivem na mesma tabela, separados por context.
    it 'filters by context: board views do not mix with saved reports' do
      do_board = create_view!(user: ana, name: 'No quadro')
      do_report = create_view!(user: ana, name: 'Semana atual', context: 'report')

      get "/api/v1/accounts/#{account.id}/crm/board_views",
          params: { context: 'report' }, headers: headers, as: :json

      expect(response.parsed_body.pluck('id')).to eq([do_report.id])
      expect(response.parsed_body.first['context']).to eq('report')

      get "/api/v1/accounts/#{account.id}/crm/board_views", headers: headers, as: :json

      expect(response.parsed_body.pluck('id')).to eq([do_board.id])
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/board_views' do
    it 'saves the filter with a name' do
      post "/api/v1/accounts/#{account.id}/crm/board_views",
           params: {
             board_view: {
               name: 'Sem próxima ação',
               filters: { has_pending_activity: false },
               group_by: 'owner'
             }
           },
           headers: headers, as: :json

      expect(response).to have_http_status(:created)
      view = account.crm_board_views.last
      expect(view.name).to eq('Sem próxima ação')
      expect(view.group_by).to eq('owner')
      expect(view.user).to eq(ana)
    end

    # A visão que responde a meta de <10% do plano é justamente `false`. Se o
    # jsonb perdesse isso, ela viraria "sem filtro nenhum".
    it 'keeps a false in the filters, because false is a filter' do
      post "/api/v1/accounts/#{account.id}/crm/board_views",
           params: { board_view: { name: 'Sem ação', filters: { has_pending_activity: false } } },
           headers: headers, as: :json

      expect(account.crm_board_views.last.filters['has_pending_activity']).to be(false)
    end

    it 'refuses a second view of mine with the same name' do
      create_view!(user: ana, name: 'Radar')

      post "/api/v1/accounts/#{account.id}/crm/board_views",
           params: { board_view: { name: 'Radar', filters: {} } },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'ignores an attempt to save the view under someone else' do
      post "/api/v1/accounts/#{account.id}/crm/board_views",
           params: { board_view: { name: 'Minha', filters: {}, user_id: bruno.id } },
           headers: headers, as: :json

      expect(account.crm_board_views.last.user).to eq(ana)
    end

    # 6.3 — group_by é conceito de board; relatório salvo não carrega isso.
    it 'accepts a report view even when group_by would be invalid for boards' do
      post "/api/v1/accounts/#{account.id}/crm/board_views",
           params: {
             board_view: {
               name: 'Funil do mês',
               context: 'report',
               group_by: 'bogus',
               filters: { 'from' => '2026-09-01' }
             }
           },
           headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_board_views.last.context).to eq('report')
    end

    it 'still validates group_by for board views' do
      post "/api/v1/accounts/#{account.id}/crm/board_views",
           params: { board_view: { name: 'Zoada', group_by: 'bogus', filters: {} } },
           headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/board_views/:id' do
    it 'lets me rename my own view' do
      view = create_view!(user: ana, name: 'Antigo')

      patch "/api/v1/accounts/#{account.id}/crm/board_views/#{view.id}",
            params: { board_view: { name: 'Novo' } }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(view.reload.name).to eq('Novo')
    end

    it 'lets me share my view with the team' do
      view = create_view!(user: ana, name: 'Minha')

      patch "/api/v1/accounts/#{account.id}/crm/board_views/#{view.id}",
            params: { board_view: { is_shared: true } }, headers: headers, as: :json

      expect(view.reload.is_shared).to be(true)
    end

    # Compartilhada é da equipe para **usar**. Deixar qualquer um editar faria a
    # visão de alguém mudar debaixo dele.
    it 'refuses to let me edit a view that is not mine, even a shared one' do
      view = create_view!(user: bruno, name: 'Do Bruno', is_shared: true)

      patch "/api/v1/accounts/#{account.id}/crm/board_views/#{view.id}",
            params: { board_view: { name: 'Sequestrada' } }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(view.reload.name).to eq('Do Bruno')
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/crm/board_views/:id' do
    it 'deletes my own view' do
      view = create_view!(user: ana, name: 'Minha')

      delete "/api/v1/accounts/#{account.id}/crm/board_views/#{view.id}",
             headers: headers, as: :json

      expect(response).to have_http_status(:no_content)
      expect(account.crm_board_views.find_by(id: view.id)).to be_nil
    end

    it 'refuses to delete a shared view that belongs to someone else' do
      view = create_view!(user: bruno, name: 'Do Bruno', is_shared: true)

      delete "/api/v1/accounts/#{account.id}/crm/board_views/#{view.id}",
             headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(account.crm_board_views.find_by(id: view.id)).to be_present
    end

    it 'lets the owner delete a view they had shared' do
      view = create_view!(user: bruno, name: 'Do Bruno', is_shared: true)

      delete "/api/v1/accounts/#{account.id}/crm/board_views/#{view.id}",
             headers: bruno_headers, as: :json

      expect(response).to have_http_status(:no_content)
    end
  end
end
