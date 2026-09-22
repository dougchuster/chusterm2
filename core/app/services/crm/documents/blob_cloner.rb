# Cria um blob independente com o mesmo conteúdo de outro — a "cópia própria"
# que o documento capturado precisa para sobreviver à mensagem apagada.
#
# No serviço Disk (produção hoje: ext4 na VPS), a cópia é um HARDLINK: dois
# nomes para o mesmo conteúdo em disco, sem ocupar espaço extra, e apagar um
# não afeta o outro. Medido em 22/09/2026: copiar de verdade dobraria 4,5 GB
# (+1 GB/mês) na VPS da cliente. Em outros serviços (S3), copia os bytes.
class Crm::Documents::BlobCloner
  KEY_LENGTH = 28

  def self.call(blob)
    new(blob).call
  end

  def initialize(blob)
    @blob = blob
  end

  def call
    disk_service? ? hardlink_clone : byte_copy
  end

  private

  def disk_service?
    @blob.service.is_a?(ActiveStorage::Service::DiskService)
  end

  def hardlink_clone
    clone = build_clone
    target = @blob.service.path_for(clone.key)
    FileUtils.mkdir_p(File.dirname(target))
    File.link(@blob.service.path_for(@blob.key), target)
    clone.save!
    clone
  rescue Errno::EXDEV, Errno::EPERM, Errno::EMLINK, NotImplementedError
    # Volume que não aceita hardlink: cai na cópia normal, nunca falha a captura.
    byte_copy
  end

  def byte_copy
    @blob.open do |file|
      ActiveStorage::Blob.create_and_upload!(io: file, filename: @blob.filename.to_s, content_type: @blob.content_type,
                                             identify: false)
    end
  end

  def build_clone
    ActiveStorage::Blob.new(
      key: ActiveStorage::Blob.generate_unique_secure_token(length: KEY_LENGTH),
      filename: @blob.filename, content_type: @blob.content_type, byte_size: @blob.byte_size,
      checksum: @blob.checksum, metadata: @blob.metadata, service_name: @blob.service_name
    )
  end
end
