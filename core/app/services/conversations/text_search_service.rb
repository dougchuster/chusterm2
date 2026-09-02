class Conversations::TextSearchService
  SEARCHABLE_MESSAGE_TYPES = %w[incoming outgoing].freeze
  MIN_QUERY_LENGTH = 3
  MAX_QUERY_LENGTH = 120

  def initialize(conversations, query)
    @conversations = conversations
    @query = query.to_s.strip
  end

  def perform
    return conversations if query.blank?
    return conversations.where(display_id: normalized_display_id) if exact_display_id_query?
    return conversations.none unless query.length.between?(MIN_QUERY_LENGTH, MAX_QUERY_LENGTH)

    conversations.where(search_condition, search: search_pattern, message_types: searchable_message_types)
  end

  private

  attr_reader :conversations, :query

  def exact_display_id_query?
    query.match?(/\A#\d+\z/) || query.match?(/\A\d{1,2}\z/)
  end

  def normalized_display_id
    query.delete_prefix('#').to_i
  end

  def search_condition
    [conversation_condition, contact_condition, message_condition].map { |condition| "(#{condition})" }.join(' OR ')
  end

  def conversation_condition
    <<~SQL.squish
      CAST(conversations.display_id AS TEXT) ILIKE :search
      OR conversations.identifier ILIKE :search
      OR conversations.additional_attributes ->> 'mail_subject' ILIKE :search
    SQL
  end

  def contact_condition
    <<~SQL.squish
      EXISTS (
        SELECT 1
        FROM contacts
        WHERE contacts.id = conversations.contact_id
          AND (
            contacts.name ILIKE :search
            OR contacts.email ILIKE :search
            OR contacts.phone_number ILIKE :search
            OR contacts.identifier ILIKE :search
          )
      )
    SQL
  end

  def message_condition
    <<~SQL.squish
      EXISTS (
        SELECT 1
        FROM messages
        WHERE messages.conversation_id = conversations.id
          AND messages.account_id = conversations.account_id
          AND messages.message_type IN (:message_types)
          AND messages.content ILIKE :search
      )
    SQL
  end

  def search_pattern
    "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
  end

  def searchable_message_types
    Message.message_types.values_at(*SEARCHABLE_MESSAGE_TYPES)
  end
end
