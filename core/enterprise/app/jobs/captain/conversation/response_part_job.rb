# Envia as partes 2..n de uma resposta do Capitão, com intervalo entre elas,
# para o atendimento chegar em mensagens curtas em vez de um bloco único.
#
# Cada parte é reavaliada no momento do envio: se um humano assumiu a conversa
# nesse intervalo, as partes restantes são descartadas. Sem isso, a IA
# continuaria falando por cima do atendente.
class Captain::Conversation::ResponsePartJob < ApplicationJob
  queue_as :default

  def perform(conversation, assistant, content, agent_name = nil, **options)
    @conversation = conversation
    @assistant = assistant
    @origin_incoming_id = options[:origin_incoming_id]

    return if content.blank?
    return unless still_ai_turn?

    texto = if options[:policy_applied]
              content.to_s.strip
            else
              Captain::Conversation::ResponsePolicyService.new(
                conversation: @conversation,
                assistant: @assistant
              ).apply(content)
            end
    return if texto.blank?

    message = create_message(texto, agent_name)
    mark_analysis_notice_delivered!(message.content)
  end

  private

  def still_ai_turn?
    return false if @conversation.captain_conversation_state&.human_controlled?
    return false unless @conversation.inbox.captain_active?
    return false if @conversation.assignee_id.present?
    return false if incoming_received_after_origin?
    return false if human_replied_since_last_ai_message?

    true
  end

  def incoming_received_after_origin?
    return false if @origin_incoming_id.blank?

    @conversation.messages
                 .where(message_type: :incoming, private: false)
                 .exists?(['id > ?', @origin_incoming_id])
  end

  # Um humano respondeu depois da última mensagem da IA? Então a IA perdeu a vez.
  def human_replied_since_last_ai_message?
    ultima_ia = @conversation.messages
                             .where(sender_type: 'Captain::Assistant', private: false)
                             .reorder(id: :desc)
                             .first
    return false if ultima_ia.blank?

    @conversation.messages
                 .outgoing
                 .where(private: false)
                 .where('id > ?', ultima_ia.id)
                 .any? { |mensagem| public_human_message?(mensagem) }
  end

  def public_human_message?(mensagem)
    return false if mensagem.sender_type.in?(['AgentBot', 'Captain::Assistant'])

    atributos = mensagem.content_attributes.to_h
    return false if atributos['automation_rule_id'].present?

    mensagem.sender_type.present? ||
      ActiveModel::Type::Boolean.new.cast(atributos['external_echo'])
  end

  def create_message(texto, agent_name)
    atributos = {}
    atributos[:agent_name] = agent_name if agent_name.present?
    atributos[:ai_response_part] = true

    @conversation.messages.create!(
      message_type: :outgoing,
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      sender: @assistant,
      content: texto,
      additional_attributes: atributos
    )
  end

  def mark_analysis_notice_delivered!(content)
    return unless Captain::Conversation::ResponsePolicyService.review_notice?(content)

    state = CaptainConversationState.for_conversation!(@conversation)
    state.update!(analysis_notice_sent_at: Time.current) if state.analysis_notice_sent_at.blank?
  end
end
