require 'rails_helper'

RSpec.describe Crm::Documents::BlobCloner do
  let(:original) do
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\nconteudo\n"), filename: 'rg.pdf',
                                           content_type: 'application/pdf')
  end

  it 'cria um blob novo com o mesmo conteúdo e metadados' do
    clone = described_class.call(original)

    expect(clone.id).not_to eq(original.id)
    expect(clone.key).not_to eq(original.key)
    expect(clone).to have_attributes(checksum: original.checksum, byte_size: original.byte_size,
                                     content_type: 'application/pdf', filename: original.filename)
    expect(clone.download).to eq(original.download)
  end

  it 'no disco, é um hardlink: mesmo conteúdo físico, sem espaço extra' do
    clone = described_class.call(original)
    service = original.service

    expect(File.stat(service.path_for(clone.key)).ino).to eq(File.stat(service.path_for(original.key)).ino)
  end

  it 'continua existindo quando o original é apagado' do
    clone = described_class.call(original)
    original.purge

    expect(clone.reload.download).to start_with('%PDF')
  end

  it 'copia os bytes quando o volume não aceita hardlink' do
    allow(File).to receive(:link).and_raise(Errno::EXDEV)

    clone = described_class.call(original)

    expect(clone.download).to eq(original.download)
  end
end
