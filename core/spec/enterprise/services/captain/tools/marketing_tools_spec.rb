require 'rails_helper'

RSpec.describe 'Captain marketing tools', type: :model do
  let(:account) { create(:account) }
  let(:assistant) { create(:captain_assistant, account: account) }
  let(:connection) do
    account.crm_external_connections.create!(provider: 'meta_ads', status: 'active', access_token: 't')
  end
  let(:campaign) do
    account.marketing_campaigns.create!(
      crm_external_connection: connection, external_id: 'cmp_1',
      name: 'Campanha X', provider: 'meta_ads', level: 'campaign', status: 'ACTIVE'
    )
  end

  before do
    account.enable_features!('marketing')
    campaign
    (0..6).each do |i|
      campaign.metric_snapshots.create!(
        account: account, date: i.days.ago.to_date,
        spend: 100 + (i * 10), leads: 4 + i, conversions: i, clicks: 50 + i, impressions: 1000 + (i * 100),
        conversion_value: 200 + (i * 20)
      )
    end
  end

  describe Captain::Tools::Copilot::MarketingSpendSummaryService do
    it 'resume gasto por provider no periodo' do
      result = JSON.parse(described_class.new(assistant).execute(period_days: 7))
      provider = result['providers'].find { |p| p['provider'] == 'meta_ads' }

      expect(provider['spend']).to be > 0
      expect(provider['leads']).to be > 0
      expect(provider['cpl']).to be > 0
      expect(result['period_days']).to eq(7)
    end

    it 'normaliza periodo invalido para 30 dias' do
      result = JSON.parse(described_class.new(assistant).execute(period_days: 999))
      expect(result['period_days']).to eq(30)
    end

    it 'fica inativo sem a feature flag' do
      account.disable_features!('marketing')
      expect(described_class.new(assistant).active?).to be(false)
    end
  end

  describe Captain::Tools::Copilot::MarketingTopCampaignsService do
    it 'retorna campanhas ordenadas pelo metrico' do
      result = JSON.parse(described_class.new(assistant).execute(metric: 'spend', limit: 5))

      expect(result.first['campaign']).to eq('Campanha X')
      expect(result.first['provider']).to eq('meta_ads')
      expect(result.first['value']).to be > 0
    end

    it 'clampa o limite entre 1 e 20' do
      result = JSON.parse(described_class.new(assistant).execute(limit: 0))
      expect(result.size).to eq(1)
    end
  end

  describe Captain::Tools::Copilot::MarketingLeadFunnelService do
    it 'mostra funil por estagio com leads de ads' do
      pipeline = account.crm_pipelines.default_first.first
      stage = pipeline.crm_pipeline_stages.ordered.first
      contact = account.contacts.create!(name: 'L', email: 'l@x.com')
      deal = account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact, title: 'D')
      account.marketing_leads.create!(leadgen_id: 'lg_1', contact: contact, crm_deal: deal, status: 'converted', field_data: {})

      result = JSON.parse(described_class.new(assistant).execute)

      expect(result['pipeline']).to eq(pipeline.name)
      expect(result['stages']).not_to be_empty
      expect(result['converted_to_crm']).to eq(1)
      expect(result['conversion_rate']).to eq(100.0)
    end

    it 'retorna mensagem quando nao ha funil' do
      account.crm_pipelines.destroy_all
      expect(described_class.new(assistant).execute).to eq('No pipeline found')
    end
  end
end
