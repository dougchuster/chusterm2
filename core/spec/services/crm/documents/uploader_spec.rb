require 'rails_helper'

RSpec.describe Crm::Documents::Uploader do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:pdf) { "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n" }
  let(:jpeg) { "\xFF\xD8\xFF\xE0\x00\x10JFIF\x00".b + ('x' * 64) }
  let(:contact) { create(:contact, account: account) }

  before { Crm::Documents::Defaults.ensure!(account, preset: 'legal') }


  def upload(io_content: pdf, filename: 'documento.pdf', **attributes)
    described_class.new(contact: contact, io: StringIO.new(io_content), filename: filename,
                        source: 'upload', user: user, attributes: attributes).call
  end

  it 'guarda na triagem quando não há tipo nem pasta' do
    result = upload

    expect(result.document.crm_document_folder.slot).to eq('triagem')
    expect(result.document.file).to be_attached
    expect(result).not_to be_duplicate
  end

  it 'copia metadados do arquivo e registra quem enviou' do
    document = upload.document

    expect(document).to have_attributes(content_type: 'application/pdf', original_filename: 'documento.pdf',
                                        uploaded_by_user_id: user.id, byte_size: pdf.bytesize)
    expect(document.checksum).to be_present
  end

  it 'envia direto para a pasta do tipo quando o tipo é informado' do
    expect(upload(doc_type: 'rg').document.crm_document_folder.slot).to eq('pessoais')
  end

  it 'identifica o tipo real pelo conteúdo, não pela extensão' do
    document = upload(io_content: jpeg, filename: 'foto.pdf', doc_type: 'rg').document

    expect(document.content_type).to eq('image/jpeg')
    expect(document.file_name).to end_with('.jpg')
  end

  it 'não duplica o mesmo arquivo do mesmo contato' do
    first = upload.document
    second = upload(filename: 'de-novo.pdf')

    expect(second).to be_duplicate
    expect(second.document.id).to eq(first.id)
    expect(CrmDocument.count).to eq(1)
  end

  it 'recusa tipos de arquivo que não estão na lista permitida' do
    expect { upload(io_content: '<html><script>x</script></html>', filename: 'x.html') }
      .to raise_error(Crm::Documents::Uploader::InvalidFile, /não é aceito/)
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it 'recusa arquivo acima do limite' do
    stub_const("#{described_class}::MAX_BYTES", 10)

    expect { upload }.to raise_error(Crm::Documents::Uploader::InvalidFile, /limite/)
  end

  it 'registra a criação na auditoria' do
    document = upload.document

    expect(CrmAuditEvent.for_target('CrmDocument', document.id).pluck(:action)).to include('document_created')
  end
end
