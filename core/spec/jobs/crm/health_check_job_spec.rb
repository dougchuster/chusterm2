require 'rails_helper'

RSpec.describe Crm::HealthCheckJob do
  let(:account) { create(:account) }
  let(:health_result) do
    {
      status: 'attention',
      deals: { hot_leads_without_owner: 1 },
      labels: { system_visible_on_sidebar: 0 },
      media: { audio_failed: 0, media_failed: 0, stale_processing: 0 }
    }
  end

  it 'does not create another health alert while an older one remains pending' do
    CrmActivity.create!(
      account: account,
      kind: 'revisao_juridica',
      title: described_class::ALERT_TITLE,
      due_at: 20.days.ago,
      created_by_type: 'system',
      created_at: 21.days.ago,
      updated_at: 21.days.ago
    )
    allow(Crm::HealthCheckService).to receive(:new)
      .with(account: account)
      .and_return(instance_double(Crm::HealthCheckService, perform: health_result))

    expect do
      described_class.new.perform(account_id: account.id)
    end.not_to change(account.crm_activities, :count)
  end
end
