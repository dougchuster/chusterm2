# frozen_string_literal: true

# The catalogue intentionally lives beside its deterministic intent matcher so
# legal intake copy and routing rules remain auditable in one place.
# rubocop:disable Metrics/ClassLength
class Captain::Assistant::InitialMessageResponseService
  SITE_PLANNING_PATTERN = /\bvim\s+pelo\s+site\s+de\s+planejamento\s+previdenciario\b/
  DATE_DETAIL_PATTERN = %r{\b(?:
    \d{1,2}[\/.-]\d{1,2}(?:[\/.-]\d{2,4})? |
    \d{1,2}\s+de\s+(?:janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro) |
    (?:janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\s+de\s+\d{4}
  )\b}ix
  MATERIAL_CASE_DETAILS_PATTERN = /
    \b(?:anexei|enviei|encaminhei|mandei|segue|estou\s+enviando|tenho|possuo)\b.{0,80}
      \b(?:cnis|carta|laudo|relatorio|ppp|ltcat|document\w*|arquiv\w*|anex\w*|extrato)\b |
    \b(?:tenho|idade(?:\s+e|:)?)[\s:]*(?:\d{1,3})\s*anos?\b
      (?!\s+(?:de\s+)?(?:contribu\w*|trabalh\w*|servic\w*|atividade|inss)) |
    \b(?:nasci\s+em|trabalhei\s+(?:como|por|de)|contribuo\s+como|recebi\s+a\s+decisao)\b |
    \b(?:cliente\s+enviou\s+um\s+anexo|user\s+has\s+shared\s+an\s+attachment)\b
  /ix

  INTENT_DETAIL_PATTERNS = {
    planning: /\b\d{1,3}\s*anos?\s+(?:de\s+)?(?:contribu\w*|trabalh\w*|servic\w*|atividade|inss)\b/,
    denial: /\b(?:carta|decisao|recebi|ciencia|motivo\s+(?:foi|e|:))\b/,
    revision: /\b(?:carta\s+de\s+concessao|valor\s+(?:de|do|e|:)|recebo|salario|cnis)\b/,
    bpc: /\b(?:moram?|pessoas?|familia|renda|cadunico|deficiencia|impedimento)\b/,
    pension: /\b(?:marido|esposa|companheir\w*|pai|mae|filh\w*|conjuge|relacao)\b/,
    incapacity: /\b(?:trabalh\w*|afastad\w*|laudo|relatorio|doenca|diagnostico|cid)\b/,
    maternity: /\b(?:gestante|gravid\w*|previsao|parto|adocao|contribuo|clt|mei|autonom\w*|facultativ\w*)\b/,
    special_activity: /\b(?:ppp|ltcat|empresa|trabalh\w*|expost\w*|insalubr\w*|periculos\w*|agente\s+nocivo)\b/,
    rural: /\b(?:fazenda|sitio|familia|document\w*|agricult\w*|lavrador\w*|pescador\w*|segurado\s+especial)\b/,
    contributions: /\b(?:sou|contribuo|paguei|codigo|aliquota|gps|das[- ]?mei|carne|mei|autonom\w*|facultativ\w*|clt|cnis)\b/,
    cnis: /\b(?:vinculo|remunerac\w*|indicador\w*|erro|ausente|corrigir|aposent\w*)\b/
  }.freeze
  NO_MATCH_PATTERN = /\b\B/
  DOCUMENT_SEND_VERB_SOURCE = '(?:anexei|enviei|encaminhei|mandei|segue|estou\s+enviando)'
  DOCUMENT_SENT_STATUS_SOURCE = '(?:anexad[oa]s?|enviad[oa]s?|encaminhad[oa]s?)'
  AGE_VALUE_PATTERN = /\b(?:(?:tenho|idade(?:\s+e|:)?)[\s:]*)?(\d{1,3})\s*anos?\b/
  NON_AGE_CONTEXT_BEFORE_PATTERN = /\b(?:contribu\w*|trabalh\w*|servic\w*|atividade).{0,18}(?:por|ha)?\s*\z/
  NON_AGE_CONTEXT_AFTER_PATTERN = /\A\s+(?:
    (?:de\s+)?(?:contribu\w*|trabalh\w*|servic\w*|atividade|exposicao|inss) |
    como\b | (?:no|na)\s+(?:campo|empresa|atividade|profissao|servico)
  )/x
  GREETING_EXPRESSION_SOURCE = '(?:oi+|ola|bom\s+dia|boa\s+tarde|boa\s+noite|tudo\s+bem)'
  GREETING_ONLY_PATTERN = /
    \A\s*#{GREETING_EXPRESSION_SOURCE}
    (?:\s*(?:[,;:!?.-]+\s*|\s+)#{GREETING_EXPRESSION_SOURCE})*
    [!?.\s]*\z
  /x
  OTHER_LAWYER_REQUEST_PATTERN = /
    \b(?:uma|outra|minha|meu|a|o)\s+advogad[ao]\b.{0,100}\b(?:pediu|solicitou|orientou|mandou)\b |
    \b(?:pediu|solicitou|orientou|mandou)\b.{0,100}\b(?:por|pela|pelo|da|do)\s+(?:uma\s+)?advogad[ao]\b
  /ix
  OTHER_LAWYER_DOCUMENT_PATTERNS = {
    'RG' => /\brg\b|\bcarteira de identidade\b/i,
    'PPP' => /\bppp\b|\bperfil profissiografico previdenciario\b/i,
    'laudo' => /\blaudos?\b|\brelatorio medico\b/i
  }.freeze
  DOCUMENT_ACQUISITION_QUESTION_PATTERN = /
    \b(?:como|onde)\b.{0,60}\b(?:cons[ei]g\w*|obte\w*|peg\w*|tir\w*|baix\w*|emit\w*|solicit\w*)\b
  /ix
  CNIS_ACQUISITION_PATTERN = /
    \b(?:como|onde)\b.{0,60}\b(?:cons[ei]g\w*|obte\w*|peg\w*|tir\w*|baix\w*|emit\w*|consult\w*)\b.{0,60}\bcnis\b |
    \bcnis\b.{0,60}\b(?:como|onde)\b.{0,60}\b(?:cons[ei]g\w*|obte\w*|peg\w*|tir\w*|baix\w*|emit\w*|consult\w*)\b
  /ix

  GENERIC_RESPONSE = <<~TEXT.squish.freeze
    Conte brevemente o que aconteceu e o que você precisa resolver para eu explicar como funciona o atendimento.
  TEXT
  DEFAULT_IDENTITY_DISCLOSURE =
    'Olá! Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos.'
  NEW_LEAD_REVIEW_NOTICE =
    'Depois deste atendimento inicial, a equipe analisará seu caso com atenção e entrará em contato em breve por aqui.'
  OTHER_LAWYER_RESPONSE = <<~TEXT.squish.freeze
    Também sou advogada e posso resolver isso para você no atendimento inicial da Dra. Paula.
    O que a outra advogada pediu exatamente?
  TEXT
  OTHER_LAWYER_CNIS_RESPONSE = <<~TEXT.squish.freeze
    Também sou advogada e posso resolver isso para você. Você consegue o CNIS pelo aplicativo ou site
    Meu INSS, entrando com sua conta gov.br e abrindo "Extrato de Contribuição (CNIS)". Não preciso do
    seu CPF para explicar esse passo.
  TEXT
  CNIS_ACQUISITION_RESPONSE = <<~TEXT.squish.freeze
    Você consegue o CNIS pelo aplicativo ou site Meu INSS, entrando com sua conta gov.br e abrindo
    "Extrato de Contribuição (CNIS)". Não preciso do seu CPF para explicar esse passo.
  TEXT
  OTHER_LAWYER_DOCUMENT_ACQUISITION_RESPONSES = {
    'RG' => <<~TEXT.squish,
      Também sou advogada e posso resolver isso para você. Entendi que a outra advogada pediu seu RG.
      Se você não estiver com o documento, solicite a emissão ou segunda via ao órgão de identificação do seu estado.
    TEXT
    'PPP' => <<~TEXT.squish,
      Também sou advogada e posso resolver isso para você. Entendi que a outra advogada pediu seu PPP.
      O PPP é emitido pela empresa onde você trabalhou; solicite-o ao RH ou ao setor responsável por segurança e medicina do trabalho.
    TEXT
    'laudo' => <<~TEXT.squish
      Também sou advogada e posso resolver isso para você. Entendi que a outra advogada pediu seu laudo.
      Solicite uma via legível, datada e assinada ao médico ou serviço de saúde que acompanha o caso.
    TEXT
  }.freeze

  INTENT_RESPONSES = [
    {
      intent: :denial,
      pattern: /\b(?:indeferid\w*|negad\w*|pedido\s+negado|recurso|prazo\s+(?:de|do)\s+recurso)\b/,
      response: <<~TEXT.squish
        Olá! Para analisar um pedido negado, conferimos o motivo da decisão, a data da ciência e os
        documentos usados, pois pode haver prazo para agir. Para começar, envie a carta de indeferimento
        e informe quando recebeu a decisão.
      TEXT
    },
    {
      intent: :revision,
      pattern: /\b(?:revis\w*|beneficio\s+(?:baixo|errado)|carta\s+de\s+concessao)\b/,
      response: <<~TEXT.squish
        Olá! Na revisão do benefício, conferimos o CNIS, o cálculo, a carta de concessão, os salários e os
        períodos que podem ter sido ignorados para identificar possíveis erros. Para começar, envie a carta
        de concessão e o CNIS atualizado.
      TEXT
    },
    {
      intent: :bpc,
      pattern: /\b(?:bpc|loas|beneficio\s+assistencial)\b/,
      response: <<~TEXT.squish
        Olá! Na análise do BPC/LOAS, verificamos idade ou deficiência, renda e composição familiar,
        CadÚnico e documentos médicos ou sociais. Para começar, informe sua idade, quantas pessoas moram
        com você e se existe deficiência ou impedimento de longo prazo.
      TEXT
    },
    {
      intent: :pension,
      pattern: /\b(?:pensao\s+por\s+morte|falec\w*|obito|dependente)\b/,
      response: <<~TEXT.squish
        Olá! Na análise de pensão por morte, verificamos a qualidade de segurado de quem faleceu, o vínculo
        do dependente, a data do óbito e os documentos disponíveis. Para começar, informe a data do
        falecimento e qual era sua relação com a pessoa.
      TEXT
    },
    {
      intent: :incapacity,
      pattern: /\b(?:incapacidad\w*|auxilio[ -]doenca|beneficio\s+por\s+incapacidade|aposentadoria\s+por\s+invalidez|invalidez)\b/,
      response: <<~TEXT.squish
        Olá! Na análise de benefício por incapacidade, verificamos seu vínculo com o INSS, contribuições,
        afastamentos e documentos médicos para identificar o caminho possível. Para começar, informe se
        está trabalhando ou afastado e envie o laudo ou relatório médico mais recente.
      TEXT
    },
    {
      intent: :maternity,
      pattern: /\b(?:salario[ -]maternidade|gestante|gravidez|parto|adocao)\b/,
      response: <<~TEXT.squish
        Olá! Na análise do salário-maternidade, verificamos sua categoria de segurada, contribuições e a
        data do parto, adoção ou afastamento para conferir o direito e os documentos necessários. Para
        começar, informe a data do parto ou a previsão e como você contribui para o INSS.
      TEXT
    },
    {
      intent: :special_activity,
      pattern: /\b(?:atividade\s+especial|insalubr\w*|periculos\w*|ppp|ltcat|agente\s+nocivo)\b/,
      response: <<~TEXT.squish
        Olá! Na análise de atividade especial, conferimos os períodos de exposição, PPP ou LTCAT e CNIS
        para avaliar o reconhecimento e o impacto na aposentadoria. Para começar, envie seu CNIS e informe
        em quais atividades e empresas trabalhou exposto a risco.
      TEXT
    },
    {
      intent: :rural,
      pattern: /\b(?:rural|agricult\w*|lavrador\w*|pescador\w*|segurado\s+especial)\b/,
      response: <<~TEXT.squish
        Olá! Na análise de tempo rural, verificamos os períodos trabalhados, o histórico familiar e os
        documentos que podem comprovar a atividade para avaliar o impacto na aposentadoria. Para começar,
        informe em quais anos trabalhou no meio rural e envie seu CNIS.
      TEXT
    },
    {
      intent: :planning,
      pattern: /\b(?:
        planejamento\s+previdenciario|aposent\w*|melhor\s+regra|melhor\s+caminho|
        tempo\s+de\s+contribuicao|como\s+funciona\s+a\s+analise
      )\b/x,
      response: [
        <<~TEXT.squish,
          Analisamos o histórico de contribuições, vínculos e documentos previdenciários para verificar se
          você já pode se aposentar, a regra mais vantajosa e a melhor data do pedido.
        TEXT
        <<~TEXT.squish
          Para começar, preciso do seu CNIS atualizado e sua idade; com essas informações, explico os próximos passos.
        TEXT
      ].join("\n\n")
    },
    {
      intent: :contributions,
      pattern: /\b(?:
        mei|autonom\w*|facultativ\w*|gps|das[- ]?mei|carne|codigo\s+de\s+pagamento|
        contribui\w*|como\s+contribuir|quero\s+contribuir|pagar\s+(?:o\s+)?inss|
        recolhimento\w*|complementacao\w*
      )\b/x,
      response: <<~TEXT.squish
        Olá! Na análise de contribuições, verificamos códigos, alíquotas, períodos e seu objetivo
        previdenciário para evitar pagamentos sem efeito ou abaixo do necessário. Para começar, envie o
        CNIS e diga se contribui como MEI, autônomo, facultativo ou CLT.
      TEXT
    },
    {
      intent: :cnis,
      pattern: /\b(?:cnis|extrato\s+previdenciario|vinculo\s+ausente|indicador\w*|remunerac\w*)\b/,
      response: <<~TEXT.squish
        Olá! Na análise do CNIS, conferimos vínculos, remunerações, contribuições e indicadores pendentes
        para localizar lacunas ou erros antes do pedido. Para começar, envie o CNIS atualizado e diga qual
        é seu objetivo previdenciário.
      TEXT
    }
  ].freeze

  # "pensao alimenticia" e Direito de Familia: sem o lookahead, um lead de
  # familia recebia a resposta pronta de previdenciario ja na primeira mensagem.
  PREVIDENCIARIO_PATTERN = /\b(?:inss|previdenc\w*|beneficio|auxilio|pensao(?!\s+aliment\w*)|aposent\w*|cnis)\b/

  def initialize(message:, identity_disclosure: DEFAULT_IDENTITY_DISCLOSURE, new_lead: true)
    @message = message
    @identity_disclosure = identity_disclosure.presence || DEFAULT_IDENTITY_DISCLOSURE
    @new_lead = new_lead
  end

  def perform
    response = response_for_message

    public_response = "#{@identity_disclosure} #{response.sub(/\AOlá!\s*/, '')}"
    new_lead_review_notice_required? ? insert_review_notice(public_response) : public_response
  end

  def previdenciario_intent?
    matched_intent.present? || normalized_message.match?(PREVIDENCIARIO_PATTERN)
  end

  def greeting_only?
    normalized_message.match?(GREETING_ONLY_PATTERN)
  end

  def material_case_details?
    normalized_message.match?(MATERIAL_CASE_DETAILS_PATTERN) ||
      normalized_message.match?(DATE_DETAIL_PATTERN) ||
      normalized_message.match?(intent_detail_pattern)
  end

  def other_lawyer_request?
    normalized_message.match?(OTHER_LAWYER_REQUEST_PATTERN)
  end

  def other_lawyer_response
    return unless other_lawyer_request?
    return OTHER_LAWYER_CNIS_RESPONSE if cnis_mentioned?

    requested_document = OTHER_LAWYER_DOCUMENT_PATTERNS.find { |_name, pattern| normalized_message.match?(pattern) }&.first
    return OTHER_LAWYER_RESPONSE if requested_document.blank?
    return OTHER_LAWYER_DOCUMENT_ACQUISITION_RESPONSES.fetch(requested_document) if document_acquisition_question?

    'Também sou advogada e posso resolver isso para você no atendimento inicial da Dra. Paula; ' \
      "entendi que a outra advogada pediu seu #{requested_document}. " \
      'Você quer ajuda para obter ou enviar esse documento?'
  end

  private

  def response_for_message
    contextual_response || intake_response
  end

  def contextual_response
    return other_lawyer_response if other_lawyer_request?
    return CNIS_ACQUISITION_RESPONSE if cnis_acquisition_question?
  end

  def intake_response
    return detail_aware_response if matched_intent && material_case_details?
    return matched_intent.fetch(:response) if matched_intent
    return generic_previdenciario_response if normalized_message.match?(PREVIDENCIARIO_PATTERN)

    GENERIC_RESPONSE
  end

  def cnis_acquisition_question?
    normalized_message.match?(CNIS_ACQUISITION_PATTERN)
  end

  def document_acquisition_question?
    normalized_message.match?(DOCUMENT_ACQUISITION_QUESTION_PATTERN)
  end

  def cnis_mentioned?
    normalized_message.match?(/\bcnis\b/)
  end

  def new_lead_review_notice_required?
    @new_lead && !greeting_only? && !other_lawyer_request? && !cnis_acquisition_question?
  end

  def insert_review_notice(response)
    question = response[/[^.!?]*\?\s*\z/]
    return "#{response} #{NEW_LEAD_REVIEW_NOTICE}" if question.blank?

    statement = response.delete_suffix(question).strip
    [statement, NEW_LEAD_REVIEW_NOTICE, question.strip].compact_blank.join(' ')
  end

  def matched_intent
    return @matched_intent if defined?(@matched_intent)

    if normalized_message.match?(SITE_PLANNING_PATTERN)
      @matched_intent = INTENT_RESPONSES.find { |intent| intent[:intent] == :planning }
      return @matched_intent
    end

    @matched_intent = INTENT_RESPONSES.find do |intent|
      normalized_message.match?(intent.fetch(:pattern))
    end
  end

  def normalized_message
    @normalized_message ||= I18n.transliterate(@message.to_s).downcase
  end

  def intent_detail_pattern
    INTENT_DETAIL_PATTERNS.fetch(matched_intent&.dig(:intent), NO_MATCH_PATTERN)
  end

  def generic_previdenciario_response
    <<~TEXT.squish
      Olá! No atendimento previdenciário, identificamos seu objetivo, conferimos o histórico no INSS e os
      documentos disponíveis para orientar a análise inicial. Conte qual benefício ou situação você precisa
      avaliar e, se tiver, envie seu CNIS atualizado.
    TEXT
  end

  def detail_aware_response
    return planning_detail_aware_response if matched_intent[:intent] == :planning

    explanation = matched_intent.fetch(:response).split('Para começar,').first.strip
    [explanation, send("#{matched_intent.fetch(:intent)}_next_step")].join(' ')
  end

  def denial_next_step
    return 'Para começar, envie a carta ou decisão do INSS.' unless decision_document_sent?
    return 'Em que data você recebeu a decisão do INSS?' unless decision_date_provided?

    'Qual foi o motivo informado pelo INSS para negar o pedido?'
  end

  def revision_next_step
    return 'Para começar, envie a carta de concessão.' unless concession_letter_sent?
    return 'Agora, envie seu CNIS atualizado.' unless cnis_provided?

    'Qual é o valor mensal do benefício que você recebe hoje?'
  end

  def bpc_next_step
    return 'Para começar, informe sua idade.' unless age_provided?
    return 'Quantas pessoas moram com você?' unless household_size_provided?
    return 'Existe deficiência ou impedimento de longo prazo?' unless bpc_basis_provided?
    return 'Qual é a renda mensal aproximada de quem mora com você?' unless household_income_provided?

    'Seu CadÚnico está atualizado?'
  end

  def pension_next_step
    return 'Para começar, informe a data do falecimento.' unless death_date_provided?
    return 'Qual era sua relação com a pessoa que faleceu?' unless relationship_provided?

    'A pessoa falecida contribuía para o INSS ou recebia algum benefício?'
  end

  def incapacity_next_step
    return 'Para começar, informe se está trabalhando ou afastado.' unless work_status_provided?
    return 'Agora, envie o laudo ou relatório médico mais recente.' unless medical_document_sent?
    return 'Em que data começou o afastamento?' unless date_provided?

    'Você já fez algum pedido de benefício por incapacidade no INSS?'
  end

  def maternity_next_step
    return 'Para começar, informe a data do parto ou a previsão.' unless maternity_date_provided?
    return 'Como você contribui para o INSS: CLT, MEI, autônoma ou facultativa?' unless contribution_category_provided?

    'Você tem o CNIS atualizado para enviar?'
  end

  def special_activity_next_step
    return 'Para começar, informe em quais atividades e empresas trabalhou exposto a risco.' unless work_history_provided?
    return 'Agora, envie seu CNIS atualizado.' unless cnis_provided?
    return 'Você pode enviar o PPP ou LTCAT desses períodos?' unless technical_document_sent?

    'Quais períodos de exposição precisam ser analisados primeiro?'
  end

  def rural_next_step
    return 'Para começar, informe em quais anos trabalhou no meio rural.' unless rural_period_provided?
    return 'Agora, envie seu CNIS atualizado.' unless cnis_provided?

    'Quais documentos você possui para comprovar a atividade rural?'
  end

  def contributions_next_step
    return 'Para começar, informe se contribui como MEI, autônomo, facultativo ou CLT.' unless contribution_category_provided?
    return 'Agora, envie seu CNIS atualizado.' unless cnis_provided?

    'Quais períodos ou guias você precisa conferir primeiro?'
  end

  def cnis_next_step
    return 'Para começar, envie seu CNIS atualizado.' unless cnis_provided?
    return 'Qual vínculo, remuneração ou período você precisa conferir?' unless cnis_objective_provided?

    'Em qual período aparece o erro ou a pendência?'
  end

  def planning_detail_aware_response
    explanation = matched_intent.fetch(:response).split("\n\n").first
    next_step = if age_provided? && cnis_provided?
                  <<~TEXT.squish
                    Com o CNIS e a idade já informados, a avaliação inicial pode começar. Você já fez algum pedido de
                    aposentadoria no INSS?
                  TEXT
                elsif age_provided?
                  'Para começar, me envie seu CNIS atualizado. Vou considerar a idade que você já informou.'
                elsif cnis_provided?
                  'Para começar, informe sua idade. Vou considerar o CNIS que você já enviou.'
                else
                  matched_intent.fetch(:response).split("\n\n").last
                end

    [explanation, next_step].join("\n\n")
  end

  def age_provided?
    age_value.present?
  end

  def cnis_provided?
    document_sent?(/cnis|extrato\s+previdenciario/)
  end

  def decision_document_sent?
    document_sent?(/carta|decisao|indeferimento/)
  end

  def concession_letter_sent?
    document_sent?(/carta(?:\s+de\s+concessao)?/)
  end

  def medical_document_sent?
    document_sent?(/laudo|relatorio(?:\s+medico)?|atestado/)
  end

  def technical_document_sent?
    document_sent?(/ppp|ltcat/)
  end

  def document_sent?(document_pattern)
    normalized_message.match?(
      /\b#{DOCUMENT_SEND_VERB_SOURCE}\b.{0,100}\b(?:#{document_pattern.source})\b|
       \b(?:#{document_pattern.source})\b.{0,60}\b#{DOCUMENT_SENT_STATUS_SOURCE}\b/x
    )
  end

  def date_provided?
    normalized_message.match?(DATE_DETAIL_PATTERN)
  end

  def decision_date_provided?
    date_provided? || normalized_message.match?(/\b(?:hoje|ontem|ha\s+\d+\s+dias?|faz\s+\d+\s+dias?)\b/)
  end

  alias death_date_provided? decision_date_provided?

  def household_size_provided?
    normalized_message.match?(/\b(?:moram?|somos)\s+\d{1,2}\b|\b\d{1,2}\s+pessoas?\b/)
  end

  def household_income_provided?
    normalized_message.match?(/\b(?:renda|ganha\w*|recebe\w*)\b.{0,40}(?:r\$|\d)/)
  end

  def bpc_basis_provided?
    normalized_message.match?(/\b(?:deficiencia|impedimento)\b/) || age_value.to_i >= 65
  end

  def age_value
    match = normalized_message.to_enum(:scan, AGE_VALUE_PATTERN).map { Regexp.last_match }.find do |candidate|
      age_context?(candidate)
    end
    match&.captures&.first
  end

  def age_context?(match)
    before = normalized_message[[match.begin(0) - 40, 0].max...match.begin(0)]
    after = normalized_message[match.end(0), 45]
    !before.match?(NON_AGE_CONTEXT_BEFORE_PATTERN) && !after.match?(NON_AGE_CONTEXT_AFTER_PATTERN)
  end

  def relationship_provided?
    normalized_message.match?(/\b(?:marido|esposa|companheir\w*|pai|mae|filh\w*|conjuge|dependente)\b/)
  end

  def work_status_provided?
    normalized_message.match?(/\b(?:estou\s+)?(?:trabalhando|afastad\w*|desempregad\w*|sem\s+trabalhar)\b/)
  end

  def maternity_date_provided?
    date_provided? || normalized_message.match?(
      /\b(?:janeiro|fevereiro|marco|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\b/
    )
  end

  def contribution_category_provided?
    normalized_message.match?(/\b(?:sou|como|contribuo\s+como)\s+(?:mei|autonom\w*|facultativ\w*|clt|empregad\w*)\b/)
  end

  def work_history_provided?
    normalized_message.match?(/\b(?:trabalhei|trabalho)\s+(?:como|na|no|em)|\bempresa\w*\b/)
  end

  def rural_period_provided?
    date_provided? || normalized_message.match?(/\b(?:19|20)\d{2}\b|\bpor\s+\d+\s+anos?\b/)
  end

  def cnis_objective_provided?
    normalized_message.match?(/\b(?:vinculo|remunerac\w*|indicador\w*|erro|ausente|corrigir|aposent\w*)\b/)
  end
end
# rubocop:enable Metrics/ClassLength
