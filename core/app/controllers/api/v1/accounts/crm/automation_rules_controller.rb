class Api::V1::Accounts::Crm::AutomationRulesController < Api::V1::Accounts::Crm::BaseController
  before_action :automation_rule, only: [:update, :destroy]

  def index
    authorize CrmAutomationRule, :index?

    @rules = Current.account.crm_automation_rules.ordered
    render json: @rules.map { |r| serialize(r) }
  end

  def create
    authorize CrmAutomationRule, :create?

    @rule = Current.account.crm_automation_rules.create!(automation_rule_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'automation_rule_created',
      target: @rule
    )
    render json: serialize(@rule), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @rule, :update?

    @rule.update!(automation_rule_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'automation_rule_updated',
      target: @rule,
      payload: { changes: audited_changes(@rule, automation_rule_params.keys) }
    )
    render json: serialize(@rule)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @rule, :destroy?

    @rule.destroy!
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'automation_rule_destroyed',
      target: @rule
    )
    head :no_content
  end

  private

  def automation_rule
    @rule = Current.account.crm_automation_rules.find(params[:id])
  end

  def automation_rule_params
    params.require(:automation_rule).permit(
      :name, :trigger_event, :action_type, :is_active, :position,
      :crm_pipeline_stage_id, action_config: {}
    )
  end

  def serialize(r)
    {
      id: r.id,
      name: r.name,
      trigger_event: r.trigger_event,
      action_type: r.action_type,
      action_config: r.action_config,
      is_active: r.is_active,
      position: r.position,
      crm_pipeline_stage_id: r.crm_pipeline_stage_id
    }
  end

  def audited_changes(record, keys)
    keys.map(&:to_s).each_with_object({}) do |key, changes|
      next unless record.saved_changes.key?(key)

      changes[key] = {
        from: record.saved_changes[key].first,
        to: record.saved_changes[key].last
      }
    end
  end
end
