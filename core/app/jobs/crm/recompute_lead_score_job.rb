class Crm::RecomputeLeadScoreJob < ApplicationJob
  queue_as :default

  def perform(deal_id)
    deal = CrmDeal.find_by(id: deal_id)
    return unless deal

    Crm::LeadScoreCalculator.new(deal).perform
  end
end
