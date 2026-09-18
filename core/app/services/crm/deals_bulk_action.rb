# B14: ação em lote sobre deals — a lógica por-deal mora aqui para ser
# reutilizada pelo controller (lote pequeno, síncrono) e pelo
# Crm::DealsBulkActionJob (select_all sobre o filtro inteiro, assíncrono).
class Crm::DealsBulkAction
  ALLOWED_ACTIONS = %w[move archive discard mark_base_client update_source
                       assign_owner apply_label destroy delete purge].freeze

  DESTROY_ACTIONS = %w[destroy delete purge].freeze

  ACTION_HANDLERS = {
    'move' => :move_deal,
    'archive' => :archive_deal,
    'discard' => :discard_deal,
    'mark_base_client' => :mark_base_client,
    'update_source' => :update_source,
    'assign_owner' => :assign_owner,
    'apply_label' => :apply_label
  }.freeze

  def initialize(account:, user:, action:, params: {})
    @account = account
    @user = user
    @action = action.to_s
    @params = params.to_h.with_indifferent_access
    raise ArgumentError, 'Ação em lote inválida.' unless ALLOWED_ACTIONS.include?(@action)
  end

  def self.destroy_action?(action)
    DESTROY_ACTIONS.include?(action.to_s)
  end

  def perform(scope)
    result = { requested: scope.count, processed: 0, failed: [] }

    scope.find_each do |deal|
      process_deal!(deal)
      result[:processed] += 1
    rescue StandardError => e
      result[:failed] << { id: deal.id, error: e.message }
    end

    result
  end

  def process_deal!(deal)
    handler = ACTION_HANDLERS[@action]
    handler ||= :destroy_deal if DESTROY_ACTIONS.include?(@action)
    send(handler, deal)
  end

  def mark_base_client(deal)
    deal.mark_base_client!(note: @params[:note], actor: @user)
  end

  private

  def move_deal(deal)
    stage = @account.crm_pipeline_stages.find(@params[:stage_id])
    Crm::DealMover.new(deal: deal, stage_id: stage.id, actor: @user).perform
  end

  def archive_deal(deal)
    deal.archive!(
      reason: @params[:reason].presence || 'arquivado',
      note: @params[:note],
      operational_status: @params[:operational_status].presence || 'archived',
      actor: @user
    )
  end

  def discard_deal(deal)
    deal.discard!(
      reason: normalized_disposition_reason(@params[:reason] || @params[:disposition_reason]),
      note: @params[:note],
      actor: @user
    )
  end

  def update_source(deal)
    deal.update!(source: @params[:source], source_detail: @params[:source_detail])
    Crm::AuditLogger.log(
      account: @account,
      actor: @user,
      action: 'deal_source_updated',
      target: deal,
      payload: { source: @params[:source], source_detail: @params[:source_detail] }
    )
  end

  def assign_owner(deal)
    owner = @params[:owner_id].present? ? @account.users.find(@params[:owner_id]) : nil
    Crm::DealOwnerAssigner.new(
      deal: deal,
      owner: owner,
      actor: @user,
      sync_assignee: :always,
      sync_contact: true,
      contact_source: 'manual'
    ).perform
    Crm::AuditLogger.log(
      account: @account,
      actor: @user,
      action: 'deal_owner_assigned',
      target: deal,
      payload: { owner_id: owner&.id }
    )
  end

  def destroy_deal(deal)
    Crm::AuditLogger.log(
      account: @account,
      actor: @user,
      action: 'deal_destroyed',
      target: deal,
      payload: { bulk: true }
    )
    deal.destroy!
  end

  def apply_label(deal)
    title = @params[:label_title].to_s.strip
    raise ArgumentError, 'Etiqueta inválida.' if title.blank?

    label = @account.labels.find_by(title: title) || @account.labels.find_by(slug: title)
    title = label.title if label

    [deal.contact, deal.conversation].compact.each do |record|
      current_titles = record.label_list.to_a
      next if current_titles.include?(title)

      record.update!(label_list: current_titles + [title])
    end

    Crm::AuditLogger.log(
      account: @account,
      actor: @user,
      action: 'deal_label_applied',
      target: deal,
      payload: { label_title: title }
    )
  end

  def normalized_disposition_reason(value)
    reason = value.to_s.presence || 'invalid'
    allowed = %w[invalid spam duplicated no_lead archived]
    allowed.include?(reason) ? reason : 'invalid'
  end
end
