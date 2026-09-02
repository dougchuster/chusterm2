class Captain::Conversation::HumanHandoffRequestService
  EXPLICIT_REQUEST_PATTERN = /
    \b(?:quero|preciso|prefiro|gostaria)\b.{0,50}
      \b(?:atendente|humano|pessoa|alguem|atendimento\s+humano)\b |
    \b(?:falar|conversar)\b.{0,40}
      \b(?:atendente|humano|pessoa|alguem|dra\.?\s+paula|doutora\s+paula|advogada\s+responsavel)\b |
    \b(?:transfir|encaminh)\w*\b.{0,40}
      \b(?:atendente|humano|dra\.?\s+paula|doutora\s+paula)\b |
    \b(?:pare|parar|desative|desativar)\b.{0,40}
      \b(?:ia|robo|bot|automacao)\b
  /x

  def self.requested?(content)
    normalized = ActiveSupport::Inflector.transliterate(content.to_s).downcase
    normalized.match?(EXPLICIT_REQUEST_PATTERN)
  end

  def self.requested_in_conversation?(conversation)
    incoming = conversation.messages.where(message_type: :incoming, private: false)
    last_outgoing_id = conversation.messages
                                   .where(message_type: :outgoing, private: false)
                                   .maximum(:id)
    incoming = incoming.where('id > ?', last_outgoing_id) if last_outgoing_id
    incoming.reorder(id: :desc).limit(20).pluck(:content).any? { |content| requested?(content) }
  end
end
