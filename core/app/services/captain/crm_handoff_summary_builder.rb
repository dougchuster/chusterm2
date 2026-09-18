class Captain::CrmHandoffSummaryBuilder
  # O painel do CRM reconhece a nota de handoff por este título.
  TITLE = 'Handoff para atendimento humano'.freeze

  def initialize(conversation, reason: nil)
    @conversation = conversation
    @reason = reason.presence
    @context = Captain::CrmContextBuilder.new(conversation).perform.with_indifferent_access
  end

  def perform
    sections = [
      TITLE,
      reason_line,
      contact_line,
      conversation_line,
      deal_line,
      documents_line,
      media_line,
      labels_line,
      next_action_line
    ].compact

    sections.join("\n")
  end

  private

  def reason_line
    return if @reason.blank?

    "Motivo: #{@reason}"
  end

  def contact_line
    contact = @context[:contact]
    return if contact.blank?

    owner = contact.dig(:crm_owner, :name) || contact.dig(:crm_owner, :email) || 'Sem responsavel'
    [
      "Contato: #{presence(contact[:name], 'Sem nome')}",
      "relacionamento #{presence(contact[:relationship_status], 'lead')}",
      "etapa #{presence(contact[:lifecycle_stage], 'lead')}",
      "responsavel #{owner}"
    ].join(' | ')
  end

  def conversation_line
    conversation = @context[:conversation]
    return if conversation.blank?

    assignee = conversation.dig(:assignee, :name) || conversation.dig(:assignee, :email) || 'Sem assignee'
    "Conversa: ##{conversation[:display_id]} | status #{conversation[:status]} | prioridade #{presence(conversation[:priority], 'normal')} | assignee #{assignee}"
  end

  def deal_line
    deal = @context[:deal]
    return if deal.blank?

    [
      "Oportunidade: #{presence(deal[:title], "Deal ##{deal[:id]}")}",
      "area #{presence(deal[:legal_area], 'nao identificada')}",
      "urgencia #{presence(deal[:urgency_level], 'nao definida')}",
      "score #{presence(deal[:score_total], 0)}"
    ].join(' | ')
  end

  def documents_line
    deal = @context[:deal]
    documents = Array(@context[:documents])
    return if deal.blank? && documents.blank?

    guesses = documents.filter_map { |document| document[:document_guess].presence }.uniq.first(5)
    status = deal&.dig(:documents_status)
    return "Documentos: #{status}" if guesses.blank?

    "Documentos: #{presence(status, 'em analise')} | reconhecidos: #{guesses.join(', ')}"
  end

  def media_line
    media = @context[:media] || {}
    audio_count = Array(media[:audio_transcriptions]).size
    image_count = Array(media[:image_descriptions]).size + Array(media[:ocr_texts]).size
    return if audio_count.zero? && image_count.zero?

    "Midia analisada: #{audio_count} audio(s), #{image_count} imagem/ns/OCR."
  end

  def labels_line
    labels = Array(@context[:labels]).filter_map { |label| label[:slug].presence || label[:title].presence }.uniq.first(8)
    return if labels.blank?

    "Etiquetas CRM: #{labels.join(', ')}"
  end

  def next_action_line
    action = @context.dig(:deal, :next_best_action)
    summary = @context.dig(:deal, :summary)
    return "Proxima acao: #{action}" if action.present?
    return "Resumo do caso: #{summary}" if summary.present?

    nil
  end

  def presence(value, fallback)
    value.presence || fallback
  end
end
