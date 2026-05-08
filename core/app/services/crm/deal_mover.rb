class Crm::DealMover
  def initialize(deal:, stage_id:, actor: nil)
    @deal = deal
    @stage_id = stage_id
    @actor = actor
  end

  def perform
    from_stage_id = @deal.crm_pipeline_stage_id
    validate_required_fields!
    @deal.update!(crm_pipeline_stage_id: target_stage.id)
    Crm::AuditLogger.log(
      account: @deal.account,
      actor: @actor,
      action: 'deal_stage_changed',
      target: @deal,
      payload: { from_stage_id: from_stage_id, to_stage_id: target_stage.id }
    )
    Crm::StageAutomation.new(deal: @deal.reload, actor: @actor).perform
    @deal
  end

  private

  def validate_required_fields!
    missing_fields = required_field_keys.select { |field| missing_required_field?(field) }
    return if missing_fields.blank?

    raise ArgumentError, "Campos obrigatorios ausentes para a etapa #{target_stage.name}: #{missing_fields.join(', ')}"
  end

  def required_field_keys
    fields = target_stage.required_fields
    case fields
    when Array
      fields
    when Hash
      configured = fields['fields'] || fields[:fields] || fields['required_fields'] || fields[:required_fields]
      return Array(configured).map(&:to_s) if configured.present?

      fields.select { |_key, value| ActiveModel::Type::Boolean.new.cast(value) }.keys
    else
      []
    end.map(&:to_s).compact_blank
  end

  def missing_required_field?(field)
    if @deal.respond_to?(field)
      @deal.public_send(field).blank?
    else
      @deal.custom_fields.to_h[field].blank?
    end
  end

  def target_stage
    @target_stage ||= begin
      stage = @deal.account.crm_pipeline_stages.find(@stage_id)
      unless stage.crm_pipeline_id == @deal.crm_pipeline_id
        raise ArgumentError, 'Stage does not belong to the deal pipeline'
      end

      stage
    end
  end
end
