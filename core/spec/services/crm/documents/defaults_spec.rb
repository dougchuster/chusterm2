require 'rails_helper'

# Modelos de documentos por área: o CRM atende várias verticais, então o
# padrão é universal e o jurídico é só um dos modelos.
RSpec.describe Crm::Documents::Defaults do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account, name: 'Ana Souza') }

  it 'lista os modelos disponíveis' do
    expect(described_class.presets.pluck(:slug)).to include('geral', 'legal', 'clinic', 'real_estate', 'education')
  end

  it 'conta nova começa no modelo geral, sem nenhum termo jurídico' do
    described_class.ensure!(account)

    expect(account.crm_document_setting.preset).to eq('geral')
    expect(account.crm_document_types.pluck(:slug)).not_to include('cnis', 'peticao', 'ppp')
    names = Crm::Documents::DrawerProvisioner.new(contact).ensure!.map(&:name)
    expect(names).to include('04 Negócios', '05 Enviados pela Equipe')
    expect(names.join).not_to include('Processo')
  end

  it 'usa o modelo do pack vertical instalado na conta' do
    account.crm_account_packs.create!(slug: 'clinic', installed_at: Time.current)

    described_class.ensure!(account)

    expect(account.crm_document_setting.preset).to eq('clinic')
    expect(account.crm_document_types.pluck(:slug)).to include('exame', 'receita')
  end

  it 'reconhece conta que já usava o catálogo jurídico antes dos modelos' do
    account.crm_document_types.create!(slug: 'cnis', label: 'CNIS', target_slot: 'processo_docs')

    described_class.ensure!(account)

    expect(account.crm_document_setting.preset).to eq('legal')
  end

  it 'troca de modelo sem apagar tipos nem pastas existentes' do
    described_class.ensure!(account)
    Crm::Documents::DrawerProvisioner.new(contact).ensure!

    described_class.apply_preset!(account, 'real_estate')

    expect(account.crm_document_types.pluck(:slug)).to include('documento_identidade', 'matricula_imovel')
    expect(account.crm_document_folder_templates.client_scope.first.nodes.pluck('name')).to include('03 Negociações')
    expect(CrmDocumentFolder.where(contact: contact).pluck(:name)).to include('04 Negócios')
  end

  it 'aplica o padrão de nome editado pela conta' do
    described_class.ensure!(account)
    account.crm_document_setting.update!(naming: { 'file' => '{cliente} - {tipo} ({data})',
                                                   'client_folder' => '{codigo} {nome}' })

    document = crm_document_for(contact, doc_type: 'cpf')

    expect(document.file_name).to match(/\AAna Souza - CPF \(\d{4}-\d{2}-\d{2}\)\.pdf\z/)
    expect(Crm::Documents::Naming::PathBuilder.client_folder_name(contact)).to eq("#{contact.id.to_s.rjust(6, '0')} Ana Souza")
  end

  it 'recusa padrão de nome inválido' do
    described_class.ensure!(account)

    expect { account.crm_document_setting.update!(naming: { 'client_folder' => '{nome}' }) }
      .to raise_error(ActiveRecord::RecordInvalid, /codigo/)
  end
end
