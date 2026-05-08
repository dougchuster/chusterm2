require 'rails_helper'

RSpec.describe CrmCaptainTriageListener do
  include ActiveJob::TestHelper

  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { build(:message, account: account, inbox: inbox, conversation: conversation, message_type: 'incoming') }
  let(:event) { Events::Base.new('message_created', Time.current, message: message) }

  before do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  describe '#message_created' do
    it 'does not enqueue CRM triage when the account has no active pipeline stages' do
      expect { listener.message_created(event) }.not_to have_enqueued_job(Crm::CaptainTriageJob)
    end

    it 'enqueues CRM triage when the account has an active pipeline stage' do
      pipeline = CrmPipeline.create!(account: account, name: 'Pipeline teste', position: 1, is_default: true)
      CrmPipelineStage.create!(account: account, crm_pipeline: pipeline, name: 'Novo atendimento', position: 1)

      expect { listener.message_created(event) }
        .to have_enqueued_job(Crm::CaptainTriageJob)
        .with(conversation.id, account.id)
    end
  end
end
