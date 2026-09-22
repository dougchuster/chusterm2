require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §5.5 — um único sanitizador vale para a tela, o
# espelho em disco, o Drive e o .zip. Cada caso abaixo já quebrou algum destino
# em algum sistema: por isso a tabela.
RSpec.describe Crm::Documents::Naming::Sanitizer do
  describe '.call' do
    {
      'mantém acentos' => ['Certidão de Óbito', 'Certidão de Óbito'],
      'normaliza NFD (iPhone/macOS) para NFC' => %w[Certidão Certidão],
      'troca caracteres proibidos por espaço' => ['a/b\\c:d*e?f"g<h>i|j', 'a b c d e f g h i j'],
      'remove caracteres de controle' => ["RG\u0000\u0007 frente", 'RG frente'],
      'colapsa espaços repetidos' => ["  RG   \t frente  ", 'RG frente'],
      'remove ponto e espaço no fim (Windows recusa)' => ['Procuração. . ', 'Procuração'],
      'remove pontos no início (arquivo oculto)' => ['..rg', 'rg'],
      'protege nome reservado do Windows' => %w[CON CON_],
      'protege nome reservado com extensão' => ['nul.pdf', 'nul_.pdf'],
      'não confunde palavra comum com reservado' => %w[Contrato Contrato],
      'mantém travessão e ponto médio da nomenclatura' => ['2026-09-22 — RG · C000123', '2026-09-22 — RG · C000123']
    }.each do |description, (input, expected)|
      it description do
        expect(described_class.call(input)).to eq(expected)
      end
    end

    it 'usa o fallback quando nada sobra' do
      expect(described_class.call('../..')).to eq('Sem nome')
      expect(described_class.call(nil, fallback: 'Documento')).to eq('Documento')
    end

    it 'trunca no limite de caracteres, não de bytes' do
      result = described_class.call('Á' * 200, max: 120)

      expect(result.length).to eq(120)
      expect(result).to be_valid_encoding
    end

    it 'não deixa espaço pendurado depois de truncar' do
      expect(described_class.call('abc defgh', max: 4)).to eq('abc')
    end
  end
end
