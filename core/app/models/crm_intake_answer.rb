class CrmIntakeAnswer < ApplicationRecord
  include AccountAssociationScoped

  belongs_to :account
  belongs_to :crm_deal

  validates :account, :crm_deal, :question_key, :question_text, presence: true
  validates_same_account_for :crm_deal
end
