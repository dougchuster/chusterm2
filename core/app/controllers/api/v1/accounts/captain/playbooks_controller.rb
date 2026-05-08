class Api::V1::Accounts::Captain::PlaybooksController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Captain::Assistant) }
  before_action :set_playbook, only: [:show, :update, :destroy]

  def index
    playbooks = Current.account.captain_playbooks.ordered
    playbooks = playbooks.where(assistant_id: params[:assistant_id]) if params[:assistant_id].present?
    playbooks = playbooks.for_legal_area(params[:legal_area]) if params[:legal_area].present?

    render json: playbooks.map { |playbook| playbook_payload(playbook) }
  end

  def show
    render json: playbook_payload(@playbook)
  end

  def create
    playbook = Current.account.captain_playbooks.create!(playbook_params)
    render json: playbook_payload(playbook), status: :created
  end

  def update
    @playbook.update!(playbook_params)
    render json: playbook_payload(@playbook)
  end

  def destroy
    @playbook.destroy!
    head :no_content
  end

  private

  def set_playbook
    @playbook = Current.account.captain_playbooks.find(params[:id])
  end

  def playbook_params
    permitted = params.require(:playbook).permit(
      :assistant_id, :name, :legal_area, :case_type, :objective,
      :instructions, :active, :position,
      required_fields: [],
      escalation_rules: {},
      metadata: {}
    )
    permitted[:assistant_id] = nil if permitted[:assistant_id].blank?
    permitted
  end

  def playbook_payload(playbook)
    playbook.context_payload.merge(
      assistant_id: playbook.assistant_id,
      active: playbook.active,
      position: playbook.position,
      metadata: playbook.metadata,
      created_at: playbook.created_at,
      updated_at: playbook.updated_at
    )
  end
end
