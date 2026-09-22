# Deriva o nome físico de um documento (PROJETO-COFRE-DOCUMENTOS.md §5.3):
#
#   classificado  2026-09-22 — RG — Frente e verso.pdf
#   sem descrição 2026-09-22 — CNIS.pdf
#   na triagem    2026-09-22 14h37 — WhatsApp — IMG-20260922-WA0012.jpg
#
# A extensão vem do tipo real do conteúdo (Active Storage identifica pelos
# magic bytes), não do nome que o cliente mandou.
class Crm::Documents::Naming::FileNamer
  MAX_BASE_LENGTH = 120
  SEPARATOR = ' — '.freeze
  OTHER_TYPE = 'outro'.freeze
  SOURCE_LABELS = {
    'whatsapp' => 'WhatsApp', 'email' => 'E-mail', 'instagram' => 'Instagram',
    'upload' => 'Envio da equipe', 'portal' => 'Portal', 'system' => 'Sistema'
  }.freeze

  def self.call(document)
    new(document).call
  end

  def initialize(document)
    @document = document
    @sanitizer = Crm::Documents::Naming::Sanitizer
  end

  def call
    "#{base_name}.#{Crm::Documents::Naming::Extension.for(@document.content_type, @document.original_filename)}"
  end

  private

  def base_name
    return triage_base if @document.doc_type.blank?

    prefix = [date_label, type_label].join(SEPARATOR)
    description = @document.doc_type == OTHER_TYPE ? nil : @document.description
    return @sanitizer.call(prefix, max: MAX_BASE_LENGTH) if description.blank?

    room = MAX_BASE_LENGTH - prefix.length - SEPARATOR.length
    return @sanitizer.call(prefix, max: MAX_BASE_LENGTH) if room < 1

    [prefix, @sanitizer.call(description, max: room, fallback: '')].reject(&:blank?).join(SEPARATOR)
  end

  def triage_base
    received = @document.received_at.in_time_zone(@document.time_zone)
    stamp = received.strftime('%Y-%m-%d %Hh%M')
    origin = SOURCE_LABELS.fetch(@document.source.to_s, 'Arquivo')
    original = File.basename(@document.original_filename.to_s, '.*')
    room = MAX_BASE_LENGTH - stamp.length - origin.length - (SEPARATOR.length * 2)
    [stamp, origin, @sanitizer.call(original, max: room, fallback: 'arquivo')].join(SEPARATOR)
  end

  def date_label
    date = @document.document_date || @document.received_at.in_time_zone(@document.time_zone).to_date
    date.strftime('%Y-%m-%d')
  end

  def type_label
    label = if @document.doc_type == OTHER_TYPE
              @document.description.presence || 'Documento'
            else
              @document.document_type&.label || @document.doc_type
            end
    @sanitizer.call(label, max: 60, fallback: 'Documento')
  end
end
