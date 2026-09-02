class Api::V1::Accounts::Crm::PipelineStagesController < Api::V1::Accounts::Crm::BaseController
  before_action :pipeline
  before_action :stage, only: [:update, :destroy, :purge, :restore]

  def index
    authorize @pipeline, :index?

    @stages = @pipeline.crm_pipeline_stages.active.ordered
    # Princípio 11 (Kommo "Automatize"): automação visível onde acontece —
    # contagem agregada de regras ativas por etapa (1 query)
    automation_counts = CrmAutomationRule.active
                                         .where(crm_pipeline_stage_id: @stages.map(&:id))
                                         .group(:crm_pipeline_stage_id).count
    render json: @stages.map { |s| serialize_stage(s, automations_count: automation_counts.fetch(s.id, 0)) }
  end

  def create
    authorize @pipeline, :create?

    @stage = @pipeline.crm_pipeline_stages.create!(stage_create_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'pipeline_stage_created',
      target: @stage,
      payload: { pipeline_id: @pipeline.id }
    )
    render json: serialize_stage(@stage), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @pipeline, :update?

    @stage.update!(stage_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'pipeline_stage_updated',
      target: @stage,
      payload: { changes: audited_changes(@stage, stage_params.keys) }
    )
    render json: serialize_stage(@stage)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @pipeline, :destroy?

    @stage.archive!
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'pipeline_stage_archived',
      target: @stage,
      payload: { pipeline_id: @pipeline.id }
    )
    head :no_content
  end

  def archived
    authorize @pipeline, :index?

    @stages = @pipeline.crm_pipeline_stages.archived.ordered
    render json: @stages.map { |s| serialize_stage(s) }
  end

  def purge
    authorize @pipeline, :destroy?

    deals_count = @stage.crm_deals.count
    if deals_count.positive?
      render json: {
        error: "Etapa possui #{deals_count} deal(s) associado(s). Mova-os para outra etapa antes de deletar.",
        deals_count: deals_count
      }, status: :unprocessable_entity
      return
    end

    @stage.destroy!
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'pipeline_stage_purged',
      target: @stage,
      payload: { pipeline_id: @pipeline.id }
    )
    head :no_content
  end

  def restore
    authorize @pipeline, :update?

    @stage.restore!
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'pipeline_stage_restored',
      target: @stage,
      payload: { pipeline_id: @pipeline.id }
    )
    render json: serialize_stage(@stage)
  end

  private

  def pipeline
    @pipeline = Current.account.crm_pipelines.find(params[:pipeline_id])
  end

  def stage
    @stage = @pipeline.crm_pipeline_stages.find(params[:id])
  end

  def stage_params
    params.require(:stage).permit(:wip_limit, :name, :slug, :position, :probability_pct, :expected_duration_hours, :color, required_fields: {})
  end

  def stage_create_params
    permitted = stage_params
    permitted[:position] = next_stage_position if permitted[:position].blank?
    permitted.merge(account: Current.account)
  end

  def next_stage_position
    (@pipeline.crm_pipeline_stages.maximum(:position) || -1) + 1
  end

  def serialize_stage(stage, automations_count: nil)
    {
      id: stage.id,
      pipeline_id: stage.crm_pipeline_id,
      name: stage.name,
      slug: stage.slug,
      position: stage.position,
      probability_pct: stage.probability_pct,
      expected_duration_hours: stage.expected_duration_hours,
      wip_limit: stage.wip_limit,
      color: stage.color,
      required_fields: stage.required_fields,
      active_automations_count: automations_count || CrmAutomationRule.active.for_stage(stage.id).count
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
