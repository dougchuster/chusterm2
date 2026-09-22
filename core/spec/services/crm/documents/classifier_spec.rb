require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §7.3 — camada 1: regras determinísticas, sem IA.
# A legenda do cliente ("segue meu rg") é o melhor sinal e vem antes do nome.
RSpec.describe Crm::Documents::Classifier do
  let(:account) { create(:account) }
  let(:classifier) { described_class.new(account) }

  before { Crm::Documents::Defaults.ensure!(account) }

  {
    ['segue meu rg', 'IMG-20260922-WA0012.jpg'] => 'rg',
    ['', 'CNIS_maria.pdf'] => 'cnis',
    ['comprovante de residência', 'foto.jpg'] => 'comprovante_residencia',
    ['conta de luz de agosto', 'x.pdf'] => 'comprovante_residencia',
    ['Certidão de Casamento', 'scan.pdf'] => 'certidao_casamento',
    ['minha carteira de trabalho', 'ctps.jpg'] => 'ctps',
    ['holerite', 'contracheque_julho.pdf'] => 'holerite',
    ['PROCURAÇÃO ASSINADA', 'doc.pdf'] => 'procuracao'
  }.each do |(caption, filename), expected|
    it "sugere #{expected} para \"#{caption}\" / #{filename}" do
      expect(classifier.suggest(caption: caption, filename: filename)).to eq(expected)
    end
  end

  it 'prefere a legenda ao nome do arquivo' do
    expect(classifier.suggest(caption: 'meu cpf', filename: 'rg.jpg')).to eq('cpf')
  end

  it 'não sugere nada quando nenhuma regra casa' do
    expect(classifier.suggest(caption: 'bom dia', filename: 'IMG-20260922-WA0012.jpg')).to be_nil
  end

  it 'não confunde palavra que só contém a sigla' do
    expect(classifier.suggest(caption: 'o orgão respondeu', filename: 'x.pdf')).to be_nil
  end

  it 'ignora padrão inválido cadastrado pela conta' do
    account.crm_document_types.find_by(slug: 'rg').update!(patterns: ['(sem fechar'])

    expect { classifier.suggest(caption: 'rg', filename: 'x.pdf') }.not_to raise_error
  end
end
