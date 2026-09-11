require 'rails_helper'

RSpec.describe 'CRM Activities API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:conversation) { create(:conversation, account: account) }

  def activity_payload(conversation_id)
    {
      conversation_id: conversation_id,
      kind: 'follow_up',
      title: 'Retorno ao cliente',
      priority: 'normal',
      due_at: 1.day.from_now.iso8601
    }
  end

  describe 'GET /api/v1/accounts/:account_id/crm/activities' do
    it 'respects the requested response limit' do
      3.times do |index|
        CrmActivity.create!(
          account: account,
          kind: 'follow_up',
          title: "Atividade #{index}",
          priority: 'normal',
          due_at: (index + 1).days.from_now
        )
      end

      get "/api/v1/accounts/#{account.id}/crm/activities",
          params: { limit: 2 },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.length).to eq(2)
    end

    it 'caps the response at 200 activities when no limit is given' do
      201.times do |index|
        CrmActivity.create!(
          account: account,
          kind: 'follow_up',
          title: "Atividade #{index}",
          priority: 'normal',
          due_at: (index + 1).days.from_now
        )
      end

      get "/api/v1/accounts/#{account.id}/crm/activities",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.length).to eq(200)
    end

    it 'returns both conversation identifiers for agenda fallback data' do
      conversation = create(:conversation, account: account)
      conversation.update_column(:display_id, conversation.id + 100_000) # rubocop:disable Rails/SkipsModelValidations
      CrmActivity.create!(
        account: account,
        conversation: conversation,
        kind: 'follow_up',
        title: 'Retorno ao cliente',
        priority: 'normal',
        due_at: 1.day.from_now
      )

      get "/api/v1/accounts/#{account.id}/crm/activities",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first).to include(
        'conversation_id' => conversation.id,
        'conversation_display_id' => conversation.display_id,
        'conversation' => {
          'id' => conversation.id,
          'display_id' => conversation.display_id
        }
      )
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/activities' do
    it 'accepts a current-account conversation primary key' do
      post "/api/v1/accounts/#{account.id}/crm/activities",
           params: activity_payload(conversation.id),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(account.crm_activities.last.conversation).to eq(conversation)
    end

    it 'rejects another account primary key' do
      foreign_conversation = create(:conversation, account: create(:account))

      expect do
        post "/api/v1/accounts/#{account.id}/crm/activities",
             params: activity_payload(foreign_conversation.id),
             headers: headers,
             as: :json
      end.not_to change(account.crm_activities, :count)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq('error' => 'Conversation not found')
    end

    it 'does not resolve a display id whose value is a foreign primary key' do
      foreign_conversation = create(:conversation, account: create(:account))
      conversation.update_column(:display_id, foreign_conversation.id) # rubocop:disable Rails/SkipsModelValidations

      post "/api/v1/accounts/#{account.id}/crm/activities",
           params: activity_payload(conversation.display_id),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:not_found)
      expect(account.crm_activities).to be_empty
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/crm/activities/:id' do
    it 'rejects a foreign conversation and preserves the current association' do
      activity = CrmActivity.create!(
        account: account,
        conversation: conversation,
        kind: 'follow_up',
        title: 'Atividade protegida',
        priority: 'normal'
      )
      foreign_conversation = create(:conversation, account: create(:account))

      patch "/api/v1/accounts/#{account.id}/crm/activities/#{activity.id}",
            params: { conversation_id: foreign_conversation.id, title: 'Alteração bloqueada' },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:not_found)
      expect(activity.reload).to have_attributes(
        conversation_id: conversation.id,
        title: 'Atividade protegida'
      )
    end
  end

  describe 'POST /api/v1/accounts/:account_id/crm/activities/schedule_suggestion' do
    it 'schedules an activity for a current-account conversation primary key' do
      post "/api/v1/accounts/#{account.id}/crm/activities/schedule_suggestion",
           params: activity_payload(conversation.id).merge(kind: 'reuniao'),
           headers: headers,
           as: :json

      expect(response).to have_http_status(:success)
      expect(account.crm_activities.last.conversation).to eq(conversation)
    end

    it 'rejects another account conversation before scheduling' do
      foreign_conversation = create(:conversation, account: create(:account))

      expect do
        post "/api/v1/accounts/#{account.id}/crm/activities/schedule_suggestion",
             params: activity_payload(foreign_conversation.id).merge(kind: 'reuniao'),
             headers: headers,
             as: :json
      end.not_to change(account.crm_activities, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
