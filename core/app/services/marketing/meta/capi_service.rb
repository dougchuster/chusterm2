# Envia eventos server-side para a Meta Conversions API (CAPI).
# user_data vai com SHA-256 (phone/email normalizados) + lead_id do leadgen.
# Docs: https://developers.facebook.com/docs/marketing-api/conversions-api
class Marketing::Meta::CapiService
  STAGE_EVENT_MAP = {
    'won' => 'Purchase',
    'lost' => 'LeadDiscarded'
  }.freeze

  def initialize(connection:)
    @connection = connection
    @client = Marketing::Meta::GraphClient.new(access_token: connection.access_token)
  end

  # Retorna o MarketingEvent persistido (sent/failed/skipped).
  def send_stage_event(deal:, lead:, stage:)
    existing = @connection.account.marketing_events.find_by(event_id: event_id_for(deal))
    return existing if existing&.status == 'sent'

    dataset_id = @connection.metadata&.dig('capi_dataset_id')
    return record(deal, lead, 'skipped', {}) if dataset_id.blank?

    event_name = event_name_for(deal, stage)
    logged = record(deal, lead, 'pending', build_event(deal, lead, event_name), event_name: event_name)
    dispatch(logged, dataset_id)
  end

  private

  def dispatch(logged, dataset_id)
    response = @client.post("/#{dataset_id}/events", payload: { data: [logged.payload] })
    logged.update!(status: 'sent', response: response.slice('events_received', 'fbtrace_id'), sent_at: Time.current)
    logged
  rescue Marketing::Meta::GraphClient::ApiError, Marketing::Meta::GraphClient::RateLimited => e
    logged.update!(status: 'failed', response: { 'error' => e.message })
    logged
  end

  def event_name_for(deal, stage)
    custom = @connection.metadata&.dig('stage_event_map', deal.crm_pipeline_stage_id.to_s)
    return custom if custom.present?

    STAGE_EVENT_MAP.fetch(deal.status) { stage.name.to_s.parameterize.underscore.camelize }
  end

  def build_event(deal, lead, event_name)
    {
      event_name: event_name,
      event_time: deal.updated_at.to_i,
      event_id: event_id_for(deal),
      action_source: 'system_generated',
      event_source_url: nil,
      user_data: user_data_for(lead),
      custom_data: {
        lead_event_source: 'ChusteRM CRM',
        stage: deal.crm_pipeline_stage&.name,
        value: deal.value_estimate_cents.to_f / 100,
        currency: 'BRL'
      }.compact
    }.compact
  end

  def user_data_for(lead)
    data = {}
    phone = lead.phone.presence
    email = lead.email.presence
    data[:ph] = Digest::SHA256.hexdigest(phone.gsub(/\D/, '')) if phone
    data[:em] = Digest::SHA256.hexdigest(email.downcase.strip) if email
    data[:lead_id] = lead.leadgen_id
    data
  end

  def event_id_for(deal)
    "deal-#{deal.id}-#{deal.crm_pipeline_stage_id}-#{deal.updated_at.to_i}"
  end

  def record(deal, lead, status, payload, event_name: 'stage')
    @connection.account.marketing_events.find_or_create_by!(event_id: event_id_for(deal)) do |e|
      e.crm_external_connection = @connection
      e.crm_deal = deal
      e.marketing_lead = lead
      e.provider = 'meta_ads'
      e.direction = 'outbound'
      e.event_name = event_name
      e.status = status
      e.payload = payload
    end
  rescue ActiveRecord::RecordNotUnique
    @connection.account.marketing_events.find_by!(event_id: event_id_for(deal))
  end
end
