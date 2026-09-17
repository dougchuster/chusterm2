require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Marketing::Events', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:admin_headers) { admin.create_new_auth_token }

  before { account.enable_features!('marketing') }

  def create_event(attrs = {})
    account.marketing_events.create!({
      provider: 'meta_ads',
      event_name: 'Lead',
      event_id: SecureRandom.hex(6),
      status: 'sent',
      direction: 'outbound'
    }.merge(attrs))
  end

  it 'lista eventos outbound com contagens' do
    create_event
    create_event(status: 'failed')

    get "/api/v1/accounts/#{account.id}/marketing/events",
        headers: admin_headers

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['events'].size).to eq(2)
    expect(body['counts']['sent']).to eq(1)
    expect(body['counts']['failed']).to eq(1)
  end

  it 'filtra por status' do
    create_event
    create_event(status: 'failed')

    get "/api/v1/accounts/#{account.id}/marketing/events?status=failed",
        headers: admin_headers

    expect(response.parsed_body['events'].size).to eq(1)
  end

  it 'isola eventos por conta' do
    other = create(:account)
    other.marketing_events.create!(provider: 'meta_ads', event_name: 'X', event_id: 'e1', status: 'sent')
    create_event

    get "/api/v1/accounts/#{account.id}/marketing/events",
        headers: admin_headers

    ids = response.parsed_body['events'].map { |e| e['event_id'] }
    expect(ids).not_to include('e1')
  end

  it 'reenfileira retry para evento com deal' do
    pipeline = account.crm_pipelines.default_first.first
    deal = account.crm_deals.create!(
      crm_pipeline: pipeline,
      crm_pipeline_stage: pipeline.crm_pipeline_stages.ordered.first,
      title: 'D'
    )
    event = create_event(status: 'failed', crm_deal: deal)

    expect do
      post "/api/v1/accounts/#{account.id}/marketing/events/#{event.id}/retry",
           headers: admin_headers
    end.to have_enqueued_job(Marketing::CapiDispatchJob).with(deal.id)
  end

  it 'rejeita retry sem deal associado' do
    event = create_event(status: 'failed')

    post "/api/v1/accounts/#{account.id}/marketing/events/#{event.id}/retry",
         headers: admin_headers

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'retorna 403 sem a feature flag' do
    account.disable_features!('marketing')

    get "/api/v1/accounts/#{account.id}/marketing/events",
        headers: admin_headers

    expect(response).to have_http_status(:forbidden)
  end
end
