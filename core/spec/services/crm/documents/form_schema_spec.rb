require 'rails_helper'

RSpec.describe Crm::Documents::FormSchema do
  let(:account) { create(:account) }
  let(:base_fields) do
    [{ key: 'nome', label: 'Nome completo', type: 'text', required: true, maps_to: 'contact_name' },
     { key: 'whatsapp', label: 'WhatsApp', type: 'phone', required: true, maps_to: 'contact_phone' }]
  end

  before { Crm::Documents::Defaults.ensure!(account, preset: 'legal') }

  def errors_for(fields: base_fields, items: [], settings: {})
    form = CrmDocumentForm.new(account: account, name: 'F', fields: fields, document_items: items, settings: settings)
    described_class.new(form).errors
  end

  it 'aceita um formulário mínimo com nome e telefone' do
    expect(errors_for).to be_empty
  end

  it 'exige identificar o contato por nome e telefone ou e-mail' do
    expect(errors_for(fields: [base_fields.first]).join).to include('telefone ou e-mail')
  end

  it 'recusa chave repetida ou inválida e tipo desconhecido' do
    fields = base_fields + [{ key: 'nome', label: 'X', type: 'text' }, { key: 'Com Espaço', label: 'Y', type: 'foto' }]

    errors = errors_for(fields: fields).join(' | ')
    expect(errors).to include('chave repetida', 'chave inválida', 'tipo de campo desconhecido')
  end

  it 'exige opções nos campos de escolha' do
    expect(errors_for(fields: base_fields + [{ key: 'assunto', label: 'Assunto', type: 'select' }]).join)
      .to include('informe as opções')
  end

  it 'aceita condição que aponta para um campo de escolha anterior' do
    fields = base_fields + [
      { key: 'assunto', label: 'Assunto', type: 'radio', options: %w[Trabalho Família] },
      { key: 'empresa', label: 'Empresa', type: 'text', show_if: { field: 'assunto', equals: 'Trabalho' } }
    ]
    items = [{ key: 'ctps', label: 'Carteira de trabalho', show_if: { field: 'assunto', equals: 'Trabalho' } }]

    expect(errors_for(fields: fields, items: items)).to be_empty
  end

  it 'recusa condição que aponta para campo posterior ou de texto' do
    fields = base_fields + [{ key: 'empresa', label: 'Empresa', type: 'text', show_if: { field: 'nome', equals: 'x' } }]

    expect(errors_for(fields: fields).join).to include('campo de escolha que vem antes')
  end

  it 'recusa documento com tipo fora do catálogo da conta' do
    expect(errors_for(items: [{ key: 'x', label: 'X', doc_type: 'inexistente' }]).join).to include('não existe no catálogo')
  end

  it 'limita o tamanho dos textos' do
    expect(errors_for(settings: { intro: 'a' * 2001 }).join).to include('intro')
  end
end
