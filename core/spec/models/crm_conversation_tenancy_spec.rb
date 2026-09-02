require 'rails_helper'

RSpec.describe 'CRM conversation tenancy', type: :model do
  let(:account) { create(:account) }
  let(:foreign_account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:foreign_conversation) { create(:conversation, account: foreign_account) }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Pipeline seguro', position: 1) }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Entrada', position: 1) }

  it 'accepts a deal conversation from the same account' do
    deal = CrmDeal.new(
      account: account,
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      conversation: conversation,
      title: 'Vínculo válido'
    )

    expect(deal).to be_valid
  end

  it 'rejects a deal conversation from another account' do
    deal = CrmDeal.new(
      account: account,
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      conversation: foreign_conversation,
      title: 'Vínculo inválido'
    )

    expect(deal).not_to be_valid
    expect(deal.errors[:conversation]).to include('must belong to the same account')
  end

  it 'rejects an activity conversation from another account' do
    activity = CrmActivity.new(
      account: account,
      conversation: foreign_conversation,
      kind: 'follow_up',
      title: 'Vínculo inválido',
      priority: 'normal'
    )

    expect(activity).not_to be_valid
    expect(activity.errors[:conversation]).to include('must belong to the same account')
  end

  it 'rejects every foreign account association on a deal' do
    foreign_pipeline = CrmPipeline.create!(account: foreign_account, name: 'Pipeline externo', position: 1)
    foreign_stage = CrmPipelineStage.create!(
      account: foreign_account,
      crm_pipeline: foreign_pipeline,
      name: 'Etapa externa',
      position: 1
    )
    foreign_user = create(:user, account: foreign_account)
    foreign_loss_reason = CrmLossReason.create!(account: foreign_account, name: 'Motivo externo', slug: 'externo')

    deal = CrmDeal.new(
      account: account,
      crm_pipeline: foreign_pipeline,
      crm_pipeline_stage: foreign_stage,
      contact: create(:contact, account: foreign_account),
      conversation: foreign_conversation,
      inbox: create(:inbox, account: foreign_account),
      team_id: create(:team, account: foreign_account).id,
      owner_id: foreign_user.id,
      assignee_id: foreign_user.id,
      crm_loss_reason: foreign_loss_reason,
      title: 'Tentativa entre contas'
    )

    expect(deal).not_to be_valid
    expect(deal.errors.attribute_names).to include(
      :crm_pipeline, :crm_pipeline_stage, :contact, :conversation, :inbox,
      :team, :owner, :assignee, :crm_loss_reason
    )
  end

  it 'rejects foreign deal, contact and users on an activity' do
    foreign_user = create(:user, account: foreign_account)
    foreign_pipeline = CrmPipeline.create!(account: foreign_account, name: 'Pipeline externo', position: 1)
    foreign_stage = CrmPipelineStage.create!(
      account: foreign_account,
      crm_pipeline: foreign_pipeline,
      name: 'Etapa externa',
      position: 1
    )
    foreign_deal = CrmDeal.create!(
      account: foreign_account,
      crm_pipeline: foreign_pipeline,
      crm_pipeline_stage: foreign_stage,
      title: 'Deal externo'
    )
    activity = CrmActivity.new(
      account: account,
      crm_deal: foreign_deal,
      contact: create(:contact, account: foreign_account),
      owner: foreign_user,
      assignee: foreign_user,
      kind: 'follow_up',
      title: 'Atividade externa',
      priority: 'normal'
    )

    expect(activity).not_to be_valid
    expect(activity.errors.attribute_names).to include(:crm_deal, :contact, :owner, :assignee)
  end

  it 'rejects a foreign deal on a Captain conversation state' do
    foreign_pipeline = CrmPipeline.create!(account: foreign_account, name: 'Pipeline externo', position: 1)
    foreign_stage = CrmPipelineStage.create!(
      account: foreign_account,
      crm_pipeline: foreign_pipeline,
      name: 'Etapa externa',
      position: 1
    )
    foreign_deal = CrmDeal.create!(
      account: foreign_account,
      crm_pipeline: foreign_pipeline,
      crm_pipeline_stage: foreign_stage,
      title: 'Deal externo'
    )
    state = CaptainConversationState.new(conversation: conversation, crm_deal: foreign_deal)

    expect(state).not_to be_valid
    expect(state.errors[:crm_deal]).to include('must belong to the same account')
  end
end
