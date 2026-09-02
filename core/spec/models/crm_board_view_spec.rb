require 'rails_helper'

# F2.7 do PLANO-KANBAN-CRM-2026.md — visões salvas.
#
# "Cada atendente reconstrói o filtro todo dia" é a lacuna K-05. Uma visão é um
# filtro com nome, e a decisão de produto que ela carrega é: **minha ou da
# equipe**. Compartilhar não é detalhe de UI — muda quem pode apagar.
RSpec.describe CrmBoardView do
  let(:account) { create(:account) }
  let(:ana) { create(:user, account: account) }
  let(:bruno) { create(:user, account: account) }

  def build_view(**attrs)
    account.crm_board_views.create!(
      { user: ana, name: 'Meus quentes', filters: { 'score_min' => 80 } }.merge(attrs)
    )
  end

  describe 'o que uma visão precisa ter' do
    it 'belongs to an account and to whoever created it' do
      view = build_view

      expect(view.account).to eq(account)
      expect(view.user).to eq(ana)
    end

    it 'refuses a view with no name' do
      expect { build_view(name: '') }.to raise_error(ActiveRecord::RecordInvalid, /Name/)
    end

    it 'keeps the filters as they were saved' do
      view = build_view(
        filters: { 'stage_id' => [10, 20], 'has_pending_activity' => false }
      )

      expect(view.reload.filters).to eq(
        'stage_id' => [10, 20], 'has_pending_activity' => false
      )
    end

    # `has_pending_activity: false` é a visão que responde a meta de <10% do
    # plano. Se o jsonb perdesse o `false`, a visão mais importante viraria
    # "sem filtro".
    it 'does not lose a false, which is a filter and not an absence' do
      view = build_view(filters: { 'has_pending_activity' => false })

      expect(view.reload.filters['has_pending_activity']).to be(false)
    end

    it 'starts private, because sharing is a decision and not a default' do
      expect(build_view.is_shared).to be(false)
    end

    it 'defaults the grouping to the stage, which is how the board opens' do
      expect(build_view.group_by).to eq('stage')
    end

    it 'refuses a grouping the board does not know' do
      expect { build_view(group_by: 'signo') }
        .to raise_error(ActiveRecord::RecordInvalid, /Group by/)
    end
  end

  describe 'nomes' do
    it 'refuses two views with the same name for the same person' do
      build_view(name: 'Radar')

      expect { build_view(name: 'Radar') }
        .to raise_error(ActiveRecord::RecordInvalid, /Name/)
    end

    # Duas pessoas podem ter, cada uma, a sua "Radar": são visões diferentes.
    it 'lets two people keep a view with the same name' do
      build_view(name: 'Radar')

      expect { build_view(name: 'Radar', user: bruno) }.not_to raise_error
    end
  end

  describe 'quem enxerga o quê' do
    it 'shows me my own views' do
      minha = build_view(name: 'Minha')

      expect(described_class.visible_to(ana)).to include(minha)
    end

    it 'hides someone else private view from me' do
      alheia = build_view(name: 'Do Bruno', user: bruno)

      expect(described_class.visible_to(ana)).not_to include(alheia)
    end

    it 'shows me what the team shared' do
      compartilhada = build_view(name: 'Da equipe', user: bruno, is_shared: true)

      expect(described_class.visible_to(ana)).to include(compartilhada)
    end

    it 'never shows a view from another account' do
      vizinha = create(:account)
      outro = create(:user, account: vizinha)
      alheia = vizinha.crm_board_views.create!(
        user: outro, name: 'Da vizinha', is_shared: true, filters: {}
      )

      expect(described_class.visible_to(ana)).not_to include(alheia)
    end
  end

  describe 'ordem' do
    it 'keeps the order the attendant arranged' do
      terceira = build_view(name: 'C', position: 3)
      primeira = build_view(name: 'A', position: 1)
      segunda = build_view(name: 'B', position: 2)

      expect(account.crm_board_views.ordered.pluck(:id))
        .to eq([primeira.id, segunda.id, terceira.id])
    end

    it 'puts a new view at the end instead of at an arbitrary place' do
      build_view(name: 'A')
      ultima = build_view(name: 'B')

      expect(ultima.position).to be > account.crm_board_views.find_by(name: 'A').position
    end
  end
end
