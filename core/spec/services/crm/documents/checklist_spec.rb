require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §8.6 — "7 de 9": o que falta sem reler conversa.
# Itens espelham os checklists reais da produção (22/09/2026).
RSpec.describe Crm::Documents::Checklist do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Casos', slug: 'casos-checklist', kind: 'legal_intake') }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 0) }
  let(:deal) do
    account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact,
                              title: 'Aposentadoria', legal_area: 'previdenciario', case_type: 'aposentadoria')
  end
  let!(:template) do
    account.crm_checklist_templates.create!(
      name: 'Aposentadoria por Tempo de Contribuição', legal_area: 'previdenciario', case_type: 'aposentadoria',
      items: [
        { key: 'cnis', kind: 'document', title: 'CNIS atualizado', required: true },
        { key: 'rg_cpf', kind: 'document', title: 'RG e CPF', required: true },
        { key: 'comprovante_residencia', kind: 'document', title: 'Comprovante de residência', required: true },
        { key: 'carta_indeferimento', kind: 'document', title: 'Carta de indeferimento', required: false },
        { key: 'agendar_pericia', kind: 'task', title: 'Agendar perícia' }
      ]
    )
  end

  before { crm_documents_enable!(account) }

  def checklist
    described_class.new(deal).call
  end

  def item(key)
    checklist[:items].find { |i| i[:key] == key }
  end

  it 'usa o checklist do tipo de caso e só conta itens de documento' do
    expect(checklist).to include(template_id: template.id, total: 4, done: 0, required_total: 3)
  end

  it 'marca o item quando existe documento do tipo, inclusive por apelido (rg_cpf aceita RG)' do
    crm_document_for(contact, doc_type: 'rg')
    crm_document_for(contact, doc_type: 'comprovante_residencia')

    expect(item('rg_cpf')).to include(status: 'received')
    expect(item('comprovante_residencia')).to include(status: 'received')
    expect(checklist).to include(done: 2)
  end

  it 'só aceita documento de processo que pertence a este negócio' do
    other_deal = account.crm_deals.create!(crm_pipeline: pipeline, crm_pipeline_stage: stage, contact: contact,
                                           title: 'Outro caso', status: 'won')
    crm_document_for(contact, doc_type: 'cnis').update!(crm_deal: other_deal)
    expect(item('cnis')[:status]).to eq('missing')

    crm_document_for(contact, doc_type: 'cnis').update!(crm_deal: deal)
    expect(item('cnis')[:status]).to eq('received')
  end

  it 'mostra aprovado e não conta rejeitado' do
    crm_document_for(contact, doc_type: 'rg').update!(status: 'approved')
    crm_document_for(contact, doc_type: 'comprovante_residencia').update!(status: 'rejected', review_note: 'Ilegível')

    expect(item('rg_cpf')[:status]).to eq('approved')
    expect(item('comprovante_residencia')[:status]).to eq('rejected')
    expect(checklist[:done]).to eq(1)
  end

  it 'aceita marcação manual (entregue em papel)' do
    described_class.new(deal).mark!('carta_indeferimento', done: true)

    expect(item('carta_indeferimento')[:status]).to eq('manual')
    described_class.new(deal).mark!('carta_indeferimento', done: false)
    expect(item('carta_indeferimento')[:status]).to eq('missing')
  end

  it 'permite escolher outro checklist quando o negócio não tem área nem tipo' do
    deal.update!(legal_area: nil, case_type: nil)
    expect(checklist[:template_id]).to be_nil

    described_class.new(deal).choose_template!(template.id)

    expect(checklist).to include(template_id: template.id, total: 4)
  end

  it 'lista os checklists disponíveis para o seletor' do
    expect(checklist[:templates]).to include({ id: template.id, name: template.name })
  end
end
