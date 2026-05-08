class Captain::Playbook < ApplicationRecord
  self.table_name = 'captain_playbooks'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant', optional: true

  validates :name, presence: true
  validates :escalation_rules, jsonb_attributes_length: true
  validates :metadata, jsonb_attributes_length: true
  validate :required_fields_length
  validate :assistant_belongs_to_account

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }
  scope :for_legal_area, lambda { |legal_area|
    return all if legal_area.blank?

    normalized_area = legal_area.to_s.downcase
    where('legal_area IS NULL OR legal_area = ? OR LOWER(legal_area) = ?', '', normalized_area)
  }

  def context_payload
    {
      id: id,
      name: name,
      legal_area: legal_area,
      case_type: case_type,
      objective: objective,
      instructions: instructions,
      required_fields: required_fields,
      escalation_rules: escalation_rules
    }.compact
  end

  private

  def assistant_belongs_to_account
    return if assistant.blank? || assistant.account_id == account_id

    errors.add(:assistant_id, 'must belong to the same account as the playbook')
  end

  def required_fields_length
    Array(required_fields).each do |field|
      errors.add(:required_fields, "#{field} length should be < 1500") if field.to_s.length > 1500
    end
  end
end
