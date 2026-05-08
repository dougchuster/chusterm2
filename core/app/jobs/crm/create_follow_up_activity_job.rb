class Crm::CreateFollowUpActivityJob < ApplicationJob
  queue_as :default

  def perform(deal_id, delay_hours: 24)
    deal = CrmDeal.find_by(id: deal_id)
    return unless deal&.status == 'open'

    deal.crm_activities.create!(
      account: deal.account,
      kind: 'follow_up',
      title: 'Follow-up agendado',
      priority: 'normal',
      due_at: delay_hours.hours.from_now
    )
  end
end
