class Api::V1::Accounts::Captain::FlowsController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Flow) }
  before_action :set_flow, only: [:show, :update, :destroy, :publish, :graph]

  def index
    @flows = account_flows.active.ordered
  end

  def show; end

  def create
    @flow = account_flows.create!(flow_params)
  end

  def update
    @flow.update!(flow_params)
  end

  def destroy
    @flow.destroy
    head :no_content
  end

  def publish
    @flow.publish!
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def graph
    @flow.save_graph!(
      nodes: graph_params[:nodes] || [],
      edges: graph_params[:edges] || [],
      actor: Current.user
    )
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_flow
    @flow = account_flows.find(params[:id])
  end

  def account_flows
    @account_flows ||= Captain::Flow.for_account(Current.account.id)
  end

  def flow_params
    params.require(:flow).permit(:name, :slug, :description, :captain_assistant_id)
  end

  def graph_params
    params.require(:flow).permit(
      nodes: [:node_id, :node_type, :position_x, :position_y, { config: {} }],
      edges: [:edge_id, :source_node_id, :target_node_id, :label, { condition: {} }]
    )
  end
end
