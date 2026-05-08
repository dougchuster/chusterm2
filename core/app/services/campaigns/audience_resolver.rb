class Campaigns::AudienceResolver
  SUPPORTED_SEGMENT_TYPES = %w[CustomFilter ContactSegment Segment].freeze
  SUPPORTED_SOURCE_LIST_TYPES = %w[SourceList ContactList ImportedList].freeze

  def initialize(account, audience, user = nil)
    @account = account
    @audience = audience
    @user = user
  end

  attr_reader :account, :audience, :user

  def contacts
    eligible_contacts
  end

  def count
    contacts.count
  end

  def summary
    scope = contacts
    {
      total: scope.count,
      with_phone_number: scope.where.not(phone_number: [nil, '']).count,
      without_phone_number: scope.where(phone_number: [nil, '']).count,
      with_email: scope.where.not(email: [nil, '']).count,
      without_email: scope.where(email: [nil, '']).count,
      opted_out: opted_out_contacts.count,
      blocked: blocked_contacts.count,
      labels: label_titles,
      segments: segment_names,
      source_lists: source_lists
    }
  end

  def preview(limit: 10)
    {
      summary: summary,
      contacts: contacts.limit(limit).map { |contact| preview_contact(contact) }
    }
  end

  private

  def normalized_audience
    Array(audience).map(&:with_indifferent_access)
  end

  def audience_contact_ids
    (label_contact_ids + segment_contact_ids + source_list_contact_ids).compact.uniq
  end

  def audience_contacts
    ids = audience_contact_ids
    return account.contacts.none if ids.blank?

    account.contacts.where(id: ids)
  end

  def eligible_contacts
    audience_contacts.where(blocked: false).where(
      "COALESCE(contacts.additional_attributes ->> 'campaign_opt_out', 'false') NOT IN (?)",
      %w[true 1 yes sim]
    )
  end

  def opted_out_contacts
    audience_contacts.where(
      "COALESCE(contacts.additional_attributes ->> 'campaign_opt_out', 'false') IN (?)",
      %w[true 1 yes sim]
    )
  end

  def blocked_contacts
    audience_contacts.where(blocked: true)
  end

  def label_contact_ids
    labels = label_titles
    return [] if labels.blank?

    account.contacts.tagged_with(labels, any: true).pluck(:id)
  end

  def segment_contact_ids
    segments.flat_map do |segment|
      next [] if segment.query.blank?

      Contacts::FilterService.new(account, resolved_user, segment.query.with_indifferent_access).perform[:contacts].pluck(:id)
    rescue CustomExceptions::CustomFilter::InvalidAttribute,
           CustomExceptions::CustomFilter::InvalidOperator,
           CustomExceptions::CustomFilter::InvalidQueryOperator,
           CustomExceptions::CustomFilter::InvalidValue => e
      Rails.logger.warn("[Campaign Audience] Ignoring invalid segment #{segment.id}: #{e.message}")
      []
    end
  end

  def source_list_contact_ids
    lists = source_lists
    return [] if lists.blank?

    account.contacts.where(
      'LOWER(contacts.additional_attributes ->> ?) IN (?)',
      'source_list',
      lists.map(&:downcase)
    ).pluck(:id)
  end

  def labels
    @labels ||= account.labels.where(id: label_ids)
  end

  def label_ids
    normalized_audience.select { |item| item[:type] == 'Label' }.pluck(:id)
  end

  def label_titles
    @label_titles ||= labels.pluck(:title)
  end

  def segments
    @segments ||= account.custom_filters.contact.where(id: segment_ids)
  end

  def segment_ids
    normalized_audience.select { |item| SUPPORTED_SEGMENT_TYPES.include?(item[:type]) }.pluck(:id)
  end

  def segment_names
    @segment_names ||= segments.pluck(:name)
  end

  def source_lists
    @source_lists ||= normalized_audience
                      .select { |item| SUPPORTED_SOURCE_LIST_TYPES.include?(item[:type]) }
                      .filter_map { |item| item[:id].presence || item[:name].presence }
                      .map(&:to_s)
                      .uniq
  end

  def preview_contact(contact)
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      relationship_status: contact.try(:relationship_status),
      lifecycle_stage: contact.try(:lifecycle_stage),
      campaign_opt_out: contact.campaign_opted_out?,
      blocked: contact.blocked?,
      source_list: contact.additional_attributes&.[]('source_list') || contact.additional_attributes&.[](:source_list),
      labels: contact.label_list.to_a
    }
  end

  def resolved_user
    user || account.users.first
  end
end
