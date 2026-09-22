# Extensão canônica a partir do content type (já identificado pelo conteúdo).
# Cai na extensão original só quando o tipo é genérico ou desconhecido.
module Crm::Documents::Naming::Extension
  BY_CONTENT_TYPE = {
    'application/pdf' => 'pdf',
    'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp',
    'image/heic' => 'heic', 'image/heif' => 'heif', 'image/gif' => 'gif', 'image/tiff' => 'tiff',
    'audio/ogg' => 'ogg', 'audio/mpeg' => 'mp3', 'audio/mp4' => 'm4a', 'audio/aac' => 'aac',
    'audio/opus' => 'opus', 'audio/wav' => 'wav', 'audio/x-wav' => 'wav',
    'video/mp4' => 'mp4', 'video/quicktime' => 'mov', 'video/3gpp' => '3gp', 'video/webm' => 'webm',
    'application/msword' => 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'docx',
    'application/vnd.ms-excel' => 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'xlsx',
    'application/vnd.oasis.opendocument.text' => 'odt',
    'text/plain' => 'txt', 'text/csv' => 'csv',
    'application/zip' => 'zip', 'application/x-rar-compressed' => 'rar'
  }.freeze
  SAFE_EXTENSION = /\A[a-z0-9]{1,5}\z/
  FALLBACK = 'bin'.freeze

  module_function

  def for(content_type, original_filename = nil)
    BY_CONTENT_TYPE[content_type.to_s.split(';').first.to_s.strip.downcase] || original_extension(original_filename)
  end

  def original_extension(filename)
    ext = File.extname(filename.to_s).delete_prefix('.').downcase
    ext.match?(SAFE_EXTENSION) ? ext : FALLBACK
  end
end
