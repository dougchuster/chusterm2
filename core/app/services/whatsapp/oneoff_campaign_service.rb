class Whatsapp::OneoffCampaignService
  pattr_initialize [:campaign!]

  def perform
    validate_campaign!
    # marks campaign completed so that other jobs won't pick it up
    campaign.completed!
    process_audience
  end

  private

  delegate :inbox, to: :campaign
  delegate :channel, to: :inbox

  def validate_campaign_type!
    raise "Invalid campaign #{campaign.id}" unless whatsapp_campaign? && campaign.one_off?
  end

  def whatsapp_campaign?
    campaign.inbox.inbox_type == 'Whatsapp'
  end

  def validate_campaign_status!
    raise 'Completed Campaign' if campaign.completed?
  end

  def validate_provider!
    raise 'WhatsApp Cloud provider required' if channel.provider != 'whatsapp_cloud'
  end

  def validate_feature_flag!
    raise 'WhatsApp campaigns feature not enabled' unless campaign.account.feature_enabled?(:whatsapp_campaign)
  end

  def validate_campaign!
    validate_campaign_type!
    validate_campaign_status!
    validate_provider!
    validate_feature_flag!
  end

  def process_contact(contact)
    Rails.logger.info "Processing contact: #{contact.name} (#{contact.phone_number})"

    if contact.phone_number.blank?
      Rails.logger.info "Skipping contact #{contact.name} - no phone number"
      return [:skipped, nil]
    end

    if contact.campaign_opted_out?
      Rails.logger.info "Skipping contact #{contact.name} - campaign opt-out"
      return [:skipped, nil]
    end

    if campaign.template_params.blank?
      Rails.logger.error "Skipping contact #{contact.name} - no template_params found for WhatsApp campaign"
      return [:failed, nil]
    end

    external_id = send_whatsapp_template_message(to: contact.phone_number)
    external_id.present? ? [:sent, external_id] : [:failed, nil]
  end

  def process_audience
    contacts = Campaigns::AudienceResolver.new(campaign.account, campaign.audience, campaign.sender).contacts
    Rails.logger.info "Processing #{contacts.count} contacts for campaign #{campaign.id}"

    tracker = Campaigns::DeliveryTracker.new(campaign)
    stats = { total: contacts.count, sent: 0, skipped: 0, failed: 0 }
    contacts.find_each do |contact|
      result, external_id = process_contact(contact)
      stats[result] += 1 if stats.key?(result)
      tracker.record!(
        result,
        contact: contact,
        provider: channel.provider,
        external_id: external_id,
        metadata: { phone_number: contact.phone_number }
      )
    rescue StandardError => e
      stats[:failed] += 1
      tracker.record!(:failed, contact: contact, provider: channel.provider, metadata: { error: e.message })
      Rails.logger.error("[WhatsApp Campaign #{campaign.id}] Failed for contact #{contact.id}: #{e.message}")
    end

    persist_delivery_stats(stats)

    Rails.logger.info "Campaign #{campaign.id} processing completed"
  end

  def persist_delivery_stats(stats)
    Campaigns::DeliveryTracker.new(campaign).persist_initial_stats!(stats)
  end

  def send_whatsapp_template_message(to:)
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: campaign.template_params
    )

    name, namespace, lang_code, processed_parameters = processor.call

    return false if name.blank?

    channel.send_template(to, {
                            name: name,
                            namespace: namespace,
                            lang_code: lang_code,
                            parameters: processed_parameters
                          }, nil)

  rescue StandardError => e
    Rails.logger.error "Failed to send WhatsApp template message to #{to}: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
    # continue processing remaining contacts
    nil
  end
end
