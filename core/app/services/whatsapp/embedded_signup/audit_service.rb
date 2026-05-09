# frozen_string_literal: true

module Whatsapp
  module EmbeddedSignup
    class AuditService
      def initialize(channel:, user:, event:, metadata: {})
        @channel = channel
        @user = user
        @event = event
        @metadata = metadata
      end

      def perform
        Rails.logger.info(
          "[WHATSAPP AUDIT] event=#{@event} " \
          "account_id=#{@channel.account_id} " \
          "channel_id=#{@channel.id} " \
          "phone_number=#{@channel.phone_number} " \
          "user_id=#{@user&.id} " \
          "metadata=#{@metadata.to_json}"
        )
      rescue StandardError => e
        Rails.logger.error("[WHATSAPP AUDIT] audit failed for #{@event}: #{e.message}")
      end
    end
  end
end
