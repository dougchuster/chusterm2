require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §5.3 — o nome é derivado, não digitado.
RSpec.describe Crm::Documents::Naming::FileNamer do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:received_at) { Time.zone.parse('2026-09-22 17:37:00 UTC') } # 14h37 em Brasília

  before { Crm::Documents::Defaults.ensure!(account) }

  def build_document(**attrs)
    CrmDocument.new(
      { account: account, contact: contact, source: 'whatsapp', created_at: received_at,
        original_filename: 'IMG-20260922-WA0012.jpg', content_type: 'image/jpeg' }.merge(attrs)
    )
  end

  def name_for(**attrs)
    described_class.call(build_document(**attrs))
  end

  it 'nomeia documento classificado com data, tipo e descrição' do
    expect(name_for(doc_type: 'rg', description: 'Frente e verso', content_type: 'application/pdf'))
      .to eq('2026-09-22 — RG — Frente e verso.pdf')
  end

  it 'omite a descrição quando não há' do
    expect(name_for(doc_type: 'cnis', content_type: 'application/pdf')).to eq('2026-09-22 — CNIS.pdf')
  end

  it 'prefere a data do documento à data de recebimento' do
    expect(name_for(doc_type: 'cnis', document_date: Date.new(2026, 3, 10)))
      .to eq('2026-03-10 — CNIS.jpg')
  end

  it 'usa a descrição como rótulo no tipo "outro"' do
    expect(name_for(doc_type: 'outro', description: 'Declaração do vizinho'))
      .to eq('2026-09-22 — Declaração do vizinho.jpg')
  end

  it 'mantém nome original, hora local e origem enquanto está na triagem' do
    expect(name_for).to eq('2026-09-22 14h37 — WhatsApp — IMG-20260922-WA0012.jpg')
  end

  it 'deriva a extensão do tipo real do conteúdo, não do nome enviado' do
    expect(name_for(doc_type: 'rg', original_filename: 'foto.pdf', content_type: 'image/jpeg'))
      .to eq('2026-09-22 — RG.jpg')
  end

  it 'cai na extensão original quando o tipo é desconhecido' do
    expect(name_for(doc_type: 'rg', original_filename: 'scan.TIFF', content_type: 'application/octet-stream'))
      .to eq('2026-09-22 — RG.tiff')
  end

  it 'limpa caracteres proibidos da descrição' do
    expect(name_for(doc_type: 'rg', description: 'frente/verso?', content_type: 'application/pdf'))
      .to eq('2026-09-22 — RG — frente verso.pdf')
  end

  it 'trunca a descrição, nunca a data, o tipo ou a extensão' do
    name = name_for(doc_type: 'rg', description: 'x' * 300, content_type: 'application/pdf')
    base = name.delete_suffix('.pdf')

    expect(base.length).to be <= described_class::MAX_BASE_LENGTH
    expect(name).to start_with('2026-09-22 — RG — xxx')
    expect(name).to end_with('.pdf')
  end
end
