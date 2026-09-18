require 'rails_helper'

# D6 do PLANO_17_09.md — o executor pula steps send_message de deals com
# consentimento negado e audita o bloqueio.
RSpec.describe Crm::CadenceExecutorJob do
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
    step
    cadence.crm_cadence_enrollments.create!(
      account: account, crm_cadence: cadence, crm_deal: deal,
      next_step_at: 1.minute.ago, status: 'active'
    )
  end

  it 'pula o step e audita quando o consentimento foi negado' do
    deal.update!(consent_status: 'denied')
    enrollment

    expect do
      described_class.new.perform
    end.not_to have_enqueued_job(Crm::CadenceMessageSenderJob)

    expect(account.crm_audit_events.where(action: 'cadence_step_blocked_consent').count).to eq(1)
  end

  it 'enfileira o envio quando o consentimento não foi negado' do
    deal.update!(consent_status: 'pending')
    enrollment

    expect do
      described_class.new.perform
    end.to have_enqueued_job(Crm::CadenceMessageSenderJob)
  end
end
