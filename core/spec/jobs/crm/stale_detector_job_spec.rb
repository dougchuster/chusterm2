require 'rails_helper'

RSpec.describe Crm::StaleDetectorJob do
  let(:account) { create(:account) }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Jurídico', is_default: true) }
  let(:stage) do
    CrmPipelineStage.create!(
      account: account,
      crm_pipeline: pipeline,
      name: 'Triagem IA',
      slug: 'triagem-ia',
      position: 1
    )
  end
  let(:deal) do
    CrmDeal.create!(
      account: account,
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      title: 'Caso previdenciário'
    )
  end

  it 'does not create another stale alert while an older one remains pending' do
    deal.update_columns(created_at: 30.days.ago, updated_at: 30.days.ago) # rubocop:disable Rails/SkipsModelValidations
    CrmActivity.create!(
      account: account,
      crm_deal: deal,
      kind: 'follow_up',
      title: 'Retomar deal parado em "Triagem IA"',
      due_at: 20.days.ago,
      created_by_type: 'system',
      created_at: 21.days.ago,
      updated_at: 21.days.ago
    )

    expect do
      described_class.new.perform(account_id: account.id, stale_days: 1)
    end.not_to change(account.crm_activities, :count)
  end
end
