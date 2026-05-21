require 'rails_helper'

RSpec.describe Crm::ChannelPipelineProvisioner do
  let(:account) { create(:account) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox }

  def create_legacy_pipeline!
    pipeline = CrmPipeline.create!(account: account, name: 'Pipeline Juridico', position: 1, is_default: true)
    CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo atendimento', slug: 'novo-atendimento', position: 0)
    CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', slug: 'qualificado', position: 1)
    pipeline
  end

  it 'creates an exclusive pipeline for a WhatsApp inbox' do
    create_legacy_pipeline!

    pipeline = described_class.new(account: account, inbox: inbox).perform

    expect(pipeline).to be_present
    expect(pipeline.inbox_id).to eq(inbox.id)
    expect(pipeline.name).to include(inbox.name)
    expect(pipeline.crm_pipeline_stages.pluck(:slug)).to include('novo-atendimento', 'qualificado')
  end

  it 'moves existing deals from the same inbox to the channel pipeline' do
    legacy_pipeline = create_legacy_pipeline!
    legacy_stage = legacy_pipeline.crm_pipeline_stages.find_by!(slug: 'qualificado')
    deal = CrmDeal.create!(
      account: account,
      inbox: inbox,
      crm_pipeline: legacy_pipeline,
      crm_pipeline_stage: legacy_stage,
      title: 'Atendimento previdenciario'
    )

    pipeline = described_class.new(account: account, inbox: inbox, move_existing_deals: true).perform

    expect(deal.reload.crm_pipeline_id).to eq(pipeline.id)
    expect(deal.crm_pipeline_stage.slug).to eq('qualificado')
  end
end
