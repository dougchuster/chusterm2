class Api::V1::Accounts::Crm::ChecklistTemplatesController < Api::V1::Accounts::Crm::BaseController
  before_action :template, only: [:update, :destroy]

  def index
    authorize CrmChecklistTemplate, :index?

    @templates = Current.account.crm_checklist_templates.active.ordered
    render json: @templates.map { |t| serialize(t) }
  end

  def create
    authorize CrmChecklistTemplate, :create?

    @template = Current.account.crm_checklist_templates.create!(template_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'checklist_template_created',
      target: @template
    )
    render json: serialize(@template), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @template, :update?

    @template.update!(template_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'checklist_template_updated',
      target: @template,
      payload: { changes: audited_changes(@template, template_params.keys) }
    )
    render json: serialize(@template)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @template, :destroy?

    @template.update!(archived_at: Time.current)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'checklist_template_archived',
      target: @template
    )
    head :no_content
  end

  private

  def template
    @template = Current.account.crm_checklist_templates.find(params[:id])
  end

  def template_params
    params.require(:checklist_template).permit(
      :name, :case_type, :legal_area, :position,
      items: [:key, :title, :kind, :required]
    )
  end

  def serialize(t)
    { id: t.id, name: t.name, case_type: t.case_type, legal_area: t.legal_area,
      items: t.items, position: t.position }
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
