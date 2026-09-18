# frozen_string_literal: true

require 'rails_helper'

# Complementa tools_spec.rb: a IA nunca fecha um negócio por conta própria.
RSpec.describe Crm::Tools do # move_stage em etapas terminais
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Funil', slug: 'funil', kind: 'sales') }
  let!(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 1) }
  let!(:won_stage) do
    pipeline.crm_pipeline_stages.create!(account: account, name: 'Ganho', slug: 'ganho', position: 9, terminal_outcome: 'won')
  end
  let(:contact) { create(:contact, account: account, name: 'Maria') }
  let(:deal) do
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact, title: 'Negócio')
  end
  let(:tools) { described_class.new(deal: deal) }

  it 'recusa mover para uma etapa terminal e audita a negativa' do
    result = tools.move_stage('ganho', reason: 'cliente confirmou')

    expect(result).not_to be_ok
    expect(deal.reload.crm_pipeline_stage_id).to eq(stage.id)
    expect(CrmAuditEvent.where(target_id: deal.id, action: 'ai_tool_denied')).to exist
  end

  it 'não lista etapas terminais em allowed_stages do contexto' do
    expect(tools.deal_context.data[:allowed_stages]).to eq(['novo'])
    expect(tools.deal_context.data[:allowed_stages]).not_to include(won_stage.slug)
  end
end
