require 'rails_helper'

RSpec.describe 'CRM Audit Events API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  def create_event!(actor_type: 'user')
    CrmAuditEvent.create!(
      account: account,
      actor_type: actor_type,
      actor_id: admin.id,
      action: 'deal_updated',
      target_type: 'CrmDeal',
      target_id: 1,
      payload: { changes: { 'title' => %w[antes depois] } },
      # record_timestamps = false no model: quem registra fornece o timestamp
      # (Crm::AuditLogger passa created_at explicitamente).
      created_at: Time.current
    )
  end

  describe 'GET /api/v1/accounts/:account_id/crm/audit-events' do
    it 'returns the events for an administrator' do
      event = create_event!

      get "/api/v1/accounts/#{account.id}/crm/audit-events",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.map { |e| e['id'] }).to include(event.id)
    end

    it 'denies access to a non-admin agent' do
      create_event!

      get "/api/v1/accounts/#{account.id}/crm/audit-events",
          headers: agent.create_new_auth_token,
          as: :json

      # Pundit::NotAuthorizedError é renderizado como 401 nesta codebase
      # (RequestExceptionHandler#render_unauthorized).
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).to eq('error' => 'You are not authorized to do this action')
    end

    # Regressão: params[:action] é o nome da action Rails ('index'), não o
    # filtro — sem query_parameters a listagem vinha sempre vazia.
    it 'filters by action via query string' do
      create_event!
      CrmAuditEvent.create!(
        account: account, actor_type: 'user', actor_id: admin.id,
        action: 'deal_moved', target_type: 'CrmDeal', target_id: 1,
        payload: {}, created_at: Time.current
      )

      get "/api/v1/accounts/#{account.id}/crm/audit-events?action=deal_moved",
          headers: admin.create_new_auth_token,
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('action')).to eq(['deal_moved'])
    end
  end
end
