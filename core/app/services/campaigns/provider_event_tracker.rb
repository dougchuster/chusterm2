class Campaigns::ProviderEventTracker
  STATUS_EVENT_TYPES = {
    'delivered' => :delivered,
    'read' => :read,
    'failed' => :failed
  }.freeze

  def self.track_message_status!(message, metadata: {})
    new(provider: provider_for(message)).track_status!(
      external_id: message.source_id,
      status: message.status,
      message: message,
      metadata: metadata
    )
  end

  def self.provider_for(message)
    channel = message&.inbox&.channel
    channel.respond_to?(:provider) ? channel.provider : message&.inbox&.channel_type
  end

  def initialize(provider: nil)
    @provider = provider
  end

  def track_status!(external_id:, status:, message: nil, metadata: {}, occurred_at: Time.current)
    event_type = STATUS_EVENT_TYPES[status.to_s]
    return false if event_type.blank?

    sent_event = sent_event_for(external_id)
    campaign = message&.conversation&.campaign || sent_event&.campaign
    return false if campaign.blank?

    Campaigns::DeliveryTracker.new(campaign).record!(
      event_type,
      contact: message&.conversation&.contact || sent_event&.contact,
      conversation: message&.conversation || sent_event&.conversation,
      message: message || sent_event&.message,
      provider: @provider || sent_event&.provider,
      external_id: external_id,
      metadata: event_metadata(status, metadata),
      occurred_at: occurred_at
    )
  rescue StandardError => e
    Rails.logger.warn("[Campaign Tracking] provider event failed for external_id=#{external_id}: #{e.message}")
    false
  end

  private

  def sent_event_for(external_id)
    return if external_id.blank?

    scope = CampaignDeliveryEvent.where(event_type: 'sent', external_id: external_id)
    scope = scope.where(provider: @provider) if @provider.present?
    scope.order(created_at: :desc).first
  end

  def event_metadata(status, metadata)
    (metadata || {}).merge(provider_status: status.to_s)
  end
end
