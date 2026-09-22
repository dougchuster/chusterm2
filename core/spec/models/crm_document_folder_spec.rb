require 'rails_helper'

RSpec.describe CrmDocumentFolder do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }

  def folder(name, parent: nil, **attrs)
    described_class.create!({ account: account, contact: contact, parent: parent, name: name }.merge(attrs))
  end

  it 'limpa o nome com o sanitizador da nomenclatura' do
    expect(folder('  Provas: fotos/áudios  ').name).to eq('Provas fotos áudios')
  end

  it 'recusa nome repetido entre irmãs, sem diferenciar maiúsculas' do
    folder('Provas')

    duplicate = described_class.new(account: account, contact: contact, name: 'provas')
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it 'aceita o mesmo nome em pastas-mãe diferentes' do
    a = folder('A')
    b = folder('B')
    folder('Provas', parent: a)

    expect(described_class.new(account: account, contact: contact, parent: b, name: 'Provas')).to be_valid
  end

  it 'libera o nome quando a pasta anterior foi arquivada' do
    folder('Provas').update!(archived_at: Time.current)

    expect { folder('Provas') }.not_to raise_error
  end

  it 'limita a árvore a cinco níveis' do
    parent = nil
    5.times { |i| parent = folder("Nível #{i + 1}", parent: parent) }

    sixth = described_class.new(account: account, contact: contact, parent: parent, name: 'Nível 6')
    expect(sixth).not_to be_valid
    expect(sixth.errors[:parent]).to be_present
  end

  it 'não deixa mover uma pasta para dentro de uma subpasta dela' do
    top = folder('Topo')
    child = folder('Filha', parent: top)

    top.parent = child
    expect(top).not_to be_valid
  end

  it 'não aceita pasta-mãe de outro contato' do
    other = described_class.create!(account: account, contact: create(:contact, account: account), name: 'Alheia')

    expect(described_class.new(account: account, contact: contact, parent: other, name: 'X')).not_to be_valid
  end

  it 'monta a linhagem da raiz até a pasta' do
    top = folder('Topo')
    child = folder('Filha', parent: top)

    expect(child.lineage.map(&:name)).to eq(%w[Topo Filha])
  end
end
