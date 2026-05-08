# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Campaigns::ProviderEventTracker do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:inbox) { channel.inbox }
  let(:campaign) { create(:campaign, account: account, inbox: inbox, scoring_config: {}) }
  let(:contact) { create(:contact, :with_phone_number, account: account) }

  describe '#track_status!' do
    it 'records provider delivery events by campaign external id' do
      CampaignDeliveryEvent.create!(
        account: account,
        campaign: campaign,
        contact: contact,
        event_type: 'sent',
        provider: 'whatsapp_cloud',
        external_id: 'wamid.123',
        occurred_at: 1.minute.ago
      )

      event = described_class.new(provider: 'whatsapp_cloud').track_status!(
        external_id: 'wamid.123',
        status: 'delivered',
        metadata: { recipient_id: contact.phone_number }
      )

      expect(event).to be_persisted
      expect(event.event_type).to eq('delivered')
      expect(event.contact).to eq(contact)
      expect(campaign.reload.scoring_config.dig('delivery_stats', 'delivered')).to eq(1)
    end

    it 'records status changes from campaign messages' do
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact, campaign: campaign)
      message = create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing,
                                 source_id: 'wamid.456')

      message.update!(status: :read)

      event = campaign.campaign_delivery_events.find_by(event_type: 'read', external_id: 'wamid.456')
      expect(event).to be_present
      expect(event.message).to eq(message)
      expect(campaign.reload.scoring_config.dig('delivery_stats', 'read')).to eq(1)
    end
  end
end
