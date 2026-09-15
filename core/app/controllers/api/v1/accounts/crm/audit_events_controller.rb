class Api::V1::Accounts::Crm::AuditEventsController < Api::V1::Accounts::Crm::BaseController
  def index
    authorize CrmAuditEvent, :index?

    # Filtros vêm de request.query_parameters: params[:action] sempre contém o
    # nome da action do Rails ('index'), o que esvaziava a listagem sempre.
    filters = request.query_parameters
    @events = Current.account.crm_audit_events
    @events = @events.for_target(filters[:target_type], filters[:target_id]) if filters[:target_type].present? && filters[:target_id].present?
    @events = @events.where(action: filters[:action]) if filters[:action].present?
    @events = @events.where(actor_type: filters[:actor_type]) if filters[:actor_type].present?
    @events = @events.where('created_at >= ?', parsed_time(filters[:from])) if filters[:from].present?
    @events = @events.where('created_at <= ?', parsed_time(filters[:to])&.end_of_day) if filters[:to].present?
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
