class CrmLeadScore < ApplicationRecord
  belongs_to :account
  belongs_to :crm_deal

  validates :account, :crm_deal, :calculated_at, presence: true

  before_validation :compute_total, on: :create

  private

  def compute_total
    sum = [fit_score, urgency_score, economic_score, documents_score,
           clarity_score, engagement_score, payment_capacity_score, conflict_score].sum
    self.total_score = sum.to_i.clamp(0, 100) if total_score.blank? || (total_score.to_i.zero? && sum.positive?)
    self.classification ||= classification_for(total_score)
  end

  def classification_for(total)
    CrmScoreClassification.classify(total)
  end
end
