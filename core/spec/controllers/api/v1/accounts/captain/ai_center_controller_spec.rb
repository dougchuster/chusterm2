require 'rails_helper'

RSpec.describe 'Captain AI Center API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:inbox) { create(:inbox, account: account) }

  def create_state!(ai_mode:, reason: nil, reason_code: nil)
    conversation = create(:conversation, account: account, inbox: inbox)
    CaptainConversationState.create!(
      account: account,
      conversation: conversation,
      ai_mode: ai_mode,
      handoff_reason: reason,
      handoff_reason_code: reason_code,
      handoff_at: CaptainConversationState::HUMAN_MODES.include?(ai_mode) ? Time.current : nil
    )
  end

  describe 'GET /api/v1/accounts/:account_id/captain/ai_center' do
    it 'returns summary counts, media health and paused conversations with structured reasons' do
      create_state!(ai_mode: 'auto')
      paused_state = create_state!(
        ai_mode: 'human_only',
        reason: 'Atendimento humano detectado; IA pausada automaticamente.',
        reason_code: 'human_takeover'
      )
      paused_state.conversation.update_column( # rubocop:disable Rails/SkipsModelValidations
        :display_id,
        paused_state.conversation_id + 100_000
      )

      get "/api/v1/accounts/#{account.id}/captain/ai_center", headers: headers, as: :json

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body['summary']['auto']).to eq(1)
      expect(body['summary']['human_only']).to eq(1)
      expect(body['summary']['by_reason_code']).to eq('human_takeover' => 1)
      expect(body['media']).to be_present
      expect(body['metrics']).to include('resolved_total', 'deflection_rate', 'avg_seconds_to_handoff')
      expect(body['paused_conversations'].length).to eq(1)
      paused_conversation = body['paused_conversations'].first
      expect(paused_conversation).to include(
        'conversation_id' => paused_state.conversation_id,
        'conversation_display_id' => paused_state.conversation.display_id,
        'handoff_reason_code' => 'human_takeover'
      )
    end

    it 'requires authentication' do
      get "/api/v1/accounts/#{account.id}/captain/ai_center", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
