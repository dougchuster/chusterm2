require 'rails_helper'

RSpec.describe Marketing::Sync::AccountService do
  let(:account) { create(:account) }

  def build_connection(provider:, metadata: {})
    account.crm_external_connections.create!(
      provider: provider,
      status: 'active',
      name: provider,
      access_token: 'token-abc',
      expires_at: 1.day.from_now,
      metadata: metadata
    )
  end

  describe 'meta_ads sync' do
    let(:connection) do
      build_connection(provider: 'meta_ads',
                       metadata: { 'ad_accounts' => [{ 'id' => 'act_1', 'currency' => 'BRL' }] })
    end
    let(:client) { instance_double(Marketing::Meta::GraphClient) }

    before do
      allow(Marketing::Meta::GraphClient).to receive(:new).and_return(client)
      allow(client).to receive(:campaigns_for).with('act_1').and_return(
        [
          { 'id' => 'c1', 'name' => 'Campanha Leads', 'status' => 'ACTIVE',
            'objective' => 'OUTCOME_LEADS', 'daily_budget' => '5000' },
          { 'id' => 'c2', 'name' => 'Remarketing', 'status' => 'PAUSED', 'objective' => 'OUTCOME_SALES' }
        ]
      )
      allow(client).to receive(:insights_for).and_return(
        [
          { 'campaign_id' => 'c1', 'date_start' => Date.current.to_s,
            'impressions' => '1200', 'clicks' => '80', 'spend' => '45.50',
            'actions' => [{ 'action_type' => 'lead', 'value' => '9' }],
            'action_values' => [{ 'action_type' => 'offsite_conversion', 'value' => '350.0' }] }
        ]
      )
    end

    it 'upserts campaigns and daily snapshots' do
      described_class.new(connection: connection).perform!

      expect(account.marketing_campaigns.count).to eq(2)
      campaign = account.marketing_campaigns.find_by(external_id: 'c1')
      expect(campaign.name).to eq('Campanha Leads')
      expect(campaign.provider).to eq('meta_ads')

      snapshot = campaign.metric_snapshots.find_by(date: Date.current)
      expect(snapshot.impressions).to eq(1200)
      expect(snapshot.leads).to eq(9)
      expect(snapshot.spend).to eq(45.50)
    end

    it 'is idempotent across runs' do
      described_class.new(connection: connection).perform!
      described_class.new(connection: connection).perform!

      expect(account.marketing_campaigns.count).to eq(2)
      expect(MarketingMetricSnapshot.count).to eq(1)
    end

    it 'marks the connection synced' do
      described_class.new(connection: connection).perform!
      connection.reload
      expect(connection.status).to eq('active')
      expect(connection.metadata['last_synced_at']).to be_present
    end
  end

  describe 'google_ads sync' do
    let(:connection) { build_connection(provider: 'google_ads') }
    let(:client) { instance_double(Marketing::GoogleAds::Client) }

    before do
      allow(GlobalConfigService).to receive(:load).and_call_original
      allow(GlobalConfigService).to receive(:load).with('GOOGLE_ADS_DEVELOPER_TOKEN', nil).and_return('dev-token')
      allow(Marketing::GoogleAds::Client).to receive(:new).and_return(client)
      allow(client).to receive(:accessible_customers).and_return(['1234567890'])
      allow(client).to receive(:campaigns).with('1234567890').and_return(
        [{ 'campaign' => { 'id' => 'g1', 'name' => 'PMax', 'status' => 'ENABLED' },
           'campaign_budget' => { 'amount_micros' => '10000000' } }]
      )
      allow(client).to receive(:daily_metrics).and_return(
        [{ 'campaign' => { 'id' => 'g1' }, 'segments' => { 'date' => Date.current.to_s },
           'metrics' => { 'impressions' => '500', 'clicks' => '40',
                          'cost_micros' => '12300000', 'conversions' => '3.0',
                          'conversions_value' => '900.0' } }]
      )
    end

    it 'upserts google campaigns converting micros to currency units' do
      described_class.new(connection: connection).perform!

      campaign = account.marketing_campaigns.find_by(external_id: 'g1')
      expect(campaign.name).to eq('PMax')
      expect(campaign.daily_budget).to eq(10.0)

      snapshot = campaign.metric_snapshots.find_by(date: Date.current)
      expect(snapshot.spend).to eq(12.3)
      expect(snapshot.conversions).to eq(3)
    end

    it 'persists discovered customer ids in connection metadata' do
      described_class.new(connection: connection).perform!
      expect(connection.reload.metadata['customer_ids']).to eq(['1234567890'])
    end

    it 'fails loudly when the developer token is missing' do
      allow(GlobalConfigService).to receive(:load).with('GOOGLE_ADS_DEVELOPER_TOKEN', nil).and_return(nil)

      expect { described_class.new(connection: connection).perform! }
        .to raise_error(/GOOGLE_ADS_DEVELOPER_TOKEN/)
      expect(connection.reload.status).to eq('error')
      expect(connection.metadata['last_error']).to be_present
    end
  end

  describe 'ga4 sync' do
    let(:connection) { build_connection(provider: 'ga4') }
    let(:client) { instance_double(Marketing::Ga4::Client) }

    before do
      allow(Marketing::Ga4::Client).to receive(:new).and_return(client)
      allow(client).to receive(:account_summaries).and_return(
        [{ 'account' => 'accounts/1',
           'propertySummaries' => [{ 'property' => 'properties/123', 'displayName' => 'Site Principal' }] }]
      )
      allow(client).to receive(:daily_traffic).and_return(
        { 'rows' => [
          { 'dimensionValues' => [{ 'value' => Date.current.strftime('%Y%m%d').gsub(/(\d{4})(\d{2})(\d{2})/, '\1-\2-\3') },
                                  { 'value' => 'google' }, { 'value' => 'cpc' }],
            'metricValues' => [{ 'value' => '88' }, { 'value' => '2' }, { 'value' => '70' }] }
        ] }
      )
    end

    it 'registers each property as a campaign-level row with traffic in metadata' do
      described_class.new(connection: connection).perform!

      campaign = account.marketing_campaigns.find_by(provider: 'ga4', external_id: '123')
      expect(campaign.name).to eq('Site Principal')
      snapshot = campaign.metric_snapshots.first
      expect(snapshot.metadata['source:google/cpc']['sessions']).to eq(88)
    end
  end
end
