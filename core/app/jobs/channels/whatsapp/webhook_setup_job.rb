class Channels::Whatsapp::WebhookSetupJob < ApplicationJob
  queue_as :default

  def perform(channel_id)
    channel = Channel::Whatsapp.find_by(id: channel_id)
    return unless channel

    channel.setup_webhooks
    check_channel_health(channel)
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] WebhookSetupJob failed for channel #{channel_id}: #{e.message}")
  end

  private

  def check_channel_health(channel)
    health_data = Whatsapp::HealthService.new(channel).fetch_health_status
    return unless health_data

    if health_data[:platform_type] == 'NOT_APPLICABLE' ||
       health_data.dig(:throughput, 'level') == 'NOT_APPLICABLE'
      channel.prompt_reauthorization!
    end
  rescue StandardError => e
    Rails.logger.error("[WHATSAPP] Health check failed for channel #{channel.phone_number}: #{e.message}")
  end
end
