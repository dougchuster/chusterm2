# frozen_string_literal: true

module Evolution
  class WebhookEventBuilder
    def self.call(params:, evolution_instance: nil, channel: nil)
      new(params: params, evolution_instance: evolution_instance, channel: channel).call
    end

    def initialize(params:, evolution_instance: nil, channel: nil)
      @params = params.with_indifferent_access
      @evolution_instance = evolution_instance
      @channel = channel || evolution_instance&.channel_whatsapp
    end

    def call
      attrs = event_attributes
      existing = find_existing(attrs[:event_uid])
      return existing if existing.present?

      EvolutionWebhookEvent.create!(attrs)
    rescue ActiveRecord::RecordNotUnique
      find_existing(attrs[:event_uid])
    end

    private

    def event_attributes
      {
        account: account,
        inbox: inbox,
        evolution_instance: @evolution_instance,
        event_name: normalized_event,
        instance_name: incoming_instance,
        message_id: message_id,
        event_uid: event_uid,
        payload: @params.to_h,
        status: 'received'
      }
    end

    def account
      @evolution_instance&.account || @channel&.account
    end

    def inbox
      @evolution_instance&.inbox || @channel&.inbox
    end

    def normalized_event
      (@params[:event] || @params['event']).to_s.downcase.tr('.', '_')
    end

    def incoming_instance
      @params[:instance].presence || @params.dig(:evolution, :instance)
    end

    def message_id
      payload_entries.filter_map { |entry| message_id_from(entry) }.first
    end

    def payload_entries
      data = @params[:data]
      return [] if data.blank?

      if data.is_a?(Hash) && data[:messages].is_a?(Array)
        data[:messages]
      elsif data.is_a?(Hash) && data['messages'].is_a?(Array)
        data['messages']
      else
        Array.wrap(data)
      end
    end

    def message_id_from(entry)
      return if entry.blank?

      data = entry.respond_to?(:with_indifferent_access) ? entry.with_indifferent_access : entry
      return unless data.respond_to?(:[])

      key = data[:key] || {}
      key = key.with_indifferent_access if key.respond_to?(:with_indifferent_access)
      key[:id] || data[:keyId] || data[:messageId] || data[:id]
    end

    def event_uid
      [
        @evolution_instance&.id || @channel&.id,
        normalized_event,
        incoming_instance,
        message_id,
        Digest::SHA256.hexdigest(@params.to_json)
      ].compact_blank.join(':')
    end

    def find_existing(uid)
      EvolutionWebhookEvent.find_by(event_uid: uid)
    end
  end
end
