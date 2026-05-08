class Api::V1::Accounts::Crm::PipelinesController < Api::V1::Accounts::Crm::BaseController
  before_action :pipeline, only: [:update, :destroy, :purge, :restore]

  def index
    authorize CrmPipeline, :index?

    @pipelines = Current.account.crm_pipelines.active.default_first
                         .includes(:crm_pipeline_stages)
    render json: serialize_pipelines(@pipelines)
  end

  def create
    authorize CrmPipeline, :create?

    @pipeline = Current.account.crm_pipelines.create!(pipeline_params)
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'pipeline_created', target: @pipeline)
    render json: serialize_pipeline(@pipeline), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @pipeline, :update?

    @pipeline.update!(pipeline_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'pipeline_updated',
      target: @pipeline,
      payload: { changes: audited_changes(@pipeline, pipeline_params.keys) }
    )
    render json: serialize_pipeline(@pipeline)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @pipeline, :destroy?

    @pipeline.archive!
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'pipeline_archived', target: @pipeline)
    head :no_content
  end

  def archived
    authorize CrmPipeline, :index?

    @pipelines = Current.account.crm_pipelines.archived.default_first
                         .includes(:crm_pipeline_stages)
    render json: serialize_pipelines(@pipelines)
  end

  def purge
    authorize @pipeline, :destroy?

    deals_count = @pipeline.crm_deals.count
    if deals_count.positive?
      render json: {
        error: "Pipeline possui #{deals_count} deal(s) associado(s). Mova-os para outro pipeline antes de deletar.",
        deals_count: deals_count
      }, status: :unprocessable_entity
      return
    end

    @pipeline.destroy!
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'pipeline_purged', target: @pipeline)
    head :no_content
  end

  def restore
    authorize @pipeline, :update?

    @pipeline.restore!
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'pipeline_restored', target: @pipeline)
    render json: serialize_pipeline(@pipeline)
  end

  private

  def pipeline
    @pipeline = Current.account.crm_pipelines.find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :slug, :kind, :is_default, :position, scoring_config: {})
  end

  def serialize_pipelines(pipelines)
    pipelines.map { |p| serialize_pipeline(p) }
  end

  def serialize_pipeline(pipeline)
    {
      id: pipeline.id,
      name: pipeline.name,
      slug: pipeline.slug,
      kind: pipeline.kind,
      is_default: pipeline.is_default,
      position: pipeline.position,
      scoring_config: pipeline.scoring_config || {},
      stages: pipeline.crm_pipeline_stages.active.ordered.map { |s| serialize_stage(s) }
    }
  end

  def serialize_stage(stage)
    {
      id: stage.id,
      name: stage.name,
      slug: stage.slug,
      position: stage.position,
      probability_pct: stage.probability_pct,
      expected_duration_hours: stage.expected_duration_hours,
      color: stage.color
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
