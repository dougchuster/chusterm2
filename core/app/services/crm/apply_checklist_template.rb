class Crm::ApplyChecklistTemplate
  def initialize(deal:, actor: nil)
    @deal = deal
    @actor = actor
  end

  # Mesmo critério usado pelo cofre de documentos para o "X de Y" do negócio.
  def self.best_template_for(deal)
    new(deal: deal).send(:find_best_template)
  end

  def perform
    template = find_best_template
    return unless template

    template.items.each do |item|
      @deal.crm_activities.create!(
        account: @deal.account,
        kind: activity_kind_for(item['kind']),
        title: item['title'],
        priority: item.fetch('required', false) ? 'alta' : 'normal',
        due_at: due_at_for(item),
        assignee_id: @deal.assignee_id,
        owner_id: @deal.owner_id,
        contact_id: @deal.contact_id,
        conversation_id: @deal.conversation_id
      )
    end

    Crm::AuditLogger.log(
      account: @deal.account,
      actor: @actor,
      action: 'checklist_applied',
      target: @deal,
      payload: { template_id: template.id, items_count: template.items.size }
    )
  end

  private

  def find_best_template
    scope = @deal.account.crm_checklist_templates.active.ordered
    scope.find_by(case_type: @deal.case_type, legal_area: @deal.legal_area) ||
      scope.find_by(case_type: @deal.case_type, legal_area: nil) ||
      scope.find_by(case_type: nil, legal_area: @deal.legal_area) ||
      scope.find_by(case_type: nil, legal_area: nil)
  end

  def due_at_for(item)
    hours = item['due_in_hours'].presence || item['due_hours'].presence
    hours ||= item['due_in_days'].to_i * 24 if item['due_in_days'].present?
    hours = hours.to_i
    hours = item.fetch('required', false) ? 24 : 72 if hours <= 0
    Time.current + hours.hours
  end

  def activity_kind_for(kind)
    mapped_kind = {
      'task' => 'follow_up',
      'document' => 'solicitacao_documentos'
    }.fetch(kind.to_s, kind)

    mapped_kind = mapped_kind.to_s
    CrmActivity::KINDS.include?(mapped_kind) ? mapped_kind : 'follow_up'
  end
end
