require 'rails_helper'

RSpec.describe 'Rack::Attack CRM throttles', type: :request do
  let(:account) { create(:account) }

  around do |example|
    original_enabled = Rack::Attack.enabled
    Rack::Attack.enabled = true
    example.run
  ensure
    Rack::Attack.enabled = original_enabled
    Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear)
  end

  def analyst_path
    "/api/v1/accounts/#{account.id}/crm/analyst/ask"
  end

  def export_path
    "/api/v1/accounts/#{account.id}/crm/deals/export"
  end

  # 127.0.0.1 está no safelist do Rack::Attack — request specs precisam
  # simular um IP externo para o throttle disparar.
  def authed_post(path, uid: 'agent@example.com')
    post path,
         headers: { 'uid' => uid },
         env: { 'REMOTE_ADDR' => '203.0.113.10' },
         as: :json
  end

  it 'throttles analyst asks beyond the per-user limit' do
    limit = ENV.fetch('RATE_LIMIT_CRM_ANALYST', '20').to_i

    # travel_to fixa os requests no mesmo bucket do período — sem ele, um
    # loop que cruza a virada do minuto divide a contagem em duas janelas.
    freeze_time do
      limit.times { authed_post(analyst_path) }
      authed_post(analyst_path)
    end

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'throttles CRM exports beyond the per-user limit' do
    limit = ENV.fetch('RATE_LIMIT_CRM_EXPORT', '10').to_i

    freeze_time do
      limit.times { authed_post(export_path) }
      authed_post(export_path)
    end

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'tracks different users independently' do
    limit = ENV.fetch('RATE_LIMIT_CRM_ANALYST', '20').to_i

    freeze_time do
      limit.times { authed_post(analyst_path) }
      authed_post(analyst_path, uid: 'other-agent@example.com')
    end

    expect(response).not_to have_http_status(:too_many_requests)
  end
end
