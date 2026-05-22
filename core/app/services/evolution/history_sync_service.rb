# frozen_string_literal: true

module Evolution
  class HistorySyncService
    DEFAULT_LIMIT = 50
    DEFAULT_CONTACT_LIMIT = 100

    def initialize(instance:, limit: DEFAULT_LIMIT, contact_limit: DEFAULT_CONTACT_LIMIT)
      @instance = instance
      @inbox = instance&.inbox
      @client = instance ? Evolution::Client.new(configuration: instance.configuration) : nil
      @limit = bounded(limit, DEFAULT_LIMIT, 1, 200)
      @contact_limit = bounded(contact_limit, DEFAULT_CONTACT_LIMIT, 1, 500)
      @imported = 0
      @scanned = 0
      @failed = 0
    end

    def perform
      return summary(status: 'skipped', reason: 'missing_instance_or_inbox') if @instance.blank? || @inbox.blank?

      remote_jids_for_sync.each { |remote_jid| sync_remote_jid(remote_jid) }

      summary(status: 'ok')
    end

    private

    def remote_jids_for_sync
      (known_remote_jids + discovered_remote_jids).compact_blank.uniq.first(@contact_limit)
    end

    def known_remote_jids
      contact_inboxes.flat_map { |contact_inbox| remote_jids_for(contact_inbox) }
    end

    def discovered_remote_jids
      payload = @client.find_chats(instance_name: @instance.instance_name, limit: @contact_limit)
      extract_entries(payload).filter_map { |entry| remote_jid_from_chat(entry) }.uniq
    rescue StandardError => e
      Rails.logger.warn({ component: 'evolution', action: 'chat_discovery_failed', instance_id: @instance.id, error: e.message }.to_json)
      []
    end

    def sync_remote_jid(remote_jid)
      payload = @client.find_messages(
        instance_name: @instance.instance_name,
        remote_jid: remote_jid,
        limit: @limit
      )

      entries_for(remote_jid, payload).first(@limit).each do |entry|
        process_entry(entry)
      end
    rescue StandardError => e
      @failed += 1
      Rails.logger.warn({ component: 'evolution', action: 'history_sync_failed', instance_id: @instance.id, remote_jid: remote_jid, error: e.message }.to_json)
    end

    def process_entry(entry)
      data = entry.with_indifferent_access
      source_id = data.dig(:key, :id) || data[:id] || data[:messageId]
      return if source_id.blank?

      @scanned += 1
      already_imported = @inbox.messages.exists?(source_id: source_id)

      Whatsapp::IncomingMessageEvolutionService.new(
        inbox: @inbox,
        params: { event: 'messages.set', instance: @instance.instance_name, data: data },
        import_history: true
      ).perform

      @imported += 1 if !already_imported && @inbox.messages.exists?(source_id: source_id)
    end

    def entries_for(remote_jid, payload)
      entries = extract_entries(payload).map { |entry| entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry }
      matching = entries.select { |entry| remote_jid_matches?(entry, remote_jid) }
      matching.presence || entries
    end

    def extract_entries(payload)
      case payload
      when Array
        payload
      when Hash
        return [payload] if payload['key'].present? || payload[:key].present?

        [
          payload['messages'],
          payload['chats'],
          safe_dig(payload, 'messages', 'records'),
          safe_dig(payload, 'chats', 'records'),
          payload['records'],
          payload['data'],
          safe_dig(payload, 'data', 'messages'),
          safe_dig(payload, 'data', 'chats'),
          safe_dig(payload, 'data', 'records'),
          payload['response'],
          safe_dig(payload, 'response', 'messages'),
          safe_dig(payload, 'response', 'chats'),
          safe_dig(payload, 'response', 'records')
        ].find { |value| value.is_a?(Array) } || []
      else
        []
      end
    end

    def safe_dig(value, *keys)
      keys.reduce(value) do |memo, key|
        return nil unless memo.respond_to?(:[])
        return nil if memo.is_a?(Array) && !key.is_a?(Integer)

        memo[key]
      end
    end

    def remote_jid_matches?(entry, remote_jid)
      jid = entry.dig(:key, :remoteJid) || entry[:remoteJid] || entry[:remote_jid]
      jid.blank? || jid.to_s.casecmp?(remote_jid.to_s)
    end

    def remote_jid_from_chat(entry)
      data = entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
      return unless data.respond_to?(:[])

      raw_jid = data[:remoteJid] || data[:remote_jid] || data[:jid] || data[:id] || data.dig(:key, :remoteJid)
      normalized = normalize_remote_jid(raw_jid)
      return unless usable_remote_jid?(normalized)

      normalized
    end

    def normalize_remote_jid(value)
      text = value.to_s.strip
      return if text.blank?
      return text if text.include?('@')

      digits = text.gsub(/\D/, '')
      digits.present? ? "#{digits}@s.whatsapp.net" : nil
    end

    def usable_remote_jid?(jid)
      text = jid.to_s
      return false if text.blank?
      return false if text.end_with?('@g.us')
      return false if text.include?('status@broadcast')

      text.end_with?('@s.whatsapp.net') || text.end_with?('@lid')
    end

    def remote_jids_for(contact_inbox)
      contact = contact_inbox.contact
      attrs = contact&.additional_attributes.to_h
      phone = contact&.phone_number.to_s.delete_prefix('+').presence || contact_inbox.source_id.to_s.gsub(/\D/, '').presence

      [
        attrs['whatsapp_jid'],
        attrs['whatsapp_sender_pn'],
        *Array(attrs['whatsapp_lid_jids']),
        phone.present? ? "#{phone}@s.whatsapp.net" : nil,
        contact_inbox.source_id.to_s.include?('@') ? contact_inbox.source_id : nil
      ].compact_blank.uniq
    end

    def contact_inboxes
      @inbox.contact_inboxes
            .includes(:contact)
            .order(updated_at: :desc)
            .limit(@contact_limit)
    end

    def bounded(value, fallback, min, max)
      integer = value.to_i
      integer = fallback if integer.zero?
      integer.clamp(min, max)
    end

    def summary(status:, reason: nil)
      {
        status: status,
        reason: reason,
        instance_id: @instance&.id,
        inbox_id: @inbox&.id,
        scanned: @scanned,
        imported: @imported,
        failed: @failed
      }.compact
    end
  end
end
