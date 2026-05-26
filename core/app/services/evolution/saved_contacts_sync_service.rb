# frozen_string_literal: true

module Evolution
  class SavedContactsSyncService
    DEFAULT_LIMIT = 500
    SAVED_TRUE_KEYS = %i[isSaved saved isMyContact isContact contactSaved].freeze
    SAVED_FALSE_KEYS = %i[isSaved saved isMyContact contactSaved].freeze

    def initialize(instance:, client: nil, limit: DEFAULT_LIMIT)
      @instance = instance
      @inbox = instance&.inbox
      @client = client || (instance ? Evolution::Client.new(configuration: instance.configuration) : nil)
      @limit = bounded(limit, DEFAULT_LIMIT, 1, 1000)
      @scanned = 0
      @imported = 0
      @skipped = 0
      @failed = 0
    end

    def perform
      return summary(status: 'skipped', reason: 'missing_instance_or_inbox') if @instance.blank? || @inbox.blank?

      payload = @client.find_contacts(instance_name: @instance.instance_name, limit: @limit)
      extract_entries(payload).first(@limit).each { |entry| import_entry(entry) }
      summary(status: 'ok')
    rescue StandardError => e
      @failed += 1
      Rails.logger.warn({ component: 'evolution', action: 'saved_contacts_sync_failed', instance_id: @instance&.id, error: e.message }.to_json)
      summary(status: 'error', reason: e.message)
    end

    private

    def import_entry(entry)
      data = normalize_entry(entry)
      @scanned += 1
      return skip unless saved_contact_entry?(data)

      phone = phone_from_entry(data)
      return skip if phone.blank?

      contact_inbox = ContactInboxWithContactBuilder.new(
        source_id: phone,
        inbox: @inbox,
        contact_attributes: {
          name: display_name(data, phone),
          phone_number: "+#{phone}",
          identifier: remote_jid_from_entry(data),
          additional_attributes: saved_contact_attributes(data, phone)
        }
      ).perform

      contact = contact_inbox.contact
      refresh_contact_identity!(contact, data, phone)
      Crm::SavedContactCustomerClassifier.promote!(
        contact,
        source: 'evolution_saved_contacts',
        metadata: saved_contact_attributes(data, phone)
      )
      enqueue_avatar_sync(contact, data)
      @imported += 1
    rescue StandardError => e
      @failed += 1
      Rails.logger.warn({ component: 'evolution', action: 'saved_contact_import_failed', instance_id: @instance&.id, error: e.message }.to_json)
    end

    def normalize_entry(entry)
      return entry.with_indifferent_access if entry.respond_to?(:with_indifferent_access)

      {}
    end

    def saved_contact_entry?(data)
      return false unless data.respond_to?(:[])
      return false if group_or_broadcast_contact?(data)
      return false if explicit_saved_flag_false?(data)

      return true if explicit_saved_flag_true?(data) || saved_name_present?(data)

      true
    end

    def explicit_saved_flag_true?(data)
      SAVED_TRUE_KEYS.any? { |key| truthy?(data[key]) }
    end

    def explicit_saved_flag_false?(data)
      SAVED_FALSE_KEYS.any? { |key| data.key?(key) && !truthy?(data[key]) }
    end

    def saved_name_present?(data)
      name = data[:name] || data[:verifiedName]
      name.to_s.strip.present?
    end

    def group_or_broadcast_contact?(data)
      jid = remote_jid_from_entry(data).to_s
      jid.blank? ||
        jid.end_with?('@g.us') ||
        jid.include?('status@broadcast') ||
        jid.include?('broadcast')
    end

    def phone_from_entry(data)
      candidates = [
        data[:number],
        data[:phone],
        data[:phoneNumber],
        data[:remoteJid],
        data[:jid],
        data[:id],
        data.dig(:key, :remoteJid)
      ]

      candidates.filter_map { |value| normalize_phone(value) }.first
    end

    def normalize_phone(value)
      text = value.to_s.strip
      return if text.blank? || text.end_with?('@lid')

      text = text.split('@').first if text.include?('@')
      digits = text.gsub(/\D/, '')
      return if digits.length < 8

      digits
    end

    def remote_jid_from_entry(data)
      data[:remoteJid] ||
        data[:remote_jid] ||
        data[:jid] ||
        data[:id] ||
        data.dig(:key, :remoteJid)
    end

    def display_name(data, phone)
      [
        data[:name],
        data[:verifiedName],
        data[:pushName],
        data[:notify],
        data[:displayName]
      ].map(&:to_s).map(&:strip).find(&:present?) || phone
    end

    def saved_contact_attributes(data, phone)
      {
        'whatsapp_saved_contact' => true,
        'whatsapp_saved_contact_synced_at' => Time.current.iso8601,
        'whatsapp_saved_contact_name' => display_name(data, phone),
        'whatsapp_remote_jid' => remote_jid_from_entry(data),
        'whatsapp_saved_contact_confidence' => explicit_saved_flag_true?(data) || saved_name_present?(data) ? 'explicit' : 'contacts_endpoint'
      }.compact
    end

    def refresh_contact_identity!(contact, data, phone)
      attrs = contact.additional_attributes.to_h.merge(saved_contact_attributes(data, phone))
      updates = { additional_attributes: attrs }
      updates[:name] = display_name(data, phone) if contact.name.blank? || contact.name == phone || contact.name == "+#{phone}"
      updates[:identifier] = remote_jid_from_entry(data) if contact.identifier.blank? && remote_jid_from_entry(data).present?
      contact.update!(updates) if updates.any?
    end

    def enqueue_avatar_sync(contact, data)
      avatar_url = data[:profilePictureUrl] || data[:profilePicUrl] || data[:profile_picture_url]
      return if avatar_url.blank? || contact.avatar.attached?

      Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def extract_entries(payload)
      case payload
      when Array
        payload
      when Hash
        [
          payload['contacts'],
          payload['records'],
          payload['data'],
          safe_dig(payload, 'contacts', 'records'),
          safe_dig(payload, 'data', 'contacts'),
          safe_dig(payload, 'data', 'records'),
          payload['response'],
          safe_dig(payload, 'response', 'contacts'),
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

    def bounded(value, fallback, min, max)
      integer = value.to_i
      integer = fallback if integer.zero?
      integer.clamp(min, max)
    end

    def skip
      @skipped += 1
      nil
    end

    def summary(status:, reason: nil)
      {
        status: status,
        reason: reason,
        instance_id: @instance&.id,
        inbox_id: @inbox&.id,
        scanned: @scanned,
        imported: @imported,
        skipped: @skipped,
        failed: @failed
      }.compact
    end
  end
end
