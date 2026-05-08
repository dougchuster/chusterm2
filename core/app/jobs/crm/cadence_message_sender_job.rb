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

    conversation = deal.conversation || find_or_create_conversation(account, inbox, contact)
    return unless conversation

    conversation.messages.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      content: body,
      message_type: :outgoing,
      source_id: "cadence-#{enrollment.crm_cadence_id}-#{step_id}"
    )
  rescue StandardError => e
    ChusteRMExceptionTracker.new(e, account: enrollment&.account).capture_exception
    Rails.logger.error "CadenceMessageSender error: #{e.message}"
  end

  private

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
