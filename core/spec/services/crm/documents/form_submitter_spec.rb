require 'rails_helper'

# PROJETO-COFRE-DOCUMENTOS.md §8.7 — formulário montado pela conta.
RSpec.describe Crm::Documents::FormSubmitter do
  let(:account) { create(:account) }
  let(:form) do
    account.crm_document_forms.create!(
      name: 'Envio de documentos',
      fields: [
        { key: 'nome', label: 'Nome completo', type: 'text', required: true, maps_to: 'contact_name' },
        { key: 'whatsapp', label: 'WhatsApp', type: 'phone', required: true, maps_to: 'contact_phone' },
        { key: 'cpf', label: 'CPF', type: 'cpf' },
        { key: 'assunto', label: 'Assunto', type: 'radio', required: true, options: %w[Compra Aluguel] },
        { key: 'renda', label: 'Renda mensal', type: 'number', show_if: { field: 'assunto', equals: 'Aluguel' } }
      ],
      document_items: [
        { key: 'identidade', label: 'Documento com foto', doc_type: 'documento_identidade', required: true },
        { key: 'renda_doc', label: 'Comprovante de renda', doc_type: 'comprovante_renda', multiple: true,
          show_if: { field: 'assunto', equals: 'Aluguel' } }
      ]
    )
  end
  let(:answers) { { nome: 'Joana Lima', whatsapp: '(61) 98765-4321', assunto: 'Compra' } }

  before { crm_documents_enable!(account, preset: 'geral') }

  def pdf(name = 'doc.pdf')
    crm_pdf_upload(name, "#{CrmDocumentsHelpers::PDF_BYTES}%#{SecureRandom.hex(4)}")
  end

  def submit(answers: self.answers, files: { identidade: [pdf] }, consent: '1', link: nil)
    described_class.new(form: form, answers: answers, files: files, consent: consent, link: link,
                        ip: '1.2.3.4', user_agent: 'rspec').call
  end

  it 'cria o contato, o envio com protocolo e guarda o arquivo na triagem com o tipo sugerido' do
    result = submit

    expect(result).to be_success
    submission = result.submission
    expect(submission.protocol).to match(/\A#{Time.current.year}-000001\z/)
    expect(submission).to have_attributes(match_status: 'new_contact', verified: false, documents_count: 1)
    expect(submission.contact).to have_attributes(name: 'Joana Lima', phone_number: '+5561987654321')
    document = submission.documents.first
    expect(document.crm_document_folder.slot).to eq('triagem')
    expect(document).to have_attributes(source: 'portal', uploaded_by_contact: true, doc_type: nil)
    expect(document.meta).to include('suggested_doc_type' => 'documento_identidade', 'unverified' => true,
                                     'protocol' => submission.protocol)
  end

  it 'reconhece contato existente pelo telefone sem alterar o cadastro dele' do
    existing = account.contacts.create!(name: 'Joana Cadastrada', phone_number: '+5561987654321')

    submission = submit.submission

    expect(submission).to have_attributes(contact_id: existing.id, match_status: 'matched_phone')
    expect(existing.reload.name).to eq('Joana Cadastrada')
  end

  it 'pelo link personalizado usa o contato do link, não pede identificação e entra verificado' do
    contact = account.contacts.create!(name: 'Cliente do link')
    link, = CrmDocumentFormLink.issue!(form: form, contact: contact)

    result = submit(answers: { assunto: 'Compra' }, link: link)

    expect(result).to be_success
    expect(result.submission).to have_attributes(contact_id: contact.id, match_status: 'link', verified: true)
  end

  it 'valida respostas por tipo e exige os obrigatórios visíveis' do
    result = submit(answers: answers.merge(cpf: '111.111.111-11'), files: {})

    expect(result.errors).to include('cpf' => 'CPF inválido.', 'identidade' => 'Envie este documento.')
    expect(CrmDocumentSubmission.count).to eq(0)
  end

  it 'só considera campos e documentos condicionais quando a condição vale' do
    compra = submit(answers: answers.merge(renda: 'abc'), files: { identidade: [pdf], renda_doc: [pdf('r.pdf')] })
    expect(compra.submission.answers).not_to have_key('renda')
    expect(compra.submission.documents.count).to eq(1)

    aluguel = submit(answers: answers.merge(assunto: 'Aluguel', renda: '3500'),
                     files: { identidade: [pdf], renda_doc: [pdf('r1.pdf'), pdf('r2.pdf')] })
    expect(aluguel.submission.answers).to include('renda' => '3500')
    expect(aluguel.submission.documents.count).to eq(3)
  end

  it 'exige a ciência LGPD' do
    expect(submit(consent: '0').errors).to have_key('consent')
  end

  it 'recusa mais de um arquivo em item de arquivo único' do
    html = crm_pdf_upload('x.html', '<html><body>x</body></html>')

    result = submit(files: { identidade: [pdf], renda_doc: [] }.merge(identidade: [pdf, html]))

    expect(result.errors).to include('identidade' => 'Envie só um arquivo aqui.')
  end

  it 'avisa o arquivo recusado e grava o resto' do
    form.update!(document_items: form.document_items.map { |i| i.merge('multiple' => true) })
    html = crm_pdf_upload('x.html', '<html><body>x</body></html>')

    result = submit(files: { identidade: [pdf, html] })

    expect(result).to be_success
    expect(result.rejected.first).to include(item: 'identidade', filename: 'x.html')
    expect(result.submission.documents_count).to eq(1)
  end

  it 'recusa envio que passa do teto total de bytes' do
    stub_const("#{described_class}::MAX_TOTAL_BYTES", 10)

    result = submit

    expect(result.errors['files']).to include('100 MB')
    expect(CrmDocumentSubmission.count).to eq(0)
  end

  # Revisão de segurança (22/09): quem digita o telefone de outra pessoa não
  # consegue inundar a Triagem dela.
  it 'limita os envios não verificados para o mesmo contato e não cria nada no excedente' do
    stub_const("#{described_class}::MAX_UNVERIFIED_PER_CONTACT", 2)
    2.times { expect(submit).to be_success }

    result = submit

    expect(result.errors['form']).to include('muitos envios')
    expect(CrmDocumentSubmission.count).to eq(2)
    expect(CrmDocument.count).to eq(2)
  end

  it 'não limita o link personalizado, que é verificado' do
    stub_const("#{described_class}::MAX_UNVERIFIED_PER_CONTACT", 1)
    contact = submit.submission.contact
    link, = CrmDocumentFormLink.issue!(form: form, contact: contact)

    expect(submit(answers: { assunto: 'Compra' }, link: link)).to be_success
  end

  it 'numera os protocolos em sequência dentro do ano' do
    first = submit.submission
    second = submit(answers: answers.merge(whatsapp: '61912345678')).submission

    expect(second.protocol.split('-').last.to_i).to eq(first.protocol.split('-').last.to_i + 1)
  end
end
