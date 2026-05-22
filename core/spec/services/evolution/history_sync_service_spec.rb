# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Evolution::HistorySyncService do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:configuration) { create(:evolution_api_configuration, account: account) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'evolution',
      provider_config: { 'source' => 'managed_evolution', 'instance_name' => 'dra_paula' },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:inbox) { channel.inbox }
  let(:instance) do
    EvolutionInstance.create!(
      account: account,
      inbox: inbox,
      channel_whatsapp: channel,
      configuration: configuration,
      instance_name: 'dra_paula'
    )
  end
  let(:contact) { create(:contact, account: account, phone_number: '+556199999999') }
  let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '556199999999') }
  let(:client) { instance_double(Evolution::Client) }

  before do
    allow(Evolution::Client).to receive(:new).and_return(client)
    allow(client).to receive(:fetch_profile_picture_url).and_return({})
    clear_enqueued_jobs
  end

  it 'imports missing messages from the Evolution history endpoint' do
    allow(client).to receive(:find_messages).and_return(
      [
        {
          key: {
            remoteJid: '556199999999@s.whatsapp.net',
            fromMe: false,
            id: 'HIST-1'
          },
          pushName: 'Maria Previdência',
          message: { conversation: 'Tenho dúvidas sobre aposentadoria.' },
          messageType: 'conversation',
          messageTimestamp: 1_779_400_000
        }.with_indifferent_access
      ]
    )

    result = nil
    expect do
      result = described_class.new(instance: instance, limit: 20).perform
    end.not_to have_enqueued_job(SendReplyJob)

    message = inbox.messages.find_by!(source_id: 'HIST-1')
    expect(message.content).to eq('Tenho dúvidas sobre aposentadoria.')
    expect(message.content_attributes['external_import']).to be true
    expect(result[:imported]).to eq(1)
  end

  it 'does not duplicate an already imported message' do
    create(:message, inbox: inbox, account: account, source_id: 'HIST-1', conversation: create(:conversation, account: account, inbox: inbox))
    allow(client).to receive(:find_messages).and_return(
      [
        {
          key: {
            remoteJid: '556199999999@s.whatsapp.net',
            fromMe: false,
            id: 'HIST-1'
          },
          message: { conversation: 'Mensagem duplicada' },
          messageType: 'conversation'
        }.with_indifferent_access
      ]
    )

    result = described_class.new(instance: instance, limit: 20).perform

    expect(inbox.messages.where(source_id: 'HIST-1').count).to eq(1)
    expect(result[:imported]).to eq(0)
  end
end
