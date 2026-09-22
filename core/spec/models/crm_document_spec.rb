require 'rails_helper'

RSpec.describe CrmDocument do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }

  before { Crm::Documents::Defaults.ensure!(account) }

  def build(**attrs)
    described_class.new(
      { account: account, contact: contact, source: 'upload', content_type: 'application/pdf',
        original_filename: 'x.pdf', created_at: Time.zone.parse('2026-09-22 15:00') }.merge(attrs)
    )
  end

  it 'deriva o nome físico ao salvar' do
    document = build(doc_type: 'cpf')
    document.save!

    expect(document.file_name).to eq('2026-09-22 — CPF.pdf')
  end

  it 'recalcula o nome quando o tipo muda' do
    document = build(doc_type: 'cpf')
    document.save!
    document.update!(doc_type: 'rg', description: 'Frente')

    expect(document.file_name).to eq('2026-09-22 — RG — Frente.pdf')
  end

  it 'respeita o nome dado à mão pela equipe' do
    document = build(doc_type: 'cpf', file_name: 'CPF da Maria.pdf', name_locked: true)
    document.save!
    document.update!(description: 'qualquer')

    expect(document.file_name).to eq('CPF da Maria.pdf')
  end

  it 'calcula a validade pelo tipo ao classificar' do
    document = build(doc_type: 'comprovante_residencia')
    document.save!

    expect(document.expires_on).to eq(Date.new(2026, 12, 21))
  end

  it 'conta a validade a partir da data do documento' do
    document = build(doc_type: 'cnis', document_date: Date.new(2026, 9, 1))
    document.save!

    expect(document.expires_on).to eq(Date.new(2026, 10, 1))
  end

  it 'não sobrescreve validade informada à mão e não inventa validade para tipo sem prazo' do
    manual = build(doc_type: 'comprovante_residencia', expires_on: Date.new(2027, 1, 1))
    manual.save!
    rg = build(doc_type: 'rg')
    rg.save!

    expect(manual.expires_on).to eq(Date.new(2027, 1, 1))
    expect(rg.expires_on).to be_nil
  end

  it 'exige motivo para rejeitar' do
    document = build(doc_type: 'cpf', status: 'rejected')

    expect(document).not_to be_valid
    expect(document.errors[:review_note]).to be_present
  end

  it 'recusa tipo fora do catálogo da conta' do
    expect(build(doc_type: 'inexistente')).not_to be_valid
  end

  it 'recusa pasta de outro contato' do
    other_folder = CrmDocumentFolder.create!(account: account, contact: create(:contact, account: account), name: 'X')

    expect(build(crm_document_folder: other_folder)).not_to be_valid
  end

  it 'sai junto com o contato, levando o arquivo' do
    document = build(doc_type: 'cpf')
    document.file.attach(io: StringIO.new('%PDF-1.4'), filename: 'x.pdf', content_type: 'application/pdf')
    document.save!

    expect { contact.destroy! }.to change(described_class, :count).by(-1)
  end
end
