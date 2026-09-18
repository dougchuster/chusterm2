# F2.7 do PLANO-KANBAN-CRM-2026.md — visoes salvas do board.
#
# O que este controller protege nao e CRUD: e **quem enxerga e quem pode
# mexer**. Uma visao compartilhada e da equipe para usar, nao para qualquer um
# editar — deixar editar faria a visao de alguem mudar debaixo dele.
class Api::V1::Accounts::Crm::BoardViewsController < Api::V1::Accounts::Crm::BaseController
  before_action :editable_view, only: [:update, :destroy]

  def index
    views = CrmBoardView.visible_to(Current.user)
                        .where(account_id: Current.account.id)
                        .for_context(params[:context])
                        .ordered

    render json: views.map { |view| serialize_view(view) }
  end

  def create
    # `user` vem sempre de quem esta logado: aceitar `user_id` do cliente
    # deixaria alguem salvar visao no nome de outro.
    view = Current.account.crm_board_views.new(board_view_params.merge(user: Current.user))

    if view.save
      render json: serialize_view(view), status: :created
    else
      render json: { error: view.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def update
    if @view.update(board_view_params)
      render json: serialize_view(@view)
    else
      render json: { error: @view.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    @view.destroy!
    head :no_content
  end

  private

  # Editar e apagar so valem para a propria visao. Devolver 404 em vez de 403 e
  # deliberado: o cliente nao precisa saber que a visao de outra pessoa existe
  # com aquele id.
  def editable_view
    @view = Current.account.crm_board_views.find_by(id: params[:id], user_id: Current.user.id)

    render json: { error: 'Visão não encontrada' }, status: :not_found if @view.blank?
  end

  def board_view_params
    params.require(:board_view).permit(
      :name, :group_by, :sort, :is_shared, :position, :context, filters: {}
    )
  end

  def serialize_view(view)
    {
      id: view.id,
      name: view.name,
      filters: view.filters,
      context: view.context,
      group_by: view.group_by,
      sort: view.sort,
      is_shared: view.is_shared,
      position: view.position,
      # O menu separa "minhas" de "da equipe"; sem isso o front teria que
      # comparar ids de usuario para desenhar dois grupos.
      is_mine: view.user_id == Current.user.id,
      owner_name: view.user&.name,
      created_at: view.created_at,
      updated_at: view.updated_at
    }
  end
end
