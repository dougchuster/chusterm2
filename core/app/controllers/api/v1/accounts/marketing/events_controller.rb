class Api::V1::Accounts::Marketing::EventsController < Api::V1::Accounts::BaseController
  before_action :check_feature_flag

  def index
    events = filtered_events.limit(200)
    render json: {
      events: events.map { |event| serialize_event(event) },
      counts: Current.account.marketing_events.group(:status).count
    }
  end

  def retry
    event = Current.account.marketing_events.find(params[:id])
    return render json: { error: 'not_retryable' }, status: :unprocessable_entity if event.crm_deal_id.blank?

    Marketing::CapiDispatchJob.perform_later(event.crm_deal_id)
    render json: { event: serialize_event(event) }
  end

  private

  def check_feature_flag
    render json: { error: 'feature_disabled' }, status: :forbidden unless Current.account.feature_enabled?('marketing')
  end

  def filtered_events
    scope = Current.account.marketing_events.outbound.recent_first
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(provider: params[:provider]) if params[:provider].present?
    scope
  end

  def serialize_event(event)
    {
      id: event.id,
      provider: event.provider,
      direction: event.direction,
      event_name: event.event_name,
      event_id: event.event_id,
      status: event.status,
      crm_deal_id: event.crm_deal_id,
      deal_title: event.crm_deal&.title,
      lead_name: event.marketing_lead&.display_name,
      sent_at: event.sent_at,
      created_at: event.created_at,
      error: event.response&.dig('error')
    }
  end
end
