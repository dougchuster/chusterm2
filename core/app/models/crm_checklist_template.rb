class CrmChecklistTemplate < ApplicationRecord
  belongs_to :account

  validates :account, :name, presence: true

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(position: :asc, name: :asc) }
  scope :for_case_type, ->(ct) { where(case_type: ct) }
  scope :for_legal_area, ->(la) { where(legal_area: la) }
end
