# frozen_string_literal: true

# 3.2 do PLANO_17_09.md — classificação por LLM com a taxonomia do pack da
# conta. Substitui o LegalTriageAnalyzer como entrada da triagem:
#
#   * LLM habilitada (captain_tasks + chave) => saída estruturada via schema,
#     categorias/subcategorias restritas ao pack instalado.
#   * Sem LLM (ou erro)                     => fallback às regras do
#     LegalTriageAnalyzer — o comportamento atual nunca fica pior.
#
# O resultado cru vai para `crm_deals.triage` (jsonb) — rastreável e
# inspecionável pela ficha do deal.
class Crm::Classifier
  SCHEMA = {
    type: 'object',
    properties: {
      category: { type: 'string', description: 'Categoria da lista fornecida' },
      subcategory: { type: 'string', description: 'Subcategoria da lista fornecida, ou vazio' },
      urgency_level: { type: 'string', enum: %w[baixa media alta critica] },
      intent: { type: 'string', description: 'orcamento|contratacao|duvida|suporte|outro' },
      summary: { type: 'string', description: 'Resumo do caso em 1-2 frases, pt-BR' },
      next_best_action: { type: 'string', description: 'Próxima ação sugerida para o atendente' },
      intake_answers: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            question_key: { type: 'string' },
            answer: { type: 'string' }
          },
          required: %w[question_key answer]
        }
      },
      confidence: { type: 'number', description: '0.0 a 1.0' }
    },
    required: %w[category urgency_level intent summary confidence]
  }.freeze

  MODEL = 'gpt-4o-mini'

  def initialize(conversation:, account: nil)
    @conversation = conversation
    @account = account || conversation.account
  end

  def perform
    raw = classify_with_llm
    triage = raw.present? ? normalize_llm_result(raw) : rules_fallback
    triage[:classified_by] = raw.present? ? 'llm' : 'rules'
    triage
  end

  private

  def llm_available?
    @account.feature_enabled?('captain_tasks') && Llm::Config.system_api_key.present?
  end

  def rules_fallback
    Crm::LegalTriageAnalyzer.new(conversation: @conversation).perform
  end

  def classify_with_llm
    return unless llm_available?

    text = transcript
    return if text.blank?

    Llm::Config.with_api_key(Llm::Config.system_api_key) do |context|
      chat = Llm::Config.chat_for(client: context, model: MODEL)
      chat.with_instructions(system_prompt)
      chat.with_schema(SCHEMA)
      response = chat.ask(user_prompt(text))
      parse_response(response)
    end
  rescue StandardError => e
    Rails.logger.warn("[Crm::Classifier] LLM falhou, usando regras: #{e.class}: #{e.message}")
    nil
  end

  def parse_response(response)
    content = response.content
    parsed = content.is_a?(String) ? JSON.parse(content) : content
    parsed.is_a?(Hash) ? parsed.deep_symbolize_keys : nil
  rescue JSON::ParserError
    nil
  end

  # A taxonomia do pack entra no prompt — o LLM só pode devolver valores que
  # existem na conta; qualquer alucinação fora da lista vira 'outro'.
  def packs
    @packs ||= Crm::PackOptions.installed_packs(@account)
  end

  def category_options
    packs.flat_map(&:categories).uniq { |o| o[:value] }
  end

  def normalize_llm_result(raw)
    category = valid_option(raw[:category], category_options)
    {
      legal_area: category,
      case_type: valid_subcategory(raw[:subcategory], category) || default_subcategory(category),
      urgency_level: normalize_urgency(raw[:urgency_level]),
      intent: raw[:intent].to_s.presence || 'outro',
      summary: raw[:summary].to_s,
      next_best_action: raw[:next_best_action].to_s,
      score_reason: "classificado por IA (#{(raw[:confidence].to_f * 100).round}% confiança)",
      conflict_check_status: 'pending',
      documents_status: 'pending',
      lgpd_basis: 'procedimentos_preliminares',
      consent_status: 'pending',
      data_retention_until: 5.years.from_now.to_date,
      data_quality: 'sufficient',
      intake_answers: normalize_intake(raw[:intake_answers])
    }
  end

  def normalize_urgency(value)
    %w[baixa media alta critica].include?(value.to_s) ? value.to_s : 'media'
  end

  def valid_option(value, options)
    option = options.find { |o| o[:value].to_s == value.to_s }
    option ? option[:value].to_s : 'outro'
  end

  def valid_subcategory(value, category)
    return if value.blank? || category.blank?

    sub = packs.flat_map { |p| p.subcategories_for(category) }.find { |o| o[:value].to_s == value.to_s }
    sub&.dig(:value)&.to_s
  end

  def default_subcategory(category)
    return if category.blank?

    packs.flat_map { |p| p.subcategories_for(category) }.first&.dig(:value)&.to_s
  end

  def normalize_intake(answers)
    Array(answers).filter_map do |item|
      key = item[:question_key].to_s.presence
      answer = item[:answer].to_s.presence
      { question_key: key, answer: answer } if key && answer
    end
  end

  def transcript
    @conversation.messages
                 .incoming
                 .where(private: false)
                 .includes(:attachments)
                 .order(created_at: :asc)
                 .last(20)
                 .flat_map do |message|
      meta_texts = message.attachments.filter_map do |attachment|
        meta = attachment.meta || {}
        [meta['transcribed_text'], meta['ocr_text']].compact_blank.join(' ').presence
      end
      [message.content.to_s.presence, *meta_texts].compact
    end.join("\n").squish
  end

  def system_prompt
    <<~PROMPT.squish
      #{prompt_base}
      Você classifica conversas de atendimento para um CRM. Responda SOMENTE
      com o JSON do schema. Categorias válidas: #{categories_summary}.
      Subcategorias por categoria: #{subcategories_summary}.
      urgency_level: baixa|media|alta|critica (critica só para risco real,
      ex.: prazo judicial, urgência médica). Se faltar contexto, use a
      categoria mais provável e confidence baixa.
      Perguntas de intake a cobrir quando a resposta estiver na conversa
      (question_key = "categoria.chave"): #{intake_questions_summary}.
      Responda em pt-BR.
    PROMPT
  end

  # 3.4/3.5: override por conta vence o prompt base do pack; sem os dois,
  # o prompt é só a taxonomia.
  def prompt_base
    override = (@account.custom_attributes || {})['crm_ai_prompt_override'].presence
    override || packs.filter_map { |p| p.ai[:prompt_base].presence }.join(' ')
  end

  def categories_summary
    category_options.map { |o| "#{o[:value]} (#{o[:label]})" }.join(', ')
  end

  def subcategories_summary
    category_options.filter_map do |o|
      subs = packs.flat_map { |p| p.subcategories_for(o[:value]) }.map { |s| s[:value] }
      "#{o[:value]}: #{subs.join(', ')}" if subs.any?
    end.join(' | ').presence || 'nenhuma'
  end

  # 3.3: perguntas de intake que o pack exige por categoria — a resposta
  # vai para intake_answers com question_key = "categoria.chave".
  def intake_questions_summary
    packs.flat_map do |pack|
      pack.intake_questions.flat_map do |category, questions|
        Array(questions).map { |q| "#{category}.#{q[:key]}: #{q[:question]}" }
      end
    end.uniq.join(' | ').presence || 'nenhuma'
  end

  def user_prompt(text)
    "Conversa do cliente (transcrição):\n\n#{text.truncate(4_000)}"
  end
end
