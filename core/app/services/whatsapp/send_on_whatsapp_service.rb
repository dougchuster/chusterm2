class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    return send_session_message if evolution_channel?

    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message
    else
      send_session_message
    end
  end

  def send_template_message
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    return unless ensure_evolution_recipient_available

    message_id = channel.send_template(recipient_number, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       }, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def send_session_message
    return unless ensure_evolution_recipient_available

    message_id = channel.send_message(recipient_number, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end

  def evolution_channel?
    channel.provider == 'evolution'
  end

  def recipient_number
    return message.conversation.contact&.phone_number if evolution_channel?

    message.conversation.contact_inbox.source_id
  end

  def ensure_evolution_recipient_available
    return true unless evolution_channel?
    return true if recipient_number.present?

    message.update!(
      status: :failed,
      external_error: 'Contato WhatsApp sem telefone real. Aguarde uma nova mensagem do contato para resolver o identificador LID antes de responder.'
    )
    false
  end
end
