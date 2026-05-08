class Api::V1::Accounts::Crm::AuditEventsController < Api::V1::Accounts::Crm::BaseController
  def index
    authorize CrmAuditEvent, :index?

    @events = Current.account.crm_audit_events
    @events = @events.for_target(params[:target_type], params[:target_id]) if params[:target_type].present? && params[:target_id].present?
    @events = @events.where(action: params[:action]) if params[:action].present?
    @events = @events.where(actor_type: params[:actor_type]) if params[:actor_type].present?
    @events = @events.where('created_at >= ?', parsed_time(params[:from])) if params[:from].present?
    @events = @events.where('created_at <= ?', parsed_time(params[:to])&.end_of_day) if params[:to].present?
    @events = @events.order(created_at: :desc).limit(100)
    render json: @events.map { |e| serialize_event(e) }
  end

  private

  def serialize_event(event)
    {
      id: event.id,
      actor_type: event.actor_type,
      actor_id: event.actor_id,
      action: event.action,
      target_type: event.target_type,
      target_id: event.target_id,
      payload: event.payload,
      ip: event.ip,
      user_agent: event.user_agent,
      created_at: event.created_at
    }
  end

  def parsed_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
