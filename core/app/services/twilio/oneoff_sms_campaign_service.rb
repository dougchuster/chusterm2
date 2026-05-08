class Twilio::OneoffSmsCampaignService
  pattr_initialize [:campaign!]

  def perform
    raise "Invalid campaign #{campaign.id}" if campaign.inbox.inbox_type != 'Twilio SMS' || !campaign.one_off?
    raise 'Completed Campaign' if campaign.completed?

    # marks campaign completed so that other jobs won't pick it up
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
      if contact.phone_number.blank?
        stats[:skipped] += 1
        tracker.record!(:skipped, contact: contact, provider: twilio_provider, metadata: { reason: 'missing_phone_number' })
        next
      end
      if contact.campaign_opted_out?
        stats[:skipped] += 1
        tracker.record!(:skipped, contact: contact, provider: twilio_provider, metadata: { reason: 'campaign_opt_out' })
        next
      end
      content = Liquid::CampaignTemplateService.new(campaign: campaign, contact: contact).call(campaign.message)

      begin
        response = channel.send_message(to: contact.phone_number, body: content)
        stats[:sent] += 1
        tracker.record!(:sent, contact: contact, provider: twilio_provider, external_id: response&.sid,
                               metadata: { phone_number: contact.phone_number })
      rescue Twilio::REST::TwilioError, Twilio::REST::RestError => e
        stats[:failed] += 1
        tracker.record!(:failed, contact: contact, provider: twilio_provider,
                                  metadata: { phone_number: contact.phone_number, error: e.message })
        Rails.logger.error("[Twilio Campaign #{campaign.id}] Failed to send to #{contact.phone_number}: #{e.message}")
        next
      end
    end

    persist_delivery_stats(stats)
  end

  def persist_delivery_stats(stats)
    Campaigns::DeliveryTracker.new(campaign).persist_initial_stats!(stats)
  end

  def twilio_provider
    channel.medium == 'whatsapp' ? 'twilio_whatsapp' : 'twilio_sms'
  end
end
