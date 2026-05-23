class Captain::Conversation::ResponsePolicyService
  FALLBACK_RESPONSE = 'Entendi. Pode me contar com calma o que aconteceu para eu entender melhor?'.freeze

  BANNED_REPLACEMENTS = [
    [/\bA simula[cç][aã]o do Meu INSS ajuda como ponto de partida, mas n[aã]o garante o direito nem substitui a leitura dos documentos\.?/i,
     'O simulador do Meu INSS não é parâmetro seguro; a análise precisa considerar CNIS, vínculos, remunerações, contribuições e documentos.'],
    [/\bse voc[eê] j[aá] fez alguma simula[cç][aã]o ou pedido\b/i, 'se você já fez algum pedido'],
    [/\bsimula[cç][aã]o pelo aplicativo Meu INSS\b/i, 'CNIS atualizado'],
    [/\bsimula[cç][aã]o do Meu INSS\b/i, 'CNIS atualizado'],
    [/\bsimula[cç][aã]o Meu INSS\b/i, 'CNIS atualizado'],
    [/\bsimulador do (?:Meu )?INSS\b/i, 'CNIS atualizado'],
    [/\bSou a Dra\.?\s+Julia,\s+do\s+Coimbra\s*&\s*Ruas\s+Advocacia\b/i, 'Sou a Dra. Julia, advogada do Coimbra & Ruas Advocacia'],
    [/\bsou a Dra\.?\s+Julia,\s+do\s+Coimbra\s*&\s*Ruas\s+Advocacia\b/i, 'sou a Dra. Julia, advogada do Coimbra & Ruas Advocacia'],
    [/\bpoxa,?\s*/i, ''],
    [/\bé um absurdo\b/i, 'é um ponto importante'],
    [/\babsurdo\b/i, 'ponto importante'],
    [/\bsitua[cç][aã]o frustrante\b/i, 'situação que precisa ser analisada'],
    [/\bfrustrante\b/i, 'que precisa ser analisado'],
    [/\bimagino (?:o quanto|como)[^.?!\n]*(?:[.?!]|\n)?/i, ''],
    [/\bsinto muito(?: mesmo)?(?: por isso)?[.?!]?/i, ''],
    [/\bidade aproximada(?:\s+ou\s+ano\s+de\s+nascimento)?\b/i, 'idade'],
    [/\b(me\s+)?respond[ae]\s+(?:mais\s+)?tr\S*s\s+(?:perguntas|coisas)[:：]?\s*/i, 'me responda: '],
    [/\bgarantir uma aposentadoria tranquila\b/i, 'organizar melhor o caminho para a aposentadoria'],
    [/\bretornaremos com um retorno detalhado em breve\b/i, 'a equipe entrará em contato novamente em breve'],
    [/\bretornaremos com um retorno\b/i, 'a equipe entrará em contato novamente'],
    [/\s*para que a equipe possa (?:te|lhe) orientar da melhor forma\.?/i, '.'],
    [/\s*para que a equipe possa retornar com uma orienta[cç][aã]o precisa\.?/i, '.'],
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
    text = cleanup_repeated_document_terms(text)
    text = limit_questions_for_stepwise_triage(text)
    text = remove_public_formatting(text)
    text = collapse_repeated_name_mentions(text)
    text = fix_interrogative_case_after_comma(text)
    text = normalize_spacing(text)
    text = capitalize_first_letter(text)
    text.presence || FALLBACK_RESPONSE
  end

  private

  def cleanup_repeated_document_terms(text)
    text
      .gsub(/\bCNIS atualizado,\s*CNIS atualizado,\s*/i, 'CNIS atualizado, ')
      .gsub(/\bCNIS atualizado,\s*CNIS atualizado\s+e\s+/i, 'CNIS atualizado e ')
      .gsub(/\bCNIS atualizado,\s*CNIS atualizado\b/i, 'CNIS atualizado')
      .gsub(/\bCNIS atualizado;\s*CNIS atualizado;\s*/i, 'CNIS atualizado; ')
      .gsub(/\bCNIS atualizado;\s*CNIS atualizado\b/i, 'CNIS atualizado')
      .gsub(/,\s*,+/, ',')
      .gsub(/;\s*;+/, ';')
  end

  def limit_questions_for_stepwise_triage(text)
    return text unless ActiveModel::Type::Boolean.new.cast(assistant&.config&.dig('stepwise_triage'))
    return text if text.count('?') <= 1

    first_question_end = text.index('?')
    return text unless first_question_end

    text[0..first_question_end]
      .gsub(/\s*\d+\.\s*/, ' ')
      .gsub(/(?:preciso|gostaria)[^.?!\n]{0,160}(?:informa\S*es|perguntas)[^.?!\n]{0,160}[:：]\s*/i, '')
      .gsub(/\b(?:mais\s+)?tr\S*s perguntas r\S*pidas[:：]\s*/i, '')
  end

  def remove_public_formatting(text)
    text
      .gsub(/\*\*|__|`/, '')
      .gsub(/^[ \t]*[-*]\s+/m, '')
      .gsub(/(^|[;:\n]\s*)\d+\.\s+/, '\1')
      .gsub(/[#{emoji_ranges}]/, '')
      .gsub(/[–—]/, '-')
  end

  def emoji_ranges
    "\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}"
  end

  def fix_interrogative_case_after_comma(text)
    text.gsub(/([,:])\s+(Qual|Como|Quando|Onde|Voc\S*)\b/) do
      "#{Regexp.last_match(1)} #{Regexp.last_match(2).downcase}"
    end
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
