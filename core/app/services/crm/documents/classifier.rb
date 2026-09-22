# Sugestão de tipo por regras determinísticas (PROJETO-COFRE-DOCUMENTOS.md §7.3,
# camada 1): legenda do cliente e nome do arquivo contra os padrões do catálogo
# da conta. Sem IA e sem custo. É só sugestão — quem classifica é a equipe (D9).
class Crm::Documents::Classifier
  def initialize(account)
    @account = account
  end

  # A legenda vem primeiro: "segue meu rg" diz mais que "IMG-20260922-WA0012".
  def suggest(caption:, filename:)
    [caption, File.basename(filename.to_s, '.*')].each do |text|
      normalized = normalize(text)
      next if normalized.blank?

      match = rules.find { |_slug, regexes| regexes.any? { |regex| regex.match?(normalized) } }
      return match.first if match
    end
    nil
  end

  private

  def normalize(text)
    I18n.transliterate(text.to_s).downcase.tr('_-', '  ').squeeze(' ').strip
  end

  def rules
    @rules ||= @account.crm_document_types.active.ordered.filter_map do |type|
      regexes = compile(type.patterns)
      [type.slug, regexes] if regexes.any?
    end
  end

  # Padrão inválido cadastrado pela conta é ignorado, nunca derruba a captura.
  def compile(patterns)
    Array(patterns).filter_map do |pattern|
      Regexp.new(pattern, Regexp::IGNORECASE)
    rescue RegexpError
      nil
    end
  end
end
