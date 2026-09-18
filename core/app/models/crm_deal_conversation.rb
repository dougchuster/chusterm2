class CrmDealConversation < ApplicationRecord
  include AccountAssociationScoped

  belongs_to :account
  belongs_to :crm_deal
  belongs_to :conversation

  validates :crm_deal_id, uniqueness: { scope: :conversation_id }
  validates_same_account_for :crm_deal, :conversation
end
