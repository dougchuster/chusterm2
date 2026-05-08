class Captain::Conversation::ResponsePolicyService
  FALLBACK_RESPONSE = 'Entendi. Pode me contar com calma o que aconteceu para eu entender melhor?'.freeze

  BANNED_REPLACEMENTS = [
    [/\bSou a Dra\.?\s+Julia,\s+do\s+Coimbra\s*&\s*Ruas\s+Advocacia\b/i, 'Sou a Dra. Julia, advogada do Coimbra & Ruas Advocacia'],
    [/\bsou a Dra\.?\s+Julia,\s+do\s+Coimbra\s*&\s*Ruas\s+Advocacia\b/i, 'sou a Dra. Julia, advogada do Coimbra & Ruas Advocacia'],
    [/\bpoxa,?\s*/i, ''],
    [/\bé um absurdo\b/i, 'é um ponto importante'],
    [/\babsurdo\b/i, 'ponto importante'],
    [/\bsitua[cç][aã]o frustrante\b/i, 'situação que precisa ser analisada'],
    [/\bfrustrante\b/i, 'que precisa ser analisado'],
    [/\bimagino (?:o quanto|como)[^.?!\n]*(?:[.?!]|\n)?/i, ''],
    [/\bsinto muito(?: mesmo)?(?: por isso)?[.?!]?/i, ''],
    [/\bse puder,?\s*/i, ''],
    [/\bse conseguir,?\s*/i, ''],
    [/\bsem pressa,?\s*[ée] s[oó] pra a gente ganhar tempo[.?!]?/i, ''],
    [/\bsem pressa,?\s*[ée] s[oó] para a gente ganhar tempo[.?!]?/i, ''],
    [/\bs[oó] pra a gente ganhar tempo[.?!]?/i, ''],
    [/\bs[oó] para a gente ganhar tempo[.?!]?/i, '']
  ].freeze

  TITLE_TOKENS = %w[dr dra doutor doutora sr sra senhor senhora].freeze

  pattr_initialize [:conversation!, :assistant]

  def apply(content)
    text = content.to_s.dup
    BANNED_REPLACEMENTS.each { |pattern, replacement| text.gsub!(pattern, replacement) }
    text = remove_public_formatting(text)
    text = collapse_repeated_name_mentions(text)
    text = normalize_spacing(text)
    text = capitalize_first_letter(text)
    text.presence || FALLBACK_RESPONSE
  end

  private

  def remove_public_formatting(text)
    text
      .gsub(/\*\*|__|`/, '')
      .gsub(/^[ \t]*[-*]\s+/m, '')
      .gsub(/[#{emoji_ranges}]/, '')
      .gsub(/[–—]/, '-')
  end

  def emoji_ranges
    "\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}"
  end

  def collapse_repeated_name_mentions(text)
    name = client_first_name
    return text if name.blank?

    count = 0
    text.gsub(flexible_name_regex(name)) do |match|
      count += 1
      count == 1 ? match : ''
    end
  end

  def client_first_name
    contact_name = conversation.contact&.name.to_s.strip
    return if contact_name.blank?
    return if contact_name.match?(/\A\+?\d+\z/)

    contact_name.split.find { |token| TITLE_TOKENS.exclude?(I18n.transliterate(token).downcase.delete('.')) }
  end

  def flexible_name_regex(name)
    chars = name.chars.map { |char| accent_flexible_char(char) }.join
    /\b#{chars}\b,?\s*/i
  end

  def accent_flexible_char(char)
    case I18n.transliterate(char).downcase
    when 'a' then '[aàáâãä]'
    when 'e' then '[eèéêë]'
    when 'i' then '[iìíîï]'
    when 'o' then '[oòóôõö]'
    when 'u' then '[uùúûü]'
    when 'c' then '[cç]'
    else Regexp.escape(char)
    end
  end

  def normalize_spacing(text)
    text
      .gsub(/[ \t]+/, ' ')
      .gsub(/[ \t]+\n/, "\n")
      .gsub(/\n{3,}/, "\n\n")
      .gsub(/\A[,\s.]+/, '')
      .strip
  end

  def capitalize_first_letter(text)
    return text if text.blank?

    text.sub(/\A([[:alpha:]])/) { Regexp.last_match(1).upcase }
  end
end
