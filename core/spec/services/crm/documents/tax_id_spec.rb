require 'rails_helper'

RSpec.describe Crm::Documents::TaxId do
  it 'aceita CPF e CNPJ válidos' do
    expect(described_class.cpf?('52998224725')).to be(true)
    expect(described_class.cnpj?('11222333000181')).to be(true)
  end

  it 'recusa dígito verificador errado, sequência repetida e tamanho errado' do
    expect(described_class.cpf?('52998224724')).to be(false)
    expect(described_class.cpf?('11111111111')).to be(false)
    expect(described_class.cpf?('123')).to be(false)
    expect(described_class.cnpj?('11222333000180')).to be(false)
    expect(described_class.cnpj?('00000000000000')).to be(false)
  end
end
