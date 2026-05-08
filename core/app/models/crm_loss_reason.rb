class CrmLossReason < ApplicationRecord
  belongs_to :account

  validates :account, :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :account_id }

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(position: :asc) }
end
