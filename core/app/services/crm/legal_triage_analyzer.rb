class Crm::LegalTriageAnalyzer
  AREA_RULES = {
    'previdenciario' => /\b(inss|aposentad\w*|benef[ií]cio\w*|aux[ií]lio\w*|bpc|loas|cnis|per[ií]cia|pens[aã]o)\b/i,
    'trabalhista' => /\b(demiss[aã]o|rescis[aã]o|fgts|verbas|hora extra|ass[eé]dio|emprego|patr[aã]o|direitos trabalhistas)\b/i,
    'familia' => /\b(divorcio|guarda|pensao alimenticia|alimentos|uniao estavel|inventario)\b/i,
    'consumidor' => /\b(banco|cartao|negativad|serasa|spc|compra|produto|servico|cobranca)\b/i,
    'civel' => /\b(contrato|indenizacao|dano moral|cobranca|imovel|aluguel|condominio)\b/i,
    'criminal' => /\b(boletim|delegacia|prisao|flagrante|crime|audiencia de custodia)\b/i,
    'tributario' => /\b(imposto|tributo|receita federal|divida ativa|execucao fiscal)\b/i
  }.freeze

  CASE_RULES = {
    'revisao_de_beneficio' => /\b(revis[aã]o|c[aá]lculo|benef[ií]cio\w*|aposentad\w*|cnis)\b/i,
    'rescisao_trabalhista' => /\b(rescis[aã]o|demiss[aã]o|verbas|fgts)\b/i,
    'cobranca_indevida' => /\b(cobranca indevida|negativad|serasa|spc)\b/i,
    'indenizacao' => /\b(indenizacao|dano moral|dano material)\b/i,
    'guarda_ou_alimentos' => /\b(guarda|pensao alimenticia|alimentos)\b/i,
    'contrato' => /\b(contrato|descumprimento|distrato)\b/i
  }.freeze

  URGENCY_RULES = {
    'critica' => /\b(hoje|amanha|urgente|prazo final|intimacao|citacao|audiencia|prisao|bloqueio)\b/i,
    'alta' => /\b(prazo|processo|pericia|liminar|notificacao|mandado|despejo)\b/i,
    'media' => /\b(preciso|quero|analise|orientacao|consulta|documento|contratar)\b/i
  }.freeze

  DOCUMENT_MENTION_RULE = /\b(documento\w*|contrato\w*|holerite\w*|carta\w*|cnis|extrato\w*|print\w*|comprovante\w*|anexo\w*)\b/i
  DOCUMENT_SEND_RULE = /
    (?<!n[aã]o\s)
    (?<!nunca\s)
    \b
    (?:
      enviei |
      anexei |
      encaminhei |
      mandei |
      estou\s+(?:enviando|anexando|encaminhando|mandando) |
      acabei\s+de\s+(?:enviar|anexar|encaminhar|mandar) |
      segue(?:m)?\s+(?:em\s+)?anexo |
      anexo\s+(?:o|a|meu|minha|este|esta)
    )
    \b
  /ix
  PAYMENT_RULE = /\b(honorario|valor|preco|custo|parcel|pagar|consulta)\b/i
  HIRING_RULE = /\b(contratar|fechar|seguir|representar|advogado|entrar com acao)\b/i
  GREETING_ONLY_RULE = /\A(oi+|ol(?:a|\u00e1)|bom dia|boa tarde|boa noite|e a(?:i|\u00ed)|tudo bem|teste)[!.\s]*\z/i

  def initialize(conversation:)
    @conversation = conversation
  end

  def perform
    text = transcript_text
    return insufficient_data_triage(text) if insufficient_data?(text)

    legal_area = detect_from_rules(text, AREA_RULES, nil)
    case_type = detect_from_rules(text, CASE_RULES, default_case_type(legal_area))
    urgency_level = detect_urgency(text)
    documents_needed = documents_needed_for(legal_area)

    {
      legal_area: legal_area,
      case_type: case_type,
      urgency_level: urgency_level,
      intent: detect_intent(text),
      summary: build_summary(text, legal_area, case_type),
      opposing_party: detect_opposing_party(text, legal_area),
      documents_needed: documents_needed,
      deadline_risk: deadline_risk_for(urgency_level, text),
      economic_potential: economic_potential_for(text, legal_area),
      engagement_level: engagement_level_for(text),
      payment_capacity: payment_capacity_for(text),
      conflict_check_status: 'pending',
      documents_status: document_status_for(text),
      lgpd_basis: 'procedimentos_preliminares',
      consent_status: 'pending',
      data_retention_until: 5.years.from_now.to_date,
      next_best_action: next_best_action_for(legal_area, urgency_level, documents_needed),
      score_reason: score_reason_for(legal_area, urgency_level, text),
      intake_answers: intake_answers_for(text, legal_area, case_type, urgency_level, documents_needed)
    }
  end

  private

  def transcript_text
    @transcript_text ||= incoming_messages
                         .filter_map { |message| message.content.to_s.presence }
                         .join("\n")
                         .squish
  end

  def incoming_messages
    @incoming_messages ||= @conversation.messages
                                        .incoming
                                        .where(private: false)
                                        .includes(:attachments)
                                        .order(created_at: :asc)
                                        .last(20)
  end

  def insufficient_data?(text)
    return false if document_received?(text)
    return true if text.blank?
    return true if text.match?(GREETING_ONLY_RULE)
    return false if legal_signal?(text)

    text.split(/\s+/).size < 4 || text.length < 20
  end

  def legal_signal?(text)
    [AREA_RULES, CASE_RULES, URGENCY_RULES].any? do |rules|
      rules.values.any? { |rule| text.match?(rule) }
    end || text.match?(DOCUMENT_MENTION_RULE) || text.match?(PAYMENT_RULE) || text.match?(HIRING_RULE)
  end

  def insufficient_data_triage(text)
    {
      legal_area: nil,
      case_type: nil,
      urgency_level: nil,
      intent: 'indefinido',
      summary: "Conversa ainda sem informacao suficiente para triagem juridica. Mensagem inicial: #{text.presence || 'sem texto'}",
      opposing_party: 'Nao informado',
      documents_needed: [],
      deadline_risk: 'nao_informado',
      economic_potential: 'nao_informado',
      engagement_level: 'baixo',
      payment_capacity: 'nao_informado',
      conflict_check_status: 'pending',
      documents_status: 'nao_solicitado',
      lgpd_basis: 'procedimentos_preliminares',
      consent_status: 'pending',
      data_retention_until: 5.years.from_now.to_date,
      next_best_action: 'Perguntar qual e o assunto juridico, quem e a outra parte e se existe prazo ou documento recebido.',
      score_reason: 'Score nao calculado: a conversa ainda nao tem dados juridicos suficientes.',
      data_quality: 'insufficient',
      intake_answers: [
        intake_answer('client_message', 'Mensagem inicial recebida.', text.presence || 'sem texto')
      ]
    }
  end

  def detect_from_rules(text, rules, fallback)
    rules.each { |value, rule| return value if text.match?(rule) }
    fallback
  end

  def detect_urgency(text)
    URGENCY_RULES.each { |level, rule| return level if text.match?(rule) }
    'baixa'
  end

  def detect_intent(text)
    return 'contratacao' if text.match?(HIRING_RULE)
    return 'orcamento' if text.match?(PAYMENT_RULE)

    'orientacao'
  end

  def default_case_type(legal_area)
    {
      'previdenciario' => 'analise_previdenciaria',
      'trabalhista' => 'analise_trabalhista',
      'familia' => 'consulta_familia',
      'consumidor' => 'relacao_de_consumo',
      'criminal' => 'analise_criminal',
      'tributario' => 'analise_tributaria'
    }.fetch(legal_area, 'consulta_juridica')
  end

  def build_summary(text, legal_area, case_type)
    base = text.presence || 'Conversa recebida sem conteudo textual suficiente.'
    "Triagem identificou area #{legal_area}, tipo #{case_type}. #{base.truncate(220)}"
  end

  def detect_opposing_party(text, legal_area)
    return 'INSS' if legal_area == 'previdenciario' || text.match?(/\binss\b/i)
    return 'Empregador' if legal_area == 'trabalhista'
    return 'Instituicao financeira/fornecedor' if legal_area == 'consumidor'

    'Nao informado'
  end

  def documents_needed_for(legal_area)
    {
      'previdenciario' => ['carta de concessao', 'CNIS', 'processo administrativo', 'historico de contribuicoes'],
      'trabalhista' => ['CTPS', 'contrato de trabalho', 'holerites', 'TRCT', 'extrato FGTS'],
      'familia' => ['documentos pessoais', 'certidao de casamento/nascimento', 'comprovantes de renda'],
      'consumidor' => ['contrato', 'comprovantes de pagamento', 'prints da cobranca', 'protocolos'],
      'criminal' => ['boletim de ocorrencia', 'intimacao', 'documentos do processo'],
      'tributario' => ['notificacao fiscal', 'CDA', 'comprovantes de pagamento']
    }.fetch(legal_area, ['documentos pessoais', 'contratos', 'comprovantes e protocolos'])
  end

  def deadline_risk_for(urgency_level, text)
    return 'alto' if %w[alta critica].include?(urgency_level)
    return 'medio' if text.match?(/\b(prazo|processo|audiencia|intimacao)\b/i)

    'baixo'
  end

  def economic_potential_for(text, legal_area)
    return 'alto' if text.match?(/\b(imovel|empresa|indenizacao|beneficio atrasado|rescisao)\b/i)
    return 'medio' if %w[previdenciario trabalhista consumidor civel].include?(legal_area)

    'nao_informado'
  end

  def engagement_level_for(text)
    return 'alto' if text.match?(HIRING_RULE) || document_received?(text)
    return 'medio' if text.length > 120

    'baixo'
  end

  def payment_capacity_for(text)
    return 'informado' if text.match?(PAYMENT_RULE)

    'nao_informado'
  end

  def document_status_for(text)
    return 'parcial' if document_received?(text)

    'solicitado'
  end

  def document_received?(text)
    incoming_messages.any? { |message| message.attachments.any? } || text.match?(DOCUMENT_SEND_RULE)
  end

  def next_best_action_for(legal_area, urgency_level, documents_needed)
    action = "Solicitar #{documents_needed.first(3).join(', ')}"
    return "#{action} e acionar atendimento humano imediato." if %w[alta critica].include?(urgency_level)

    "#{action} e agendar consulta de analise #{legal_area}."
  end

  def score_reason_for(legal_area, urgency_level, text)
    signals = []
    signals << "area #{legal_area}"
    signals << "urgencia #{urgency_level}"
    signals << 'intencao de contratacao' if text.match?(HIRING_RULE)
    signals << 'documentos recebidos' if document_received?(text)
    "Lead classificado por #{signals.join(', ')}."
  end

  def intake_answers_for(text, legal_area, case_type, urgency_level, documents_needed)
    [
      intake_answer('legal_area', 'Qual area juridica foi identificada?', legal_area),
      intake_answer('case_type', 'Qual tipo de caso foi identificado?', case_type),
      intake_answer('urgency_level', 'Qual nivel de urgencia foi percebido?', urgency_level),
      intake_answer('documents_needed', 'Quais documentos devem ser solicitados?', documents_needed.join(', '),
                    documents: documents_needed),
      intake_answer('client_message', 'Resumo da manifestacao inicial do cliente.', text.truncate(500))
    ]
  end

  def intake_answer(question_key, question_text, answer_text, answer_json = {})
    {
      question_key: question_key,
      question_text: question_text,
      answer_text: answer_text,
      answer_json: answer_json
    }
  end
end
