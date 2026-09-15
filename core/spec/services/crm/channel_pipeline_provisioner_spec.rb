require 'rails_helper'

RSpec.describe Crm::ChannelPipelineProvisioner do
  let(:account) { create(:account) }
  let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:inbox) { whatsapp_channel.inbox }

  # Toda conta ganha um pipeline default via AccountInitializer — é ele que o
  # provisioner usa como fonte de estágios. O "legacy pipeline" aqui simula um
  # funil antigo com slugs próprios para provar o mapeamento por slug no move.
  def create_legacy_pipeline!
    pipeline = CrmPipeline.create!(account: account, name: 'Pipeline Juridico', position: 90, is_default: false)
    CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificação', slug: 'qualificacao', position: 0)
    CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Qualificado', slug: 'qualificado', position: 1)
    pipeline
  end

  it 'creates an exclusive pipeline for a WhatsApp inbox' do
    create_legacy_pipeline!

    pipeline = described_class.new(account: account, inbox: inbox).perform

    expect(pipeline).to be_present
    expect(pipeline.inbox_id).to eq(inbox.id)
    expect(pipeline.name).to include(inbox.name)
    source_slugs = account.crm_pipelines.active.where(inbox_id: nil).default_first.first.crm_pipeline_stages.pluck(:slug)
    expect(pipeline.crm_pipeline_stages.pluck(:slug)).to match_array(source_slugs)
  end

  it 'moves existing deals from the same inbox to the channel pipeline' do
    legacy_pipeline = create_legacy_pipeline!
    # 'qualificacao' existe no pipeline default copiado; o deal deve manter o
    # estágio por slug mesmo vindo de um funil diferente.
    legacy_stage = legacy_pipeline.crm_pipeline_stages.find_by!(slug: 'qualificacao')
    deal = CrmDeal.create!(
      account: account,
      inbox: inbox,
      crm_pipeline: legacy_pipeline,
      crm_pipeline_stage: legacy_stage,
      title: 'Atendimento previdenciario'
    )

    pipeline = described_class.new(account: account, inbox: inbox, move_existing_deals: true).perform

    expect(deal.reload.crm_pipeline_id).to eq(pipeline.id)
    expect(deal.crm_pipeline_stage.slug).to eq('qualificacao')
    expect(deal.crm_pipeline_stage.crm_pipeline_id).to eq(pipeline.id)
  end

  it 'falls back to the first stage when the deal slug does not exist in the channel pipeline' do
    legacy_pipeline = create_legacy_pipeline!
    legacy_stage = legacy_pipeline.crm_pipeline_stages.find_by!(slug: 'qualificado')
    deal = CrmDeal.create!(
      account: account,
      inbox: inbox,
      crm_pipeline: legacy_pipeline,
      crm_pipeline_stage: legacy_stage,
      title: 'Atendimento sem estágio equivalente'
    )

    pipeline = described_class.new(account: account, inbox: inbox, move_existing_deals: true).perform

    expect(deal.reload.crm_pipeline_id).to eq(pipeline.id)
    expect(deal.crm_pipeline_stage).to eq(pipeline.crm_pipeline_stages.active.ordered.first)
  end

  it 'removes the exclusive pipeline and its deals when the inbox is deleted' do
    create_legacy_pipeline!
    pipeline = described_class.new(account: account, inbox: inbox).perform
    stage = pipeline.crm_pipeline_stages.first
    deal = CrmDeal.create!(
      account: account,
      inbox: inbox,
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      title: 'Atendimento do canal'
    )

    Crm::ChannelPipelineDestroyer.new(inbox: inbox).perform

    expect(CrmPipeline.exists?(pipeline.id)).to be false
    expect(CrmDeal.exists?(deal.id)).to be false
  end

  it 'removes the exclusive pipeline through the real inbox destroy callback' do
    create_legacy_pipeline!
    pipeline = described_class.new(account: account, inbox: inbox).perform
    stage = pipeline.crm_pipeline_stages.first
    deal = CrmDeal.create!(
      account: account,
      inbox: inbox,
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      title: 'Atendimento removido com o canal'
    )

    inbox.destroy!

    expect(CrmPipeline.exists?(pipeline.id)).to be false
    expect(CrmDeal.exists?(deal.id)).to be false
  end
end
