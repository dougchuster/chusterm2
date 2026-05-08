# frozen_string_literal: true

# Resets Dra. Juliana's inbox conversations and also clears Evolution's
# Chatwoot conversation cache. Without the Evolution cleanup, new WhatsApp
# messages can be posted to deleted Chatwoot display IDs and disappear with 404.
#
# Usage:
#   docker cp core/scripts/captain/reset_dra_juliana_conversations.rb chusterm-core-1:/tmp/reset_dra_juliana_conversations.rb
#   docker exec chusterm-core-1 bundle exec rails runner /tmp/reset_dra_juliana_conversations.rb
#
# Optional:
#   ASSISTANT_ID=4 DRY_RUN=true bundle exec rails runner ...

require 'json'
require 'pg'
require 'redis'

assistant_id = ENV.fetch('ASSISTANT_ID', '4').to_i
dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', 'false'))

assistant = Captain::Assistant.find(assistant_id)
captain_inboxes = CaptainInbox.where(captain_assistant_id: assistant.id).includes(:inbox)
raise "No inbox linked to assistant #{assistant.id}" if captain_inboxes.blank?

inbox_ids = captain_inboxes.pluck(:inbox_id)
conversation_records = Conversation.where(inbox_id: inbox_ids).includes(:contact, :messages, :captain_conversation_state).order(:id).to_a
conversation_ids = conversation_records.map(&:id)
display_ids = conversation_records.map(&:display_id).uniq

phones = conversation_records.filter_map do |conversation|
  phone = conversation.contact&.phone_number.to_s.gsub(/\D/, '')
  "#{phone}@s.whatsapp.net" if phone.present?
end.uniq

backup = conversation_records.map do |conversation|
  {
    conversation_id: conversation.id,
    display_id: conversation.display_id,
    inbox_id: conversation.inbox_id,
    contact_id: conversation.contact_id,
    contact_name: conversation.contact&.name,
    phone: conversation.contact&.phone_number,
    status: conversation.status,
    messages: conversation.messages.order(:created_at).map do |message|
      {
        id: message.id,
        message_type: message.message_type,
        sender_type: message.sender_type,
        content: message.content,
        source_id: message.source_id,
        created_at: message.created_at
      }
    end
  }
end

FileUtils.mkdir_p(Rails.root.join('tmp', 'resets'))
backup_path = Rails.root.join('tmp', 'resets', "dra_juliana_conversations_reset_#{Time.current.strftime('%Y%m%d%H%M%S')}.json")
File.write(backup_path, JSON.pretty_generate(backup)) unless dry_run

evolution_uri = ENV.fetch('EVOLUTION_DATABASE_URL', 'postgresql://chusterm:chusterm_pass@postgres:5432/evolution_api')
evolution_redis_url = ENV.fetch('EVOLUTION_REDIS_URL', 'redis://:chusterm_redis_pass@redis:6379/3')
redis_prefix = ENV.fetch('EVOLUTION_REDIS_PREFIX', 'evolution')

evolution_rows_cleared = 0
redis_keys_deleted = []

unless dry_run || display_ids.blank?
  PG.connect(evolution_uri) do |connection|
    result = connection.exec_params(
      <<~SQL.squish,
        UPDATE "Message"
        SET "chatwootConversationId" = NULL,
            "chatwootMessageId" = NULL,
            "chatwootContactInboxSourceId" = NULL
        WHERE "chatwootConversationId" = ANY($1::int[])
      SQL
      ["{#{display_ids.join(',')}}"]
    )
    evolution_rows_cleared = result.cmd_tuples
  end

  redis = Redis.new(url: evolution_redis_url)
  redis.scan_each(match: "#{redis_prefix}*createConversation*") do |key|
    value = redis.get(key).to_s
    should_delete = display_ids.map(&:to_s).include?(value) || phones.any? { |phone| key.include?(phone) }
    next unless should_delete

    redis.del(key)
    redis_keys_deleted << key
  end

  Conversation.transaction do
    CaptainConversationState.where(conversation_id: conversation_ids).destroy_all
    Message.where(conversation_id: conversation_ids).find_each(&:destroy!)
    Conversation.where(id: conversation_ids).find_each(&:destroy!)
  end
end

summary = {
  dry_run: dry_run,
  assistant_id: assistant.id,
  assistant_name: assistant.name,
  inbox_ids: inbox_ids,
  conversations: conversation_records.size,
  display_ids: display_ids,
  phones: phones,
  backup_path: dry_run ? nil : backup_path.to_s,
  evolution_rows_cleared: evolution_rows_cleared,
  redis_keys_deleted: redis_keys_deleted,
  remaining_conversations: Conversation.where(inbox_id: inbox_ids).count,
  remaining_states: CaptainConversationState.joins(:conversation).where(conversations: { inbox_id: inbox_ids }).count
}

puts summary.to_json
