# frozen_string_literal: true

# Campo customizado definido por pack (ou criado pela conta). `key` é o nome
# persistido em crm_deals.custom_fields; `field_type` dirige o renderer do
# frontend universal (text/select/date/number/boolean).
class CrmFieldDefinition < ApplicationRecord
  include AccountAssociationScoped

  FIELD_TYPES = %w[text textarea number currency date datetime boolean select multiselect].freeze

  belongs_to :account

  validates :key, presence: true, uniqueness: { scope: :account_id }
  validates :label, :field_type, presence: true
  validates :field_type, inclusion: { in: FIELD_TYPES }

  scope :active, -> { where(active: true).order(position: :asc) }
  scope :for_deals, -> { where(applies_to: 'deal') }
end
