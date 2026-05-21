class Crm::ChannelPipelineProvisioner
  STAGE_TEMPLATES = [
    { name: 'Novo atendimento', slug: 'novo-atendimento', position: 0, probability_pct: 5, color: '#64748b' },
    { name: 'Triagem IA', slug: 'triagem-ia', position: 1, probability_pct: 10, color: '#8b5cf6' },
    { name: 'Qualificado', slug: 'qualificado', position: 2, probability_pct: 30, color: '#3b82f6' },
    { name: 'Consulta/Reunião', slug: 'consulta-reuniao', position: 3, probability_pct: 45, color: '#06b6d4' },
    { name: 'Documentos solicitados', slug: 'documentos-solicitados', position: 4, probability_pct: 55, color: '#f59e0b' },
    { name: 'Em análise jurídica', slug: 'em-analise-juridica', position: 5, probability_pct: 65, color: '#f97316' },
    { name: 'Proposta enviada', slug: 'proposta-enviada', position: 6, probability_pct: 75, color: '#ec4899' },
    { name: 'Contrato fechado', slug: 'contrato-fechado', position: 7, probability_pct: 100, color: '#10b981' },
    { name: 'Perdido/Arquivado', slug: 'perdido-arquivado', position: 8, probability_pct: 0, color: '#ef4444' }
  ].freeze

  def self.perform_for_account(account, actor: nil, move_existing_deals: false)
    account.inboxes.where(channel_type: Inbox::CRM_PIPELINE_CHANNEL_TYPES).find_each.filter_map do |inbox|
      new(
        account: account,
        inbox: inbox,
        actor: actor,
        move_existing_deals: move_existing_deals
      ).perform
    end
  end

  def initialize(account:, inbox:, actor: nil, move_existing_deals: false)
    @account = account || inbox&.account
    @inbox = inbox
    @actor = actor
    @move_existing_deals = move_existing_deals
  end

  def perform
    return if @account.blank? || @inbox.blank?

    existing = @account.crm_pipelines.active.find_by(inbox_id: @inbox.id)
    return ensure_pipeline_ready(existing) if existing

    ActiveRecord::Base.transaction do
      pipeline = create_pipeline
      ensure_stages(pipeline)
      move_existing_deals!(pipeline) if @move_existing_deals
      log_pipeline_created(pipeline)
      pipeline
    end
  end

  private

  def ensure_pipeline_ready(pipeline)
    ActiveRecord::Base.transaction do
      ensure_stages(pipeline)
      move_existing_deals!(pipeline) if @move_existing_deals
    end
    pipeline
  end

  def create_pipeline
    @account.crm_pipelines.create!(
      inbox: @inbox,
      name: "Kanban - #{@inbox.name}",
      slug: "canal-#{@inbox.id}",
      kind: source_pipeline&.kind.presence || 'legal_intake',
      is_default: false,
      position: next_position,
      scoring_config: source_pipeline&.scoring_config || {}
    )
  end

  def ensure_stages(pipeline)
    return if pipeline.crm_pipeline_stages.active.exists?

    stage_templates.each do |attrs|
      pipeline.crm_pipeline_stages.create!(attrs.merge(account: @account))
    end
  end

  def stage_templates
    return STAGE_TEMPLATES unless source_pipeline&.crm_pipeline_stages&.active&.exists?

    source_pipeline.crm_pipeline_stages.active.ordered.map do |stage|
      {
        name: stage.name,
        slug: stage.slug,
        position: stage.position,
        probability_pct: stage.probability_pct,
        expected_duration_hours: stage.expected_duration_hours,
        color: stage.color
      }
    end
  end

  def source_pipeline
    @source_pipeline ||= begin
      @account.crm_pipelines.active.where(inbox_id: nil).find_by(is_default: true) ||
        @account.crm_pipelines.active.where(inbox_id: nil).default_first.first ||
        @account.crm_pipelines.active.default_first.first
    end
  end

  def next_position
    @account.crm_pipelines.maximum(:position).to_i + 1
  end

  def move_existing_deals!(pipeline)
    first_stage = pipeline.crm_pipeline_stages.active.ordered.first
    return unless first_stage

    @account.crm_deals.where(inbox_id: @inbox.id).where.not(crm_pipeline_id: pipeline.id).find_each do |deal|
      current_slug = deal.crm_pipeline_stage&.slug
      stage = pipeline.crm_pipeline_stages.active.find_by(slug: current_slug) || first_stage
      deal.update!(crm_pipeline: pipeline, crm_pipeline_stage: stage)
      Crm::AuditLogger.log(
        account: @account,
        actor: @actor,
        action: 'deal_channel_pipeline_aligned',
        target: deal,
        payload: { inbox_id: @inbox.id, pipeline_id: pipeline.id }
      )
    end
  end

  def log_pipeline_created(pipeline)
    Crm::AuditLogger.log(
      account: @account,
      actor: @actor,
      action: 'channel_pipeline_created',
      target: pipeline,
      payload: { inbox_id: @inbox.id, inbox_name: @inbox.name }
    )
  end
end
