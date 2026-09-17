require 'rails_helper'

RSpec.describe Marketing::InsightsService do
  let(:account) { create(:account) }
  let(:connection) do
    account.crm_external_connections.create!(provider: 'meta_ads', status: 'active', access_token: 't')
  end
  let(:campaign) do
    account.marketing_campaigns.create!(
      crm_external_connection: connection, external_id: 'c1',
      name: 'Campanha A', provider: 'meta_ads', level: 'campaign', status: 'ACTIVE'
    )
  end

  def snapshot(date:, spend:, leads:, impressions: 100)
    campaign.metric_snapshots.create!(
      account: account, date: date, spend: spend, leads: leads, impressions: impressions
    )
  end

  it 'retorna vazio quando nao ha dados' do
    result = described_class.new(account: account).perform
    expect(result[:alerts]).to be_empty
  end

  it 'alerta pico de CPL quando sobe >50% semana a semana' do
    (1..7).each { |i| snapshot(date: i.days.ago.to_date, spend: 300, leads: 1) }
    (8..14).each { |i| snapshot(date: i.days.ago.to_date, spend: 100, leads: 5) }

    result = described_class.new(account: account).perform
    alert = result[:alerts].find { |a| a[:kind] == 'cpl_spike' }

    expect(alert).to be_present
    expect(alert[:severity]).to eq('warning')
    expect(alert[:message]).to include('CPL')
  end

  it 'nao alerta CPL estavel' do
    (1..14).each { |i| snapshot(date: i.days.ago.to_date, spend: 100, leads: 5) }

    result = described_class.new(account: account).perform
    expect(result[:alerts].map { |a| a[:kind] }).not_to include('cpl_spike')
  end

  it 'alerta campanha ativa sem impressoes' do
    snapshot(date: Date.current, spend: 50, leads: 0, impressions: 0)

    result = described_class.new(account: account).perform
    alert = result[:alerts].find { |a| a[:kind] == 'zero_impressions' }

    expect(alert[:severity]).to eq('critical')
    expect(alert[:message]).to include('Campanha A')
  end

  it 'alerta eventos de conversao falhos' do
    account.marketing_events.create!(
      provider: 'meta_ads', event_name: 'Lead', event_id: 'e1',
      status: 'failed', direction: 'outbound'
    )

    result = described_class.new(account: account).perform
    expect(result[:alerts].map { |a| a[:kind] }).to include('failed_events')
  end
end
