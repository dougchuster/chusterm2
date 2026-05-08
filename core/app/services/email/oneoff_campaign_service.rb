class Email::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Email' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    campaign.completed!
    process_audience
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def process_audience
    contacts = Campaigns::AudienceResolver.new(campaign.account, campaign.audience, campaign.sender).contacts
    tracker = Campaigns::DeliveryTracker.new(campaign)
    stats = { total: contacts.count, sent: 0, skipped: 0, failed: 0 }

    contacts.find_each do |contact|
      if contact.email.blank?
        stats[:skipped] += 1
        tracker.record!(:skipped, contact: contact, provider: provider_name, metadata: { reason: 'missing_email' })
        next
      end

      if contact.campaign_opted_out?
        stats[:skipped] += 1
        tracker.record!(:skipped, contact: contact, provider: provider_name, metadata: { reason: 'campaign_opt_out' })
        next
      end

      delivered_message = CampaignMailer.with(
        account: campaign.account,
        campaign: campaign,
        contact: contact
      ).marketing_email.deliver_now

      stats[:sent] += 1
      tracker.record!(
        :sent,
        contact: contact,
        provider: provider_name,
        external_id: delivered_message.message_id,
        metadata: { email: contact.email }
      )
    rescue StandardError => e
      stats[:failed] += 1
      tracker.record!(:failed, contact: contact, provider: provider_name, metadata: { email: contact.email, error: e.message })
      Rails.logger.error("[Email Campaign #{campaign.id}] Failed for contact #{contact.id}: #{e.message}")
    end

    tracker.persist_initial_stats!(stats)
  end

  def provider_name
    channel.provider.presence || 'smtp'
  end
end
