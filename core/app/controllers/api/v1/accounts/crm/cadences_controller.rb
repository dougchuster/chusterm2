class Api::V1::Accounts::Crm::CadencesController < Api::V1::Accounts::Crm::BaseController
  before_action :cadence, only: [:update, :destroy]

  def index
    authorize CrmCadence, :index?

    cadences = Current.account.crm_cadences.active.ordered.includes(:crm_cadence_steps)
    render json: cadences.map { |cadence| serialize(cadence) }
  end

  def create
    authorize CrmCadence, :create?

    cadence = nil
    ActiveRecord::Base.transaction do
      cadence = Current.account.crm_cadences.create!(cadence_params)
      sync_steps(cadence) if steps_param_present?
    end
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'cadence_created', target: cadence)
    render json: serialize(cadence.reload), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @cadence, :update?

    ActiveRecord::Base.transaction do
      @cadence.update!(cadence_params)
      sync_steps(@cadence) if steps_param_present?
    end
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'cadence_updated',
      target: @cadence,
      payload: { changes: audited_changes(@cadence, cadence_params.keys) }
    )
    render json: serialize(@cadence.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @cadence, :destroy?

    @cadence.archive!
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'cadence_archived', target: @cadence)
    head :no_content
  end

  def enroll_deal
    authorize CrmCadence, :create?

    cadence = Current.account.crm_cadences.find(params[:cadence_id])
    deal = Current.account.crm_deals.find(params[:deal_id])
    first_step = cadence.crm_cadence_steps.active.ordered.first

    enrollment = cadence.crm_cadence_enrollments.create!(
      account: Current.account,
      crm_deal: deal,
      current_step_position: first_step&.position || 0,
      next_step_at: first_step ? first_step.wait_hours.hours.from_now : nil
    )

    Crm::AuditLogger.log(
      account: Current.account, actor: Current.user,
      action: 'cadence_enrolled', target: deal,
      payload: { cadence_id: cadence.id, enrollment_id: enrollment.id }
    )

    render json: { enrollment_id: enrollment.id, status: enrollment.status }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def unenroll_deal
    authorize CrmCadence, :update?

    cadence = Current.account.crm_cadences.find(params[:cadence_id])
    deal = Current.account.crm_deals.find(params[:deal_id])

    enrollment = cadence.crm_cadence_enrollments.find_by(crm_deal: deal)
    return render json: { error: 'Inscricao nao encontrada' }, status: :not_found unless enrollment

    enrollment.cancel!

    Crm::AuditLogger.log(
      account: Current.account, actor: Current.user,
      action: 'cadence_unenrolled', target: deal,
      payload: { cadence_id: cadence.id }
    )

    render json: { status: 'cancelled' }
  end

  private

  def cadence
    @cadence = Current.account.crm_cadences.find(params[:id])
  end

  def cadence_params
    params.require(:cadence).permit(
      :name, :status, :channel, :starts_at, :position,
      audience_filter: {},
      enrollment_config: {}
    )
  end

  def step_params
    params.require(:cadence).permit(
      steps: [:id, :name, :position, :channel, :action_type, :wait_hours,
              :template_body, :is_active, action_config: {}]
    )[:steps] || []
  end

  def steps_param_present?
    params.require(:cadence).key?(:steps)
  end

  def sync_steps(cadence)
    retained_ids = step_params.each_with_index.filter_map do |attrs, index|
      step_attrs = attrs.to_h
      step_id = step_attrs.delete('id').presence
      step_attrs['position'] = index + 1 if step_attrs['position'].blank?
      step_attrs['account_id'] = Current.account.id

      step = if step_id
               cadence.crm_cadence_steps.find(step_id)
             else
               cadence.crm_cadence_steps.build
             end
      step.update!(step_attrs)
      step.id
    end

    cadence.crm_cadence_steps.where.not(id: retained_ids).destroy_all
  end

  def serialize(cadence)
    {
      id: cadence.id,
      name: cadence.name,
      status: cadence.status,
      channel: cadence.channel,
      starts_at: cadence.starts_at,
      position: cadence.position,
      audience_filter: cadence.audience_filter,
      enrollment_config: cadence.enrollment_config,
      steps: cadence.crm_cadence_steps.ordered.map { |step| serialize_step(step) },
      created_at: cadence.created_at,
      updated_at: cadence.updated_at
    }
  end

  def serialize_step(step)
    {
      id: step.id,
      name: step.name,
      position: step.position,
      channel: step.channel,
      action_type: step.action_type,
      wait_hours: step.wait_hours,
      template_body: step.template_body,
      action_config: step.action_config,
      is_active: step.is_active
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
