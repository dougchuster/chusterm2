require 'rails_helper'

RSpec.describe Crm::Documents::DrawerProvisioner do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }

  before { Crm::Documents::Defaults.ensure!(account, preset: 'legal') }

  it 'cria as sete pastas do modelo na ordem certa' do
    names = described_class.new(contact).ensure!.map(&:name)

    expect(names).to eq(['00 Triagem', '01 Documentos Pessoais', '02 Comprovantes', '03 Procurações e Contratos',
                         '04 Processos', '05 Enviados pelo Escritório', '99 Arquivo'])
  end

  it 'é idempotente' do
    described_class.new(contact).ensure!

    expect { described_class.new(contact).ensure! }.not_to change(CrmDocumentFolder, :count)
  end

  it 'reconhece a pasta do modelo pelo slot mesmo depois de renomeada' do
    folders = described_class.new(contact).ensure!
    folders.find { |f| f.slot == 'pessoais' }.update!(name: 'Pessoais da Maria')

    expect { described_class.new(contact).ensure! }.not_to change(CrmDocumentFolder, :count)
  end

  it 'marca as pastas do modelo como system' do
    expect(described_class.new(contact).ensure!.map(&:kind).uniq).to eq(['system'])
  end
end
