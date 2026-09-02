class Captain::Conversation::ResponsePolicyService
  FALLBACK_RESPONSE = 'Tive uma dificuldade para concluir a resposta. Pode repetir em uma frase o que você precisa saber agora?'.freeze
  REPEATED_INTRO_FALLBACK = 'Vou seguir pelo contexto da conversa. Qual ponto você quer priorizar agora?'.freeze
  NEAR_DUPLICATE_FALLBACK = 'Quero responder exatamente ao que você perguntou. Pode esclarecer esse ponto em uma frase?'.freeze
  DATA_COLLECTION_RESPONSE = 'Pode enviar os dados e documentos solicitados por aqui para continuarmos o atendimento.'.freeze
  MAX_RESPONSE_SENTENCES = 2
  MAX_RESPONSE_QUESTIONS = 1
  MAX_RESPONSE_CHARACTERS = 240
  INITIAL_RESPONSE_MAX_SENTENCES = 5
  INITIAL_RESPONSE_MAX_CHARACTERS = 500
  NEW_LEAD_RESPONSE_MAX_SENTENCES = 3
  NEW_LEAD_RESPONSE_MAX_CHARACTERS = 420
  PREVIDENCIARIO_INITIAL_RESPONSE_FLAG = 'feature_previdenciario_initial_responses'.freeze
  DRA_PAULA_DATA_COLLECTION_FLAG = 'feature_dra_paula_data_collection_policy'.freeze
  LEGAL_INTAKE_PROFILE_KEY = 'dra_leticia_intake'.freeze
  LEGACY_LEGAL_INTAKE_ASSISTANT_NAMES = ['Dra. Letícia', 'Dra. Paula Matos'].freeze
  DRA_LETICIA_IDENTITY =
    'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos.'.freeze
  NEW_LEAD_REVIEW_NOTICE =
    'Depois deste atendimento inicial, a equipe analisará seu caso com atenção e entrará em contato em breve por aqui.'.freeze
  LAWYER_AVAILABILITY_RESPONSE =
    'Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. ' \
    'Já posso entender seu caso por aqui; conte brevemente o que aconteceu.'.freeze
  CNIS_ACQUISITION_RESPONSE =
    'Você consegue o CNIS pelo aplicativo ou site Meu INSS, entrando com sua conta gov.br e abrindo ' \
    '"Extrato de Contribuição (CNIS)". Não preciso do seu CPF para explicar esse passo.'.freeze
  GUIDANCE_ACKNOWLEDGEMENT_RESPONSE =
    'Fico feliz em ajudar. Quando precisar, sigo à disposição no atendimento inicial da Dra. Paula.'.freeze
  OTHER_LAWYER_REQUEST_PATTERN = /
    \b(?:uma|outra|minha|meu|a|o)\s+advogad[ao]\b.{0,100}\b(?:pediu|solicitou|orientou|mandou)\b |
    \b(?:pediu|solicitou|orientou|mandou)\b.{0,100}\b(?:por|pela|pelo|da|do)\s+(?:uma\s+)?advogad[ao]\b
  /ix
  LAWYER_AVAILABILITY_PATTERN = /
    \b(?:quero|preciso|prefiro|gostaria)\b.{0,50}\b(?:falar|conversar|atendimento)\b.{0,30}\b(?:advogad[ao]|doutor[ao])\b |
    \b(?:falar|conversar)\b.{0,30}\b(?:com\s+)?(?:uma|um)\s+(?:advogad[ao]|doutor[ao])\b
  /ix
  CNIS_ACQUISITION_PATTERN = /
    \b(?:como|onde)\b.{0,60}\b(?:cons[ei]g\w*|obte\w*|peg\w*|tir\w*|baix\w*|emit\w*|consult\w*)\b.{0,60}\bcnis\b |
    \bcnis\b.{0,60}\b(?:como|onde)\b.{0,60}\b(?:cons[ei]g\w*|obte\w*|peg\w*|tir\w*|baix\w*|emit\w*|consult\w*)\b
  /ix
  CONTEXTUAL_ACQUISITION_FOLLOWUP_PATTERN = /
    \b(?:preciso|quero|gostaria)\b.{0,40}\b(?:saber|entender)\b.{0,30}\bcomo\b.{0,40}
    \b(?:cons[ei]g\w*|obte\w*|peg\w*|tir\w*|baix\w*|emit\w*|consult\w*)\b
  /ix
  THANKS_PATTERN = /\b(?:obrigad[ao]|valeu|agrade[cç]o)\b.{0,60}\b(?:ajudou|ajuda|orienta[cç][aã]o)?\b/i
  CASE_INTAKE_PATTERN = /
    \b(?:ajuda\s+juridica|caso|processo|prazo|decisao|negad\w*|indefer\w*|revis\w*|inss|previdenc\w*|
    aposent\w*|beneficio|auxilio|bpc|loas|pensao|cnis\s+(?:errad\w*|incomplet\w*)|contribui\w*|mei|gps|das|
    demiss\w*|rescis\w*|divorci\w*|guarda|inventario|contrato|cobran[cç]a|indeniza[cç][aã]o|prisao|delegacia)\b
  /ix
  HANGUL_PATTERN = /[\u1100-\u11FF\u3130-\u318F\uA960-\uA97F\uAC00-\uD7AF\uD7B0-\uD7FF]/
  META_OUTPUT_PATTERN = /
    correct\s+format\s+needed |
    response[_\s-]*format |
    (?:json|response|output)\s+schema |
    schema\s+(?:validation\s+)?(?:error|failed|failure|invalid) |
    (?:invalid|incorrect|malformed|expected)\s+(?:json|schema|format|response|output) |
    (?:erro|falha)\s+(?:de|do|no|na|em)\s+(?:json|schema|esquema|formato) |
    (?:schema|esquema|formato)\s+(?:invalido|incorreto)
  /ix
  RAW_STRUCTURED_OUTPUT_PATTERN = /
    ``` |
    \A\s*[\{\[] |
    \{\s*["']?[a-z_][\w-]*["']?\s*: |
    ["'](?:response|reasoning|error)["']\s*:
  /ix
  DUPLICATE_STOP_WORDS = %w[
    aqui ainda caso com como das dos ela ele essa esse esta este para pela pelo
    por que seu sua uma voce
  ].to_set.freeze
  RESPONSE_ENTITY_TOKENS = %w[
    cnis ctps cpf idade laudo laudos carta decisao indeferimento recurso prazo
    ppp ltcat gps documento documentos
  ].to_set.freeze
  CREDENTIAL_REFERENCE_PATTERN = /
    \b(?:senha(?:\s+(?:do\s+)?meu\s+inss|\s+bancaria)?|pin|token|
    codigo\s+(?:de\s+)?(?:acesso|autenticacao|verificacao))\b
  /ix
  RECEIPT_CLAIM_PATTERN = /
    \b(?:recebi|recebemos|recebido|recebida|recebidos|recebidas|
    anotei|anotamos|registrei|registramos|confirmo|confirmamos|chegou|chegaram)\b |
    \bobrigad[ao]\s+(?:pelo|pela|pelos|pelas)\b |
    \b(?:foi|foram|esta|estao)\s+
    (?:recebido|recebida|recebidos|recebidas|registrado|registrada|registrados|registradas)\b
  /ix
  DOCUMENT_SUBMISSION_PATTERN = /
    \b(?:j[aá]\s+)?(?:enviei|encaminhei|anexei|mandei|remeti|estou\s+enviando|estou\s+encaminhando)\b |
    \b(?:segue|seguem)\b.{0,30}\b(?:anexo|anexos|arquivo|arquivos|documento|documentos|cnis|ctps|rg|ppp|laudo)\b |
    \b(?:em\s+anexo|anexo\s+(?:o|a|os|as|meu|minha|meus|minhas))\b
  /ix
  RECEIPT_ENTITY_PATTERNS = {
    cpf: /\bcpf\b/,
    rg: /\brg\b|\bcarteira de identidade\b/,
    cnis: /\bcnis\b|\bextrato previdenciario\b/,
    ctps: /\bctps\b|\bcarteira (?:de )?trabalho\b/,
    ppp: /\bppp\b|\bperfil profissiografico previdenciario\b/,
    ltcat: /\bltcat\b/,
    laudo: /\blaudos?\b|\brelatorio medico\b/,
    carta: /\bcarta (?:de|do) (?:concessao|indeferimento|beneficio|inss)\b/,
    decisao: /\bdecisao (?:do|de) inss\b/,
    protocolo: /\bprotocolos?\b/,
    comprovante: /\bcomprovante (?:de )?(?:endereco|residencia|pagamento)\b/,
    gps: /\bguia gps\b|\bguia da previdencia social\b/,
    das_mei: /\bdas[- ]?mei\b|\bguia (?:do )?mei\b|\bdocumento de arrecadacao do simples nacional\b/,
    carne: /\bcarnes? (?:do )?inss\b/,
    document: /\b(?:documentos?|arquivos?|anexos?)\b/
  }.freeze

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
    # Remove a frase inteira de solidariedade, não só as duas palavras: apagar
    # apenas "Sinto muito" deixava fragmentos como "Pelo ocorrido." indo para o
    # cliente. Ancorado em início de frase para nunca partir uma frase no meio.
    # O lookahead final garante que sobre texto depois: uma resposta curta que
    # fosse só a frase de solidariedade era zerada e virava fallback genérico.
    [/(?:\A|(?<=[.!?])\s+)sinto muito(?: mesmo)?[^.?!\n]*[.?!]+\s*(?=\S)/i, ''],
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

  def self.review_notice?(text)
    normalized = I18n.transliterate(text.to_s).downcase
    normalized.match?(/\bequipe\b.{0,100}\banalis\w*\b.{0,100}\bcaso\b/) &&
      normalized.match?(/\b(?:contato|retorno|entrar\w*)\b.{0,80}\bbreve\b/)
  end

  def apply(content)
    @priority_response_applied = contextual_priority_response
    text = @priority_response_applied.presence || content.to_s.dup
    return FALLBACK_RESPONSE if @priority_response_applied.blank? && unsafe_machine_output?(text)

    text = apply_content_guardrails(text)
    text = cleanup_repeated_document_terms(text)
    text = remove_public_formatting(text)
    text = suppress_repeated_intro(text)
    text = limit_questions_for_stepwise_triage(text)
    text = collapse_repeated_name_mentions(text)
    text = fix_interrogative_case_after_comma(text)
    text = normalize_spacing(text)
    text = remove_low_value_opening_sentence(text)
    text = suppress_near_duplicate_response(text)
    text = enforce_new_lead_review_notice(text)
    text = enforce_brevity(text)
    text = capitalize_first_letter(text)
    text.presence || FALLBACK_RESPONSE
  end

  private

  def apply_content_guardrails(text)
    text = enforce_public_identity(text)
    text = ensure_identity_on_first_priority_response(text)
    text = rewrite_unsafe_data_instructions(text) if dra_paula_data_collection_policy_enabled?
    text = enforce_supported_receipt_claims(text)
    # Reatribuição em vez de gsub!: remove_unsupported_receipt_claims pode
    # devolver a constante congelada FALLBACK_RESPONSE, e a versão destrutiva
    # levantava FrozenError, abortando o job — o cliente ficava sem resposta.
    BANNED_REPLACEMENTS.each { |pattern, replacement| text = text.gsub(pattern, replacement) }
    text
  end

  def enforce_public_identity(text)
    return text unless legal_intake_profile?

    enforce_dra_leticia_identity(text)
  end

  def ensure_identity_on_first_priority_response(text)
    return text unless first_turn_priority_response?
    return text if I18n.transliterate(text).match?(/\bdra\.?\s+leticia\b/i)

    "#{DRA_LETICIA_IDENTITY} #{text}"
  end

  def enforce_dra_leticia_identity(text)
    text
      .gsub(
        /\b(?:sou|aqui [ée])\s+o\s+Capit[aã]o,?\s*(?:assistente virtual )?(?:de atendimento )?(?:da )?Dra\.?\s*Paula Matos\.?/i,
        DRA_LETICIA_IDENTITY
      )
      .gsub(
        /\bCapit[aã]o,?\s+assistente virtual da Dra\.?\s*Paula Matos\b/i,
        'Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos'
      )
      .gsub(
        /\b(?:sou|aqui [ée])\s+a\s+Dra\.?\s*Paula Matos,?\s*(?:do\s+Coimbra\s*&\s*Ruas)?\.?/i,
        DRA_LETICIA_IDENTITY
      )
      .gsub(
        /\b(?:sou|aqui [ée])\s+a\s+assistente de atendimento da equipe da Dra\.?\s*Paula Matos\.?/i,
        DRA_LETICIA_IDENTITY
      )
  end

  def contextual_priority_response
    return unless legal_intake_profile?

    latest = normalized_current_customer_burst
    return if latest.blank?

    return other_lawyer_priority_response(latest) if latest.match?(OTHER_LAWYER_REQUEST_PATTERN)
    return LAWYER_AVAILABILITY_RESPONSE if latest.match?(LAWYER_AVAILABILITY_PATTERN)
    return CNIS_ACQUISITION_RESPONSE if cnis_acquisition_question?(latest)
    return GUIDANCE_ACKNOWLEDGEMENT_RESPONSE if thanks_after_cnis_guidance?(latest)

    nil
  end

  def other_lawyer_priority_response(latest)
    Captain::Assistant::InitialMessageResponseService.new(message: latest).other_lawyer_response
  end

  def cnis_acquisition_question?(latest)
    return true if latest.match?(CNIS_ACQUISITION_PATTERN)
    return false unless latest.match?(CONTEXTUAL_ACQUISITION_FOLLOWUP_PATTERN)

    recent_public_context.match?(/\bcnis\b/i)
  end

  def thanks_after_cnis_guidance?(latest)
    latest.match?(THANKS_PATTERN) && recent_assistant_context.match?(/\b(?:meu\s+inss|cnis)\b/i)
  end

  def normalized_current_customer_burst
    I18n.transliterate(initial_customer_burst_text).downcase
  end

  def recent_public_context
    @recent_public_context ||= conversation.messages
                                           .where(private: false)
                                           .reorder(id: :desc)
                                           .limit(8)
                                           .pluck(:content)
                                           .compact
                                           .reverse
                                           .join(' ')
  end

  def recent_assistant_context
    @recent_assistant_context ||= conversation.messages
                                              .where(message_type: :outgoing, private: false)
                                              .reorder(id: :desc)
                                              .limit(4)
                                              .pluck(:content)
                                              .compact
                                              .join(' ')
  end

  def unsafe_machine_output?(text)
    return true if text.match?(HANGUL_PATTERN)
    return true if I18n.transliterate(text).match?(META_OUTPUT_PATTERN)

    text.match?(RAW_STRUCTURED_OUTPUT_PATTERN)
  end

  def rewrite_unsafe_data_instructions(text)
    sentences = split_sentences(text)
    unsafe_sentences, safe_sentences = sentences.partition do |sentence|
      unsafe_data_instruction?(sentence) || credential_reference?(sentence)
    end
    return text if unsafe_sentences.blank?

    safe_text = safe_sentences.join(' ')
    return safe_text if safe_data_collection_acknowledgement?(safe_text)

    [DATA_COLLECTION_RESPONSE, safe_text].compact_blank.join(' ')
  end

  def unsafe_data_instruction?(sentence)
    normalized = I18n.transliterate(sentence).downcase
    data_target = normalized.match?(/\b(?:cpf|document\w*|dad\w*|senha\w*|meu inss|informac\w*\s+sensive\w*)\b/)
    deletion_target = normalized.match?(/\b(?:isso|o que|enviou|mensage\w*|arquiv\w*|cpf|document\w*|dad\w*|senha\w*)\b/)
    deletion_instruction = normalized.match?(/\b(?:apag|exclu|delet|remov|retir)\w*/)
    refusal_instruction = normalized.match?(
      /\b(?:nao|nunca|jamais|evite)\b.{0,140}\b(?:envi|mand|pass|compartilh|inform|fornec|anex|encaminh|coloc|digit|receb|registr|colet|aceit)\w*/
    )
    insecure_channel_instruction = normalized.match?(/\b(?:canal inseguro|por seguranca)\b/)
    delayed_collection_instruction = normalized.match?(
      /\b(?:aguard|esper|somente)\w*.{0,100}\bcanal seguro\b/
    )

    (deletion_target && deletion_instruction) ||
      (data_target && (refusal_instruction || insecure_channel_instruction || delayed_collection_instruction))
  end

  def credential_reference?(sentence)
    I18n.transliterate(sentence).downcase.match?(CREDENTIAL_REFERENCE_PATTERN)
  end

  def safe_data_collection_acknowledgement?(text)
    normalized = I18n.transliterate(text).downcase
    normalized.match?(/\b(?:receb|envi|encaminh)\w*.{0,100}\b(?:cpf|document\w*|dad\w*)\b/)
  end

  def remove_unsupported_receipt_claims(text)
    evidence = latest_incoming_evidence
    safe_sentences = split_sentences(text).reject do |sentence|
      normalized = normalize_for_evidence(sentence)
      next false unless affirmative_receipt_claim?(normalized)

      claimed_entities = RECEIPT_ENTITY_PATTERNS.filter_map do |name, pattern|
        name if normalized.match?(pattern)
      end
      claimed_entities.any? do |name|
        !evidence.match?(RECEIPT_ENTITY_PATTERNS.fetch(name))
      end
    end

    safe_sentences.join(' ').presence || FALLBACK_RESPONSE
  end

  def affirmative_receipt_claim?(normalized)
    return false unless normalized.match?(RECEIPT_CLAIM_PATTERN)
    return false if normalized.match?(/\bnao\b.{0,24}\b(?:receb|registr|anot|confirm)/)

    true
  end

  def latest_incoming_evidence
    messages = current_public_incoming_burst
    return '' if messages.blank?

    evidence = messages.flat_map do |message|
      submitted_text = submitted_message_text(message)
      [submitted_text, attachment_evidence(message)]
    end
    normalize_for_evidence(evidence.flatten.compact.join(' '))
  end

  def submitted_message_text(message)
    text = [message.content, message.processed_message_content].compact_blank.join(' ')
    return text if message.attachments.any?

    text if text.match?(DOCUMENT_SUBMISSION_PATTERN)
  end

  def enforce_supported_receipt_claims(text)
    return text unless dra_paula_data_collection_policy_enabled?

    remove_unsupported_receipt_claims(text)
  end

  def current_public_incoming_burst
    incoming = conversation.messages.where(message_type: :incoming, private: false)
    last_public_outgoing_id = conversation.messages
                                          .where(message_type: :outgoing, private: false)
                                          .maximum(:id)
    incoming = incoming.where('id > ?', last_public_outgoing_id) if last_public_outgoing_id
    incoming.reorder(id: :asc)
  end

  def attachment_evidence(message)
    attachment_terms = message.attachments.flat_map do |attachment|
      [
        attachment.fallback_title,
        (attachment.file.filename.to_s if attachment.file.attached?),
        attachment.meta&.slice('ocr_text', 'document_guess', 'transcribed_text')&.values
      ]
    end
    attachment_terms << 'documento anexo' if message.attachments.any?
    attachment_terms
  end

  def normalize_for_evidence(value)
    I18n.transliterate(value.to_s).downcase
  end

  def suppress_near_duplicate_response(text)
    # A pergunta atual muda o ato conversacional mesmo quando a resposta usa
    # termos já vistos. Substituí-la por um pedido genérico de documento foi a
    # causa do atendimento incorreto reproduzido no WhatsApp.
    return text if current_customer_asks_question?

    recent_public_ai_responses = conversation.messages
                                             .where(sender_type: 'Captain::Assistant', private: false)
                                             .reorder(id: :desc)
                                             .limit(6)
                                             .pluck(:content)
    return text unless recent_public_ai_responses.any? { |previous| near_duplicate?(previous, text) }

    NEAR_DUPLICATE_FALLBACK
  end

  def current_customer_asks_question?
    initial_customer_burst_text.include?('?') ||
      normalized_current_customer_burst.match?(/\A(?:como|onde|quando|qual|quais|por que|porque|posso|devo|preciso)\b/)
  end

  def near_duplicate?(first, second)
    first_tokens = significant_tokens(first)
    second_tokens = significant_tokens(second)
    minimum_size = [first_tokens.size, second_tokens.size].min
    return false if minimum_size < 4
    return false if conflicting_response_entities?(first_tokens, second_tokens)

    duplicate_similarity?(first_tokens, second_tokens, minimum_size)
  end

  def conflicting_response_entities?(first_tokens, second_tokens)
    first_entities = first_tokens & RESPONSE_ENTITY_TOKENS
    second_entities = second_tokens & RESPONSE_ENTITY_TOKENS
    first_entities.any? && second_entities.any? && !first_entities.intersect?(second_entities)
  end

  def duplicate_similarity?(first_tokens, second_tokens, minimum_size)
    intersection = (first_tokens & second_tokens).size
    containment = intersection.fdiv(minimum_size)
    jaccard = intersection.fdiv((first_tokens | second_tokens).size)
    (intersection >= 6 && containment >= 0.6) || containment >= 0.76 || jaccard >= 0.58
  end

  def significant_tokens(text)
    I18n.transliterate(text.to_s)
        .downcase
        .scan(/[a-z0-9]+/)
        .select { |token| token.length >= 4 && DUPLICATE_STOP_WORDS.exclude?(token) }
        .to_set
  end

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
    /\A(?:(?:ol[aá]|oi)[!.]?\s+)?(?:aqui\s+[ée]|sou)\s+.{0,220}?(?:
      como\s+posso\s+(?:(?:te|lhe|você)\s+)?ajudar(?:\s+você)?(?:\s+hoje)? |
      em\s+que\s+posso\s+(?:(?:te|lhe|você)\s+)?ajudar(?:\s+você)?
    )[.?!]?\s*/ix
  end

  def enforce_brevity(text)
    text = limit_question_count(text)
    text = limit_sentence_count(text)
    limit_character_count(text)
  end

  def remove_low_value_opening_sentence(text)
    return text if initial_explanatory_response?

    sentences = split_sentences(text)
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
    original_sentences = split_sentences(text)
    sentences = remove_leading_greeting_if_needed(original_sentences)
    within_limit = sentence_response_within_limit(text, original_sentences, sentences)
    return within_limit if within_limit.present?

    response_with_notice = sentences_preserving_review_notice(sentences)
    return response_with_notice if response_with_notice.present?

    question = sentences.reverse.find { |sentence| sentence.include?('?') }
    return sentences.first(max_response_sentences).join(' ') if question.blank?

    acknowledgement = sentences.find { |sentence| sentence != question && sentence.exclude?('?') }
    [acknowledgement, question].compact.join(' ')
  end

  def sentence_response_within_limit(text, original_sentences, sentences)
    return if sentences.size > max_response_sentences

    sentences == original_sentences ? text : sentences.join(' ')
  end

  def sentences_preserving_review_notice(sentences)
    notice = sentences.find { |sentence| review_notice_present_in?(sentence) }
    return if notice.blank?

    question = sentences.reverse.find { |sentence| sentence.include?('?') }
    statement = sentences.find do |sentence|
      sentence != notice && sentence != question && sentence.exclude?('?')
    end
    [statement, notice, question].compact.join(' ')
  end

  def remove_leading_greeting_if_needed(sentences)
    return sentences if sentences.size <= max_response_sentences
    return sentences unless sentences.first.match?(/\A(?:ol[áa]|oi|bom dia|boa tarde|boa noite)[!.]?\z/i)

    sentences.drop(1)
  end

  def split_sentences(text)
    protected_text = text.to_s.gsub(/\b(Dra|Dr|Sra|Sr|Prof|Profa)\./i, '\1__ABBR_DOT__')
    protected_text = protected_text.gsub(/(?<=\w)\.(?=\w)/, '__INNER_DOT__')
    protected_text
      .scan(/[^.!?\n]+[.!?]?/)
      .map { |sentence| sentence.gsub('__ABBR_DOT__', '.').gsub('__INNER_DOT__', '.').strip }
      .compact_blank
  end

  def limit_character_count(text)
    return text if text.length <= max_response_characters

    sentences = split_sentences(text)
    response_with_notice = truncate_while_preserving_notice(sentences)
    return response_with_notice if response_with_notice.present?

    question = sentences.reverse.find { |sentence| sentence.include?('?') }
    response_with_question = truncate_while_preserving_question(sentences, question)
    return response_with_question if response_with_question.present?

    truncate_at_natural_boundary(text)
  end

  def truncate_while_preserving_notice(sentences)
    notice = sentences.find { |sentence| review_notice_present_in?(sentence) }
    return if notice.blank?

    question = sentences.reverse.find { |sentence| sentence.include?('?') }
    preserved_question = question_preserved_with_notice(question, notice)
    reserved = [notice, preserved_question].compact
    room_for_statement = max_response_characters - reserved.sum(&:length) - reserved.size
    statement = fitting_notice_statement(sentences, notice, question, room_for_statement)
    [statement, notice, preserved_question].compact.join(' ')
  end

  def question_preserved_with_notice(question, notice)
    return if question.blank?

    question_room = max_response_characters - notice.length - 1
    return unless question_room.positive?

    truncate_component(question, question_room, ending: '?')
  end

  def fitting_notice_statement(sentences, notice, question, room)
    sentences.find do |sentence|
      sentence != notice && sentence != question && sentence.exclude?('?') && sentence.length <= room
    end
  end

  def truncate_component(text, limit, ending: '.')
    return if text.blank? || limit < 2
    return text if text.length <= limit

    shortened = text[0...(limit - 1)].to_s.strip
    boundary = shortened.rindex(/[;,]/) || shortened.rindex(' ')
    shortened = shortened[0...boundary].to_s.strip if boundary && boundary > 20
    "#{shortened.sub(/[.!?]+\z/, '')}#{ending}"
  end

  def truncate_while_preserving_question(sentences, question)
    return if question.blank? || question.length >= max_response_characters

    room_for_statement = max_response_characters - question.length - 1
    statement = sentences.find do |sentence|
      sentence.exclude?('?') && sentence.length <= room_for_statement
    end
    [statement, question].compact.join(' ')
  end

  def truncate_at_natural_boundary(text)
    shortened = text[0...max_response_characters]
    cut_at = shortened.rindex(/[.!?]/) || shortened.rindex(/[;,]/) || shortened.rindex(' ')
    shortened = shortened[0..cut_at] if cut_at && cut_at > 120
    shortened = shortened.to_s.strip
    shortened.match?(/[.!?]\z/) ? shortened : "#{shortened}."
  end

  def max_response_sentences
    return INITIAL_RESPONSE_MAX_SENTENCES if initial_explanatory_response? || first_turn_priority_response?
    return NEW_LEAD_RESPONSE_MAX_SENTENCES if new_lead_intake_response?

    MAX_RESPONSE_SENTENCES
  end

  def max_response_characters
    return INITIAL_RESPONSE_MAX_CHARACTERS if initial_explanatory_response? || first_turn_priority_response?
    return NEW_LEAD_RESPONSE_MAX_CHARACTERS if new_lead_intake_response?

    MAX_RESPONSE_CHARACTERS
  end

  def enforce_new_lead_review_notice(text)
    @current_response_candidate = text
    return text unless new_lead_review_notice_required?

    insert_before_final_question(text, NEW_LEAD_REVIEW_NOTICE)
  end

  def insert_before_final_question(text, notice)
    question = text[/[^.!?]*\?\s*\z/]
    return "#{text} #{notice}" if question.blank?

    statement = text.delete_suffix(question).strip
    [statement, notice, question.strip].compact_blank.join(' ')
  end

  def new_lead_review_notice_required?
    return false unless new_lead_intake_response?
    return false if review_notice_present_in?(current_response_candidate)

    true
  end

  def new_lead_intake_response?
    return @new_lead_intake_response if defined?(@new_lead_intake_response)

    @new_lead_intake_response = legal_intake_profile? && new_lead_contact? &&
                                substantive_case_intake? && !analysis_notice_sent?
  end

  def substantive_case_intake?
    latest = normalized_current_customer_burst
    return false if latest.blank? || latest.match?(OTHER_LAWYER_REQUEST_PATTERN)
    return false if cnis_acquisition_question?(latest) || latest.match?(THANKS_PATTERN)
    return true if current_public_incoming_burst.any? { |message| message.attachments.any? }

    latest.match?(CASE_INTAKE_PATTERN)
  end

  def new_lead_contact?
    return false if conversation.contact.blank?

    Crm::ContactRelationshipClassifier.new(conversation.contact).perform[:status] == 'lead'
  end

  def analysis_notice_sent?
    state = conversation.captain_conversation_state
    return true if state&.analysis_notice_sent_at.present?

    conversation.messages
                .where(sender_type: 'Captain::Assistant', private: false)
                .where('content ILIKE ?', '%equipe%analis%caso%contato%breve%')
                .exists?
  end

  def review_notice_present_in?(text)
    self.class.review_notice?(text)
  end

  def current_response_candidate
    @current_response_candidate.to_s
  end

  def initial_explanatory_response?
    return @initial_explanatory_response if defined?(@initial_explanatory_response)
    return @initial_explanatory_response = false unless previdenciario_initial_responses_enabled?

    initial_customer_turn = !previous_ai_response?
    initial_intent = Captain::Assistant::InitialMessageResponseService.new(
      message: initial_customer_burst_text
    ).previdenciario_intent?
    @initial_explanatory_response = initial_customer_turn && initial_intent
  end

  def first_turn_priority_response?
    @priority_response_applied && !previous_ai_response?
  end

  def initial_customer_burst_text
    current_public_incoming_burst.pluck(:content).compact_blank.join("\n")
  end

  def previdenciario_initial_responses_enabled?
    return false unless legal_intake_profile?

    ActiveModel::Type::Boolean.new.cast(
      assistant&.config&.[](PREVIDENCIARIO_INITIAL_RESPONSE_FLAG)
    )
  end

  def dra_paula_data_collection_policy_enabled?
    return false unless legal_intake_profile?

    ActiveModel::Type::Boolean.new.cast(
      assistant&.config&.[](DRA_PAULA_DATA_COLLECTION_FLAG)
    )
  end

  def legal_intake_profile?
    assistant&.config&.[]('profile_key') == LEGAL_INTAKE_PROFILE_KEY ||
      assistant&.name.in?(LEGACY_LEGAL_INTAKE_ASSISTANT_NAMES)
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
