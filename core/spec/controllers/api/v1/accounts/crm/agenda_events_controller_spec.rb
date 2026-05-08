require 'rails_helper'

RSpec.describe 'CRM Agenda Events API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:assignee) { create(:user, account: account, role: :agent) }
  let(:from_time) { Time.zone.local(2026, 5, 4, 0, 0) }
  let(:to_time) { Time.zone.local(2026, 5, 10, 23, 59) }
  let(:headers) { admin.create_new_auth_token }

  def get_events(extra_params = {})
    get "/api/v1/accounts/#{account.id}/crm/agenda_events",
        params: {
          from: from_time.iso8601,
          to: to_time.iso8601
        }.merge(extra_params),
        headers: headers,
        as: :json
  end

  describe 'GET /api/v1/accounts/:account_id/crm/agenda_events' do
    it 'returns CRM activities and the first incoming lead contact in the range' do
      contact = create(:contact, :with_email, :with_phone_number, account: account, name: 'Douglas Chuster')
      conversation = create(:conversation, account: account, contact: contact, assignee: assignee)
      lead_started_at = from_time + 1.day + 9.hours

      create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                       message_type: :incoming, created_at: lead_started_at)
      create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                       message_type: :incoming, created_at: lead_started_at + 20.minutes)

      old_conversation = create(:conversation, account: account)
      create(:message, account: account, conversation: old_conversation, inbox: old_conversation.inbox,
                       message_type: :incoming, created_at: from_time - 1.day)
      create(:message, account: account, conversation: old_conversation, inbox: old_conversation.inbox,
                       message_type: :incoming, created_at: from_time + 2.days)

      CrmActivity.create!(
        account: account,
        owner: admin,
        assignee: assignee,
        contact: contact,
        conversation: conversation,
        kind: 'reuniao',
        title: 'Consulta previdenciaria',
        priority: 'alta',
        due_at: from_time + 2.days + 10.hours
      )

      get_events

      expect(response).to have_http_status(:success)
      sources = response.parsed_body.pluck('source')
      expect(sources).to contain_exactly('lead_contact', 'crm_activity')
      expect(response.parsed_body.pluck('event_key')).to include("lead_contact-#{conversation.id}")
      expect(response.parsed_body.pluck('event_key')).not_to include("lead_contact-#{old_conversation.id}")
    end

    it 'filters events by source and assignee' do
      contact = create(:contact, account: account)
      conversation = create(:conversation, account: account, contact: contact, assignee: assignee)
      create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                       message_type: :incoming, created_at: from_time + 4.hours)
      CrmActivity.create!(
        account: account,
        owner: admin,
        assignee: assignee,
        contact: contact,
        kind: 'follow_up',
        title: 'Retorno com documentos',
        priority: 'normal',
        due_at: from_time + 5.hours
      )

      get_events(source: 'lead_contact', assignee_id: assignee.id)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.size).to eq(1)
      expect(response.parsed_body.first['source']).to eq('lead_contact')
      expect(response.parsed_body.first.dig('assignee', 'id')).to eq(assignee.id)
    end
  end
end
