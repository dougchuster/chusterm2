require 'rails_helper'

RSpec.describe Marketing::WeeklyReportJob, type: :job do
  let(:account) { create(:account) }

  before { account.enable_features!('marketing') }

  it 'registra o relatorio na trilha de auditoria da conta' do
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 't'
    )
    campaign = account.marketing_campaigns.create!(
      crm_external_connection: account.crm_external_connections.last,
      provider: 'meta_ads', level: 'campaign', external_id: 'c1', name: 'C', status: 'ACTIVE'
    )
    campaign.metric_snapshots.create!(
      account: account, date: 2.days.ago.to_date,
      impressions: 500, clicks: 50, spend: 100, leads: 8, conversions: 2, conversion_value: 300
    )

    described_class.perform_now

    event = account.crm_audit_events.where(action: 'marketing_weekly_report').last
    expect(event).to be_present
    expect(event.payload['spend']).to eq(100.0)
    expect(event.payload['leads']).to eq(8)
  end

  it 'pula contas sem a flag marketing' do
    account.disable_features!('marketing')
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 't'
    )

    described_class.perform_now

    expect(account.crm_audit_events.where(action: 'marketing_weekly_report')).to be_empty
  end

  it 'ignora contas sem conexao de marketing ativa' do
    quiet = create(:account)
    quiet.enable_features!('marketing')

    described_class.perform_now

    expect(quiet.crm_audit_events.where(action: 'marketing_weekly_report')).to be_empty
  end
end
