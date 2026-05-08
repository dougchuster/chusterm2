class Campaigns::DeliveryTracker
  STAT_KEYS = CampaignDeliveryEvent::EVENT_TYPES.freeze

  def initialize(campaign)
    @campaign = campaign
  end

  def persist_initial_stats!(stats)
    initial_stats = stats.stringify_keys.slice('total', 'sent', 'skipped', 'failed')
    write_stats(normalized_stats.merge(initial_stats).merge('processed_at' => Time.current.iso8601))
  end

  def record!(event_type, contact: nil, conversation: nil, message: nil, provider: nil, external_id: nil, metadata: {},
              occurred_at: Time.current)
    event_type = event_type.to_s
    return false unless STAT_KEYS.include?(event_type)

    event = find_or_initialize_event(event_type, contact, provider, external_id)
    event.assign_attributes(
      account: campaign.account,
      conversation: conversation,
      message: message,
      provider: provider,
      external_id: external_id,
      metadata: metadata || {},
      occurred_at: occurred_at
    )
    event.save! if event.new_record? || event.changed?
    refresh_stats!
    event
  rescue ActiveRecord::RecordNotUnique
    refresh_stats!
    false
  end

  def refresh_stats!
    write_stats(normalized_stats.merge(event_counts).merge('updated_at' => Time.current.iso8601))
  end

  private

  attr_reader :campaign

  def find_or_initialize_event(event_type, contact, provider, external_id)
    if contact.present?
      campaign.campaign_delivery_events.find_or_initialize_by(event_type: event_type, contact: contact)
    elsif external_id.present?
      campaign.campaign_delivery_events.find_or_initialize_by(
        event_type: event_type, provider: provider, external_id: external_id
      )
    else
      campaign.campaign_delivery_events.new(event_type: event_type)
    end
  end

  def event_counts
    campaign.campaign_delivery_events.group(:event_type).count.transform_values(&:to_i)
  end

  def normalized_stats
    current_stats = (campaign.scoring_config || {})['delivery_stats'] || {}
    STAT_KEYS.index_with { |key| current_stats[key].to_i }
             .merge('total' => current_stats['total'].to_i)
             .merge(current_stats.slice('processed_at'))
  end

  def write_stats(stats)
    campaign.update_columns(
      scoring_config: (campaign.scoring_config || {}).merge('delivery_stats' => stats),
      updated_at: Time.current
    )
  end
end
