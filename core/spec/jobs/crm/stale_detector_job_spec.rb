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

  it 'creates a stale activity for a deal without recent movement' do
    deal.update_columns(created_at: 30.days.ago, updated_at: 30.days.ago) # rubocop:disable Rails/SkipsModelValidations

    expect do
      described_class.new.perform(account_id: account.id, stale_days: 1)
    end.to change(account.crm_activities, :count).by(1)

    expect(account.crm_activities.last.title).to include('Retomar deal parado')
  end

  it 'treats recent conversation activity as movement even without audit events' do
    deal.update_columns(created_at: 30.days.ago, updated_at: 30.days.ago) # rubocop:disable Rails/SkipsModelValidations
    conversation = create(:conversation, account: account)
    conversation.update_column(:last_activity_at, 1.hour.ago) # rubocop:disable Rails/SkipsModelValidations
    deal.update_column(:conversation_id, conversation.id) # rubocop:disable Rails/SkipsModelValidations

    expect do
      described_class.new.perform(account_id: account.id, stale_days: 1)
    end.not_to change(account.crm_activities, :count)
  end

  it 'treats old conversation activity as stale' do
    deal.update_columns(created_at: 30.days.ago, updated_at: 30.days.ago) # rubocop:disable Rails/SkipsModelValidations
    conversation = create(:conversation, account: account)
    conversation.update_column(:last_activity_at, 20.days.ago) # rubocop:disable Rails/SkipsModelValidations
    deal.update_column(:conversation_id, conversation.id) # rubocop:disable Rails/SkipsModelValidations

    expect do
      described_class.new.perform(account_id: account.id, stale_days: 1)
    end.to change(account.crm_activities, :count).by(1)
  end

  it 'uses stage expected_duration_hours when the account is universal' do
    allow(account).to receive(:feature_enabled?).and_call_original
    allow(account).to receive(:feature_enabled?).with('crm_universal').and_return(true)
    stage.update!(expected_duration_hours: 2)
    deal.update_columns(created_at: 1.day.ago, updated_at: 1.day.ago) # rubocop:disable Rails/SkipsModelValidations

    expect do
      described_class.new.perform(account_id: account.id)
    end.to change(account.crm_activities, :count).by(1)
  end

  it 'does not leak into other accounts' do
    deal.update_columns(created_at: 30.days.ago, updated_at: 30.days.ago) # rubocop:disable Rails/SkipsModelValidations
    other_account = create(:account)

    expect do
      described_class.new.perform(account_id: other_account.id, stale_days: 1)
    end.not_to change(account.crm_activities, :count)
  end
end
