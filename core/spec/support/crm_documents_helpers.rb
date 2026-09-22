# Apoio aos specs do cofre de documentos.
module CrmDocumentsHelpers
  PDF_BYTES = "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF\n".freeze

  # Os specs do cofre foram escritos sobre o modelo jurídico (o primeiro).
  def crm_documents_enable!(account, preset: 'legal')
    Crm::Documents::Feature.enable!(account, preset: preset)
  end

  def crm_pdf_upload(name = 'documento.pdf', content = PDF_BYTES)
    file = Tempfile.new(['crm-doc', File.extname(name)])
    file.binmode
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'application/pdf', true, original_filename: name)
  end

  def crm_document_for(contact, **attrs)
    Crm::Documents::Uploader.new(
      contact: contact, io: StringIO.new(attrs.delete(:content) || "#{PDF_BYTES}#{SecureRandom.hex(4)}"),
      filename: 'documento.pdf', source: 'upload', attributes: attrs
    ).call.document
  end
end

RSpec.configure do |config|
  config.include CrmDocumentsHelpers
end
