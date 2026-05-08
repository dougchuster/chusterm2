class Crm::CadenceConditionEvaluator
  OPERATORS = %w[eq not_eq in not_in present blank gt gte lt lte].freeze

  def initialize(deal:, contact:, conditions:)
    @deal = deal
    @contact = contact
    @conditions = Array(conditions).filter_map { |condition| normalize(condition) }
  end

  def matches?
    return true if conditions.blank?

    conditions.all? { |condition| condition_matches?(condition) }
  end

  private

  attr_reader :deal, :contact, :conditions

  def normalize(condition)
    attrs = condition.to_h.with_indifferent_access
    field = attrs[:field].presence
    operator = attrs[:operator].presence || 'eq'
    return if field.blank? || OPERATORS.exclude?(operator)

    { field: field, operator: operator, value: attrs[:value] }
  end

  def condition_matches?(condition)
    actual = value_for(condition[:field])
    expected = condition[:value]

    case condition[:operator]
    when 'eq' then compare(actual, expected).zero?
    when 'not_eq' then !compare(actual, expected).zero?
    when 'in' then Array(expected).map(&:to_s).include?(actual.to_s)
    when 'not_in' then Array(expected).map(&:to_s).exclude?(actual.to_s)
    when 'present' then actual.present?
    when 'blank' then actual.blank?
    when 'gt' then numeric(actual) > numeric(expected)
    when 'gte' then numeric(actual) >= numeric(expected)
    when 'lt' then numeric(actual) < numeric(expected)
    when 'lte' then numeric(actual) <= numeric(expected)
    else false
    end
  end

  def value_for(field)
    case field.to_s
    when 'stage', 'stage_name' then deal.crm_pipeline_stage&.name
    when 'stage_slug' then deal.crm_pipeline_stage&.slug
    when 'status' then deal.status
    when 'legal_area' then deal.legal_area
    when 'case_type' then deal.case_type
    when 'urgency_level' then deal.urgency_level
    when 'score_total' then deal.score_total
    when 'relationship_status' then contact&.crm_relationship_status
    when 'lifecycle_stage' then contact&.crm_lifecycle_stage
    when 'has_phone' then contact&.phone_number.present?
    when 'campaign_opt_out' then contact&.campaign_opted_out?
    else deal_value(field) || contact_attribute(field)
    end
  end

  def deal_value(field)
    return deal.public_send(field) if deal.respond_to?(field)
  end

  def contact_attribute(field)
    contact&.additional_attributes&.[](field.to_s) || contact&.custom_attributes&.[](field.to_s)
  end

  def compare(actual, expected)
    return 0 if actual.to_s == expected.to_s

    actual.to_s <=> expected.to_s
  end

  def numeric(value)
    BigDecimal(value.to_s)
  rescue ArgumentError
    BigDecimal('0')
  end
end
