require 'rails_helper'

RSpec.describe 'CRM Triage From Conversation API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }

  describe 'POST /api/v1/accounts/:account_id/crm/triage/from-conversation/:conversation_id' do
    it 'resolves the conversation by its internal id when another display id has the same value' do
      target = create(:conversation, account: account)
      decoy = create(:conversation, account: account)
      target.update_column(:display_id, target.id + 100_000) # rubocop:disable Rails/SkipsModelValidations
      decoy.update_column(:display_id, target.id) # rubocop:disable Rails/SkipsModelValidations

      deal = instance_double(
        CrmDeal,
        id: 51,
        title: 'Triagem correta',
        status: 'open',
        crm_pipeline_id: nil,
        crm_pipeline_stage_id: nil,
        contact_id: target.contact_id,
        conversation_id: target.id,
        score_total: 0,
        score_classification: nil,
        created_at: Time.current
      )
      service = instance_double(Crm::TriageFromConversation, perform: deal)
      expect(Crm::TriageFromConversation).to receive(:new).with(
        conversation: target,
        account: account,
        actor: admin
      ).and_return(service)

      post "/api/v1/accounts/#{account.id}/crm/triage/from-conversation/#{target.id}",
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        'conversation_id' => target.id,
        'conversation_display_id' => target.display_id
      )
    end
  end
end
