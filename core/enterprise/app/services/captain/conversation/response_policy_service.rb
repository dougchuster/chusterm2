class Captain::Conversation::ResponsePolicyService
  FALLBACK_RESPONSE = 'Entendi. Pode me contar com calma o que aconteceu para eu entender melhor?'.freeze
  REPEATED_INTRO_FALLBACK = 'Entendi. Vou seguir pelo contexto da conversa. Qual ponto voce quer priorizar agora?'.freeze
  MAX_RESPONSE_SENTENCES = 2
  MAX_RESPONSE_QUESTIONS = 1
  MAX_RESPONSE_CHARACTERS = 320

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
    [/\btudo bem(?: por aqui)?,?\s*(?:sim,?\s*)?obrigad[ao][!.]?/i, ''],
    [/\bimagino (?:o quanto|como)[^.?!\n]*(?:[.?!]|\n)?/i, ''],
    [/\bsinto muito(?: mesmo)?(?: por isso)?[.?!]?/i, ''],
    [/\bidade aproximada(?:\s+ou\s+ano\s+de\s+nascimento)?\b/i, 'idade'],
    [/\b(me\s+)?respond[ae]\s+(?:mais\s+)?tr\S*s\s+(?:perguntas|coisas)[:：]?\s*/i, 'me responda: '],
    [/\bgarantir uma aposentadoria tranquila\b/i, 'organizar melhor o caminho para a aposentadoria'],
    [/\bretornaremos com um retorno detalhado em breve\b/i, 'a equipe entrará em contato novamente em breve'],
    [/\bretornaremos com um retorno\b/i, 'a equipe entrará em contato novamente'],
    [/\bN[aã]o podemos atender chamadas por este canal\.?\s*Envie uma mensagem por escrito, por favor\.?/i,
     'Pode mandar mensagem por aqui ou usar os demais canais de contato do escritorio.'],
    [/\b(?:n[aã]o\s+(?:posso|podemos|conseguimos)|sem\s+condi[cç][aã]o\s+de)\s+(?:receber|atender)\s+(?:liga[cç][aãõo]o|liga[cç][aãõo]es|chamadas?)(?:\s+por\s+este\s+canal)?\.?/i,
     'Pode mandar mensagem por aqui ou usar os demais canais de contato do escritorio.'],
    [/\s*para que a equipe possa (?:te|lhe) orientar da melhor forma\.?/i, '.'],
    [/\s*para que a equipe possa retornar com uma orienta[cç][aã]o precisa\.?/i, '.'],
    [/\bsem pressa,?\s*[ée] s[oó] pra a gente ganhar tempo[.?!]?/i, ''],
    [/\bsem pressa,?\s*[ée] s[oó] para a gente ganhar tempo[.?!]?/i, ''],
    [/\bs[oó] pra a gente ganhar tempo[.?!]?/i, ''],
    [/\bs[oó] para a gente ganhar tempo[.?!]?/i, ''],
    [/\bse puder,?\s*/i, ''],
    [/\bse conseguir,?\s*/i, '']
  ].freeze

  TITLE_TOKENS = %w[dr dra doutor doutora sr sra senhor senhora].freeze

  pattr_initialize [:conversation!, :assistant]

  def apply(content)
    text = content.to_s.dup
    BANNED_REPLACEMENTS.each { |pattern, replacement| text.gsub!(pattern, replacement) }
    text = cleanup_repeated_document_terms(text)
    text = limit_questions_for_stepwise_triage(text)
    text = remove_public_formatting(text)
    text = suppress_repeated_intro(text)
    text = collapse_repeated_name_mentions(text)
    text = fix_interrogative_case_after_comma(text)
    text = normalize_spacing(text)
    text = remove_low_value_opening_sentence(text)
    text = enforce_brevity(text)
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

  def suppress_repeated_intro(text)
    return text unless previous_ai_response?

    stripped = text.sub(repeated_intro_regex, '').strip
    return text if stripped == text.strip

    stripped.presence || REPEATED_INTRO_FALLBACK
  end

  def previous_ai_response?
    conversation.messages
                .where(sender_type: 'Captain::Assistant', private: false)
                .exists?
  end

  def repeated_intro_regex
    /\A(?:ol[aá]|oi)[!.]?\s+(?:aqui\s+[ée]|sou)\s+.{0,220}?(?:como\s+posso\s+(?:te|lhe)\s+ajudar(?:\s+hoje)?|em\s+que\s+posso\s+(?:te|lhe)\s+ajudar)[.?!]?\s*/i
  end

  def enforce_brevity(text)
    text = limit_question_count(text)
    text = limit_sentence_count(text)
    limit_character_count(text)
  end

  def remove_low_value_opening_sentence(text)
    sentences = text.scan(/[^.!?\n]+[.!?]?/).map(&:strip).compact_blank
    return text if sentences.size < 2

    first_sentence = sentences.first
    return text if first_sentence.length > 48

    normalized = I18n.transliterate(first_sentence).downcase
    return text unless normalized.match?(/\A(?:ola|oi|claro|perfeito|otimo|certo|entendi|combinado|bom dia|boa tarde|boa noite)\b/)

    text.sub(/\A#{Regexp.escape(first_sentence)}\s*/, '')
  end

  def limit_question_count(text)
    return text if text.count('?') <= MAX_RESPONSE_QUESTIONS

    first_question_end = text.index('?')
    return text if first_question_end.blank?

    text[0..first_question_end]
  end

  def limit_sentence_count(text)
    sentences = text.scan(/[^.!?\n]+[.!?]?/).map(&:strip).compact_blank
    return text if sentences.size <= MAX_RESPONSE_SENTENCES

    sentences.first(MAX_RESPONSE_SENTENCES).join(' ')
  end

  def limit_character_count(text)
    return text if text.length <= MAX_RESPONSE_CHARACTERS

    shortened = text[0...MAX_RESPONSE_CHARACTERS]
    cut_at = shortened.rindex(/[.!?]/) || shortened.rindex(/[;,]/) || shortened.rindex(' ')
    shortened = shortened[0..cut_at] if cut_at && cut_at > 120
    shortened = shortened.to_s.strip
    shortened.match?(/[.!?]\z/) ? shortened : "#{shortened}."
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
      .gsub(/\s*,\s*([.!?])/, '\1')
      .gsub(/\A[,\s.]+/, '')
      .strip
  end

  def capitalize_first_letter(text)
    return text if text.blank?

    text.sub(/\A([[:alpha:]])/) { Regexp.last_match(1).upcase }
  end
end
