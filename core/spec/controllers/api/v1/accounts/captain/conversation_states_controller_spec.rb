require 'rails_helper'

RSpec.describe 'Captain Conversation States API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:inbox) { create(:inbox, account: account) }

  describe 'GET /api/v1/accounts/:account_id/captain/conversation_states/:conversation_display_id' do
    it 'resolves only by display id when it collides with another conversation database id' do
      decoy = create(:conversation, account: account, inbox: inbox)
      target = create(:conversation, account: account, inbox: inbox)
      decoy.update_column(:display_id, decoy.id + 100_000) # rubocop:disable Rails/SkipsModelValidations
      target.update_column(:display_id, decoy.id) # rubocop:disable Rails/SkipsModelValidations

      decoy_state = CaptainConversationState.create!(conversation: decoy, ai_mode: 'paused')
      target_state = CaptainConversationState.create!(conversation: target, ai_mode: 'auto')

      get "/api/v1/accounts/#{account.id}/captain/conversation_states/#{target.display_id}",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        'id' => target_state.id,
        'conversation_id' => target.id,
        'conversation_display_id' => target.display_id,
        'ai_mode' => 'auto'
      )
      expect(response.parsed_body['id']).not_to eq(decoy_state.id)
    end

    it 'returns explainable lead or customer relationship evidence' do
      contact = create(:contact, account: account, contact_type: :customer, relationship_status: 'customer')
      conversation = create(:conversation, account: account, inbox: inbox, contact: contact)

      get "/api/v1/accounts/#{account.id}/captain/conversation_states/#{conversation.display_id}",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['relationship']).to include(
        'status' => 'customer',
        'automatic_handoff' => false
      )
      expect(response.parsed_body.dig('relationship', 'evidence')).to be_present
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/captain/conversation_states/:conversation_display_id' do
    it 'does not hand off when a score reaches 100' do
      conversation = create(:conversation, account: account, inbox: inbox)

      patch "/api/v1/accounts/#{account.id}/captain/conversation_states/#{conversation.display_id}",
            params: { conversation_state: { score_total: 100, score_classification: 'prioridade_alta' } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('score_total' => 100, 'ai_mode' => 'auto')
      expect(response.parsed_body['handoff_at']).to be_nil
    end

    it 'rejects a CRM deal from another account' do
      conversation = create(:conversation, account: account, inbox: inbox)
      foreign_account = create(:account)
      foreign_pipeline = CrmPipeline.create!(account: foreign_account, name: 'Pipeline externo', position: 1)
      foreign_stage = CrmPipelineStage.create!(
        account: foreign_account,
        crm_pipeline: foreign_pipeline,
        name: 'Etapa externa',
        position: 1
      )
      foreign_deal = CrmDeal.create!(
        account: foreign_account,
        crm_pipeline: foreign_pipeline,
        crm_pipeline_stage: foreign_stage,
        title: 'Segredo externo'
      )

      patch "/api/v1/accounts/#{account.id}/captain/conversation_states/#{conversation.display_id}",
            params: { conversation_state: { crm_deal_id: foreign_deal.id } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Segredo externo')
      expect(conversation.reload.captain_conversation_state&.crm_deal_id).to be_nil
    end
  end
end
