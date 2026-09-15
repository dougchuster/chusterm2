class Api::V1::Accounts::Crm::AutomationRunsController < Api::V1::Accounts::Crm::BaseController
  def index
    authorize CrmAutomationRun, :index?

    runs = Current.account.crm_automation_runs
    runs = runs.for_deal(params[:deal_id]) if params[:deal_id].present?
    runs = runs.for_rule(params[:automation_rule_id]) if params[:automation_rule_id].present?
    runs = runs.where(status: params[:status]) if params[:status].present?
    runs = runs.order(started_at: :desc).includes(:crm_automation_rule, :crm_deal).limit(100)
    render json: runs.map { |run| serialize_run(run) }
  end

  private

  def serialize_run(run)
    {
      id: run.id,
      status: run.status,
      skip_reason: run.skip_reason,
      error: run.error,
      payload: run.payload,
      started_at: run.started_at,
      finished_at: run.finished_at,
      automation_rule: {
        id: run.crm_automation_rule_id,
        name: run.crm_automation_rule&.name
      },
      deal: {
        id: run.crm_deal_id,
        title: run.crm_deal&.title
      }
    }
  end
end
