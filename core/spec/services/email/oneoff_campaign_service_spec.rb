require 'rails_helper'

RSpec.describe Email::OneoffCampaignService do
  let(:account) { create(:account) }
  let(:sender) { create(:user, account: account) }
  let(:email_channel) { create(:channel_email, account: account, provider: 'smtp') }
  let(:email_inbox) { email_channel.inbox }
  let(:label) { create(:label, account: account, title: 'newsletter-juridica') }
  let(:campaign) do
    create(
      :campaign,
      account: account,
      inbox: email_inbox,
      sender: sender,
      audience: [{ type: 'Label', id: label.id }],
      title: 'Atualizacao juridica',
      message: 'Ola {{contact.name}}, temos novidades.'
    )
  end

  before do
    contact_with_email.update_labels([label.title])
    contact_without_email.update_labels([label.title])
  end

  let!(:contact_with_email) { create(:contact, :with_email, account: account, name: 'Ana Cliente') }
  let!(:contact_without_email) { create(:contact, account: account, email: nil, name: 'Sem Email') }

  describe '#perform' do
    it 'sends emails, skips contacts without email and persists delivery stats' do
      delivered_message = instance_double(Mail::Message, message_id: 'email-message-id')
      mail_delivery = instance_double(ActionMailer::MessageDelivery, deliver_now: delivered_message)

      expect(CampaignMailer).to receive(:with)
        .with(account: account, campaign: campaign, contact: contact_with_email)
        .and_return(double(marketing_email: mail_delivery))

      described_class.new(campaign: campaign).perform

      stats = campaign.reload.scoring_config['delivery_stats']

      expect(campaign).to be_completed
      expect(stats).to include('total' => 2, 'sent' => 1, 'skipped' => 1, 'failed' => 0)
      expect(campaign.campaign_delivery_events.where(event_type: 'sent').pluck(:contact_id)).to contain_exactly(contact_with_email.id)
      expect(campaign.campaign_delivery_events.where(event_type: 'skipped').pluck(:contact_id)).to contain_exactly(contact_without_email.id)
      expect(campaign.campaign_delivery_events.find_by(event_type: 'skipped').metadata).to include('reason' => 'missing_email')
    end

    it 'raises when the campaign is not an email one-off campaign' do
      website_campaign = create(:campaign, account: account)

      expect { described_class.new(campaign: website_campaign).perform }
        .to raise_error("Invalid campaign #{website_campaign.id}")
    end
  end
end
