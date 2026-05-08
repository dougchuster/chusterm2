class CrmIntakeAnswer < ApplicationRecord
  belongs_to :account
  belongs_to :crm_deal

  validates :account, :crm_deal, :question_key, :question_text, presence: true
end
