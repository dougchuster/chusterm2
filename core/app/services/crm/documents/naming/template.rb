# Padrões de nome editáveis pela conta (PROJETO-COFRE-DOCUMENTOS.md §5.3):
#
#   '{data} — {tipo} — {descricao}'   →   '2026-09-22 — RG — Frente e verso'
#
# Cada marcador é limpo pelo Sanitizer. Marcador vazio não deixa separador
# sobrando ("2026-09-22 — RG" e não "2026-09-22 — RG — "). Quando o limite de
# tamanho estoura, encolhe só os marcadores "encolhíveis" (descrição, nome
# original), nunca a data ou o tipo.
module Crm::Documents::Naming::Template
  TOKEN = /\{([a-z_]+)\}/
  SEPARATOR_CHARS = '—·|'.freeze
  REPEATED_SEPARATORS = /(?:\s*[#{SEPARATOR_CHARS}]\s*){2,}/
  EDGE_SEPARATORS_START = /\A[\s#{SEPARATOR_CHARS}]+/
  EDGE_SEPARATORS_END = /[\s#{SEPARATOR_CHARS}]+\z/

  # Marcadores aceitos em cada padrão e os que precisam aparecer (unicidade).
  SPECS = {
    'file' => { allowed: %w[data tipo descricao cliente codigo nome_original], required_any: %w[tipo descricao nome_original] },
    'triage_file' => { allowed: %w[data data_hora origem nome_original cliente codigo], required_any: %w[nome_original] },
    'client_folder' => { allowed: %w[nome codigo], required_any: %w[codigo] },
    'case_folder' => { allowed: %w[ano numero titulo cliente codigo], required_any: %w[numero] }
  }.freeze

  module_function

  # Aceita os valores como hash ou como argumentos nomeados.
  def render(template, values = nil, max: nil, shrink: [], **tokens)
    values = (values || tokens).transform_keys(&:to_s)
    text = cleanup(substitute(template, values))
    return text if max.nil? || text.length <= max

    Crm::Documents::Naming::Sanitizer.call(shrink_to_fit(template, values, max, shrink), max: max)
  end

  def shrink_to_fit(template, values, max, shrink)
    shrink.map(&:to_s).each do |key|
      overflow = cleanup(substitute(template, values)).length - max
      break if overflow <= 0

      current = values[key].to_s
      values[key] = current[0, [current.length - overflow, 0].max].to_s.rstrip
    end
    cleanup(substitute(template, values))
  end

  def tokens(template)
    template.to_s.scan(TOKEN).flatten
  end

  # Erros legíveis para a tela de configuração; vazio = padrão válido.
  def errors_for(kind, template)
    spec = SPECS.fetch(kind.to_s)
    used = tokens(template)
    errors = []
    unknown = used - spec[:allowed]
    errors << "marcadores desconhecidos: #{unknown.map { |t| "{#{t}}" }.join(', ')}" if unknown.any?
    errors << "precisa conter #{spec[:required_any].map { |t| "{#{t}}" }.join(' ou ')}" unless used.intersect?(spec[:required_any])
    errors << 'contém caracteres não permitidos em nomes de arquivo' if template.to_s.gsub(TOKEN, '').match?(%r{[/\\:*?"<>|]})
    errors
  end

  def substitute(template, values)
    template.to_s.gsub(TOKEN) do
      Crm::Documents::Naming::Sanitizer.call(values[Regexp.last_match(1)].to_s, fallback: '')
    end
  end

  def cleanup(text)
    text.gsub(REPEATED_SEPARATORS) { |match| " #{match.strip[0]} " }
        .sub(EDGE_SEPARATORS_START, '')
        .sub(EDGE_SEPARATORS_END, '')
        .gsub(/\s+/, ' ')
        .strip
  end
end
