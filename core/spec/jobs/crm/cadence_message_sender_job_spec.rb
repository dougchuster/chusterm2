require 'rails_helper'

# D6 do PLANO_17_09.md — o sender re-checa consentimento e só envia texto
# livre dentro da janela de 24h do WhatsApp.
RSpec.describe Crm::CadenceMessageSenderJob do
  let(:account) { create(:account) }
  let(:pipeline) { CrmPipeline.create!(account: account, name: 'Funil', is_default: true) }
  let(:stage) { pipeline.crm_pipeline_stages.create!(account: account, name: 'Novo', slug: 'novo', position: 1) }
  let(:contact) { create(:contact, account: account, phone_number: '+5511999990000') }
  let(:deal) do
    account.crm_deals.create!(
      crm_pipeline: pipeline, crm_pipeline_stage: stage,
      contact: contact, title: 'Negócio'
    )
  end
  let(:cadence) { account.crm_cadences.create!(name: 'Follow-up') }
  let(:step) do
    cadence.crm_cadence_steps.create!(
      account: account, name: 'Msg 1', position: 0,
      action_type: 'send_message', template_body: 'Olá {{nome}}'
    )
  end
  let(:enrollment) do
    cadence.crm_cadence_enrollments.create!(
      account: account, crm_cadence: cadence, crm_deal: deal,
      next_step_at: 1.minute.ago, status: 'active'
    )
  end
  let(:inbox) do
    create(:inbox, account: account,
                   channel: create(:channel_whatsapp, account: account,
                                                      validate_provider_config: false, sync_templates: false))
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }

  def create_incoming_message(created_at)
    conversation.messages.create!(
      account: account, inbox: inbox,
      content: 'Oi', message_type: :incoming, created_at: created_at
    )
  end

  it 'não envia quando o consentimento do deal foi negado' do
    deal.update!(consent_status: 'denied', conversation: conversation)
    enrollment

    expect do
      described_class.perform_now(enrollment_id: enrollment.id, step_id: step.id, body: 'Oi')
    end.not_to(change { conversation.messages.count })
  end

  it 'não envia texto livre fora da janela de 24h e audita' do
    deal.update!(consent_status: 'granted', conversation: conversation)
    enrollment
    create_incoming_message(2.days.ago)

    expect do
      described_class.perform_now(enrollment_id: enrollment.id, step_id: step.id, body: 'Oi')
    end.not_to(change { conversation.messages.count })

    expect(account.crm_audit_events.where(action: 'cadence_message_blocked_window').count).to eq(1)
  end

  it 'envia dentro da janela de 24h' do
    deal.update!(consent_status: 'granted', conversation: conversation)
    enrollment
    create_incoming_message(1.hour.ago)

    expect do
      described_class.perform_now(enrollment_id: enrollment.id, step_id: step.id, body: 'Retorno')
    end.to(change { conversation.messages.outgoing.count }.by(1))
  end
end
