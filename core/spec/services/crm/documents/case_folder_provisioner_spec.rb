require 'rails_helper'

RSpec.describe Crm::Documents::CaseFolderProvisioner do
  let(:account) { create(:account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Casos', slug: 'casos-docs', kind: 'legal_intake') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0) }
  let(:contact) { create(:contact, account: account) }

  before { Crm::Documents::Defaults.ensure!(account, preset: 'legal') }


  def deal(**attrs)
    account.crm_deals.create!({ crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact,
                                title: 'Reclamação trabalhista' }.merge(attrs))
  end

  it 'cria a pasta do processo dentro de 04 Processos com as subpastas da área' do
    folder = described_class.new(deal(legal_area: 'trabalhista')).ensure!

    expect(folder.parent.slot).to eq('processos')
    expect(folder.children.ordered.map(&:name))
      .to eq(['01 Documentos do Contrato', '02 Provas', '03 Petições e Protocolos', '04 Decisões e Audiências'])
  end

  it 'usa o modelo cível para consumidor' do
    folder = described_class.new(deal(legal_area: 'consumidor')).ensure!

    expect(folder.children.ordered.first(2).map(&:name)).to eq(['01 Documentos do Caso', '02 Provas'])
  end

  it 'usa o modelo geral quando a área não tem modelo próprio' do
    folder = described_class.new(deal(legal_area: 'tributario')).ensure!

    expect(folder.children.ordered.map(&:name).last).to eq('04 Comunicações')
  end

  it 'acha a mesma pasta depois que o negócio é renomeado' do
    record = deal(legal_area: 'familia')
    first = described_class.new(record).ensure!
    record.update!(title: 'Divórcio consensual')

    expect(described_class.new(record).ensure!.id).to eq(first.id)
  end
end
