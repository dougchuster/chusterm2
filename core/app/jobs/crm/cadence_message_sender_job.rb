class Crm::CadenceMessageSenderJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(enrollment_id:, step_id:, body:)
    enrollment = CrmCadenceEnrollment.find_by(id: enrollment_id)
    return unless enrollment

    deal = enrollment.crm_deal
    contact = deal.contact
    return unless contact&.phone_number.present?

    account = enrollment.account
    inbox = whatsapp_inbox(account)
    return unless inbox

    # D6: re-checa consentimento aqui também — o job pode rodar depois de o
    # executor e a situação LGPD do deal pode ter mudado.
    return unless allowed_by_consent?(deal)

    conversation = deal.conversation || find_or_create_conversation(account, inbox, contact)
    return unless conversation

    # D6: WhatsApp só aceita texto livre dentro da janela de 24h após a
    # última mensagem do cliente — fora dela a mensagem seria rejeitada.
    return unless within_messaging_window?(conversation, deal, enrollment, step_id)

    conversation.messages.create!(
      account: account,
      inbox: inbox,
      content: body,
      message_type: :outgoing,
      source_id: "cadence-#{enrollment.crm_cadence_id}-#{step_id}"
    )
  rescue StandardError => e
    ChusteRMExceptionTracker.new(e, account: enrollment&.account).capture_exception
    Rails.logger.error "CadenceMessageSender error: #{e.message}"
  end

  private

  def within_messaging_window?(conversation, deal, enrollment, step_id)
    return true if Conversations::MessageWindowService.new(conversation).can_reply?

    Crm::AuditLogger.log(
      account: deal.account,
      actor: nil,
      action: 'cadence_message_blocked_window',
      target: deal,
      payload: { cadence_id: enrollment.crm_cadence_id, step_id: step_id, conversation_id: conversation.id }
    )
    false
  end

  def allowed_by_consent?(deal)
    return true unless deal.consent_status == 'denied'

    Rails.logger.info "[CRM Cadence] envio bloqueado — deal ##{deal.id} com consentimento negado"
    false
  end

  def whatsapp_inbox(account)
    account.inboxes.where(channel_type: 'Channel::Whatsapp').first
  end

  def find_or_create_conversation(account, inbox, contact)
    contact_inbox = contact.contact_inboxes.find_by(inbox: inbox)
    return nil unless contact_inbox

    contact_inbox.conversations.where(account: account).last ||
      ::Conversation.create!(
        account: account,
        inbox: inbox,
        contact: contact,
        contact_inbox: contact_inbox,
        status: :open
      )
  end
end
