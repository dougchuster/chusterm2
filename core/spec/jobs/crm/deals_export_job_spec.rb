require 'rails_helper'

RSpec.describe Crm::DealsExportJob do
  let(:account) { create(:account) }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Pipeline Jurídico', position: 1, is_default: true) }
  let(:stage) { CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo atendimento', position: 1) }

  def build_csv_for(deals)
    described_class.new.send(
      :build_csv,
      CrmDeal.where(id: Array(deals).map(&:id)).includes(:crm_pipeline_stage, :crm_loss_reason, :contact)
    )
  end

  it 'neutralizes spreadsheet formulas in every string cell' do
    deal = CrmDeal.create!(
      account: account,
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      title: '=HYPERLINK("https://evil.tld/x","open")',
      legal_area: '+1+1',
      case_type: '@cmd',
      summary: '-2+3'
    )

    row = CSV.parse(build_csv_for([deal]), headers: true).first

    expect(row['Título']).to eq("'=HYPERLINK(\"https://evil.tld/x\",\"open\")")
    expect(row['Área Jurídica']).to eq("'+1+1")
    expect(row['Tipo de Caso']).to eq("'@cmd")
    expect(row['Resumo']).to eq("'-2+3")
  end

  it 'keeps regular values untouched' do
    deal = CrmDeal.create!(
      account: account,
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      title: 'Revisão de benefício',
      legal_area: 'Previdenciário'
    )

    row = CSV.parse(build_csv_for([deal]), headers: true).first

    expect(row['Título']).to eq('Revisão de benefício')
    expect(row['Área Jurídica']).to eq('Previdenciário')
  end
end
