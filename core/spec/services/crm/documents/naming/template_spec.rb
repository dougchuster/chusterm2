require 'rails_helper'

RSpec.describe Crm::Documents::Naming::Template do
  let(:file) { '{data} — {tipo} — {descricao}' }

  it 'substitui os marcadores' do
    expect(described_class.render(file, data: '2026-09-22', tipo: 'RG', descricao: 'Frente e verso'))
      .to eq('2026-09-22 — RG — Frente e verso')
  end

  it 'não deixa separador sobrando quando um marcador vem vazio' do
    expect(described_class.render(file, data: '2026-09-22', tipo: 'RG', descricao: '')).to eq('2026-09-22 — RG')
    expect(described_class.render(file, data: '2026-09-22', tipo: '', descricao: 'X')).to eq('2026-09-22 — X')
    expect(described_class.render('{tipo} · {cliente}', tipo: '', cliente: 'Maria')).to eq('Maria')
  end

  it 'aceita padrões diferentes do padrão do sistema' do
    expect(described_class.render('{cliente} - {tipo} ({data})', cliente: 'Maria', tipo: 'CPF', data: '2026-09-22'))
      .to eq('Maria - CPF (2026-09-22)')
  end

  it 'limpa caracteres proibidos vindos dos valores' do
    expect(described_class.render(file, data: '2026-09-22', tipo: 'RG', descricao: 'a/b?'))
      .to eq('2026-09-22 — RG — a b')
  end

  it 'encolhe só o marcador indicado quando passa do limite' do
    name = described_class.render(file, { data: '2026-09-22', tipo: 'RG', descricao: 'x' * 300 },
                                  max: 40, shrink: [:descricao])

    expect(name.length).to be <= 40
    expect(name).to start_with('2026-09-22 — RG — xxx')
  end

  describe '.errors_for' do
    it 'aceita o padrão do sistema' do
      expect(described_class.errors_for('file', file)).to be_empty
    end

    it 'recusa marcador desconhecido' do
      expect(described_class.errors_for('file', '{data} {sobrenome}').join).to include('{sobrenome}')
    end

    it 'exige o código na pasta do cliente, para não misturar homônimos' do
      expect(described_class.errors_for('client_folder', '{nome}').join).to include('{codigo}')
    end

    it 'recusa caractere proibido fora dos marcadores' do
      expect(described_class.errors_for('file', '{data}/{tipo}').join).to include('não permitidos')
    end
  end
end
