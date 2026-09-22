# Limpa um nome de pasta ou arquivo para que funcione em todos os destinos:
# tela, ext4 (espelho na VPS), Google Drive e .zip extraído no Windows
# (PROJETO-COFRE-DOCUMENTOS.md §5.5). Acentos ficam; só sai o que quebra algo.
module Crm::Documents::Naming::Sanitizer
  FORBIDDEN = %r{[/\\:*?"<>|]}
  CONTROL = /[\u0000-\u001F\u007F]/
  WINDOWS_RESERVED = /\A(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|\z)/i
  DEFAULT_FALLBACK = 'Sem nome'.freeze

  module_function

  def call(text, max: nil, fallback: DEFAULT_FALLBACK)
    value = normalize(text)
    value = truncate(value, max) if max
    value = value.sub(/\A[.\s]+/, '').sub(/[.\s]+\z/, '')
    value = value.sub(WINDOWS_RESERVED) { "#{Regexp.last_match(1)}_#{Regexp.last_match(2)}" }
    value.presence || fallback
  end

  def normalize(text)
    text.to_s
        .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        .unicode_normalize(:nfc)
        .gsub(CONTROL, '')
        .gsub(FORBIDDEN, ' ')
        .gsub(/\s+/, ' ')
        .strip
  end

  def truncate(value, max)
    return value if value.length <= max

    value[0, max].rstrip
  end
end
