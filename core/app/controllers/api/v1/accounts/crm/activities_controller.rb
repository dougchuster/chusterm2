class Api::V1::Accounts::Crm::ActivitiesController < Api::V1::Accounts::Crm::BaseController
  before_action :activity, only: [:update, :destroy, :complete, :snooze, :sync_google_calendar]

  def index
    authorize CrmActivity, :index?

    @activities = filtered_activities
    render json: @activities.map { |a| serialize_activity(a) }
  end

  def calendar
    authorize CrmActivity, :index?

    activities = filtered_activities.where.not(due_at: nil)
    send_data(
      calendar_payload(activities),
      filename: "chusterm-agenda-#{Time.zone.today.iso8601}.ics",
      type: 'text/calendar; charset=utf-8',
      disposition: 'attachment'
    )
  end

  def import_google_calendar
    authorize CrmActivity, :create?

    result = Crm::GoogleCalendarImporter.new(
      account: Current.account,
      owner: Current.user,
      from: parsed_time(params[:from]) || Time.current.beginning_of_day,
      to: parsed_time(params[:to]) || 30.days.from_now.end_of_day
    ).perform
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'activities_imported_from_google_calendar',
      target: Current.account,
      payload: result
    )
    render json: result
  rescue Crm::GoogleCalendarImporter::AuthorizationRequired
    render json: {
      error: 'google_workspace_authorization_required',
      authorization_required: true
    }, status: :unprocessable_entity
  rescue Crm::GoogleCalendarImporter::ImportFailed => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def suggest_schedule
    authorize CrmActivity, :create?

    result = Crm::ScheduleSuggestionService.new(
      account: Current.account,
      owner: Current.user,
      params: schedule_suggestion_params
    ).perform
    render json: result
  rescue ActiveRecord::RecordNotFound
    render_conversation_not_found
  end

  def schedule_suggestion
    authorize CrmActivity, :create?

    @activity = Current.account.crm_activities.create!(scheduled_activity_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'activity_scheduled_by_ai',
      target: @activity,
      payload: { sync_google_calendar: sync_google_calendar? }
    )

    render json: scheduled_activity_response
  rescue Crm::GoogleCalendarExporter::AuthorizationRequired
    render json: {
      activity: serialize_activity(@activity),
      authorization_required: true,
      error: 'google_workspace_authorization_required'
    }, status: :accepted
  rescue Crm::GoogleCalendarExporter::ExportFailed => e
    render json: {
      activity: serialize_activity(@activity),
      calendar_error: e.message
    }, status: :accepted
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render_conversation_not_found
  end

  def create
    authorize CrmActivity, :create?

    @activity = Current.account.crm_activities.create!(activity_params)
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'activity_created', target: @activity)
    render json: serialize_activity(@activity), status: :created
  rescue ActiveRecord::RecordNotFound
    render_conversation_not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @activity, :update?

    attributes = activity_update_params
    @activity.update!(attributes)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'activity_updated',
      target: @activity,
      payload: { changes: audited_changes(@activity, attributes.keys) }
    )
    render json: serialize_activity(@activity)
  rescue ActiveRecord::RecordNotFound
    render_conversation_not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @activity, :destroy?

    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'activity_deleted',
      target: @activity,
      payload: {
        title: @activity.title,
        kind: @activity.kind,
        priority: @activity.priority,
        due_at: @activity.due_at
      }
    )
    @activity.destroy!
    head :no_content
  end

  def complete
    authorize @activity, :complete?

    @activity.complete!(outcome: params[:outcome], actor: Current.user)
    render json: serialize_activity(@activity)
  end

  def snooze
    authorize @activity, :snooze?

    snoozed_until = snooze_until
    @activity.update!(due_at: snoozed_until, reminder_at: snoozed_until)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'activity_snoozed',
      target: @activity,
      payload: { snoozed_until: snoozed_until }
    )
    render json: serialize_activity(@activity)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync_google_calendar
    authorize @activity, :update?

    result = Crm::GoogleCalendarExporter.new(account: Current.account, activity: @activity, user: Current.user).perform
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'activity_synced_to_google_calendar',
      target: @activity,
      payload: result
    )
    render json: result
  rescue Crm::GoogleCalendarExporter::AuthorizationRequired
    render json: {
      error: 'google_workspace_authorization_required',
      authorization_required: true
    }, status: :unprocessable_entity
  rescue Crm::GoogleCalendarExporter::ExportFailed => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def activity
    @activity = Current.account.crm_activities.find(params[:id])
  end

  def activity_params
    attrs = params.permit(:crm_deal_id, :contact_id, :conversation_id, :owner_id, :assignee_id,
                          :kind, :title, :description, :priority, :due_at, :reminder_at).to_h
    attrs[:owner_id] = Current.user.id if attrs[:owner_id].blank?
    resolve_activity_references!(attrs)
    resolve_conversation_id!(attrs)
  end

  def schedule_suggestion_params
    attrs = params.permit(:crm_deal_id, :contact_id, :conversation_id, :assignee_id,
                          :kind, :title, :description, :priority, :from, :to,
                          :duration_minutes, :horizon_days)
    resolve_activity_references!(attrs)
    resolve_conversation_id!(attrs)
  end

  def scheduled_activity_params
    attrs = params.permit(:crm_deal_id, :contact_id, :conversation_id, :assignee_id,
                          :kind, :title, :description, :priority, :due_at,
                          :reminder_at).to_h
    attrs[:owner_id] = Current.user.id
    attrs[:kind] = 'reuniao' if attrs[:kind].blank?
    attrs[:priority] = 'normal' if attrs[:priority].blank?
    attrs[:title] = 'Consulta juridica' if attrs[:title].blank?
    attrs[:due_at] = parsed_time(attrs[:due_at]) if attrs[:due_at].present?
    attrs[:reminder_at] = parsed_time(attrs[:reminder_at]) if attrs[:reminder_at].present?
    resolve_activity_references!(attrs)
    resolve_conversation_id!(attrs)
  end

  def sync_google_calendar?
    ActiveModel::Type::Boolean.new.cast(params[:sync_google_calendar])
  end

  def scheduled_activity_response
    response = { activity: serialize_activity(@activity) }
    if sync_google_calendar?
      response[:calendar] = Crm::GoogleCalendarExporter.new(account: Current.account, activity: @activity, user: Current.user).perform
      response[:activity] = serialize_activity(@activity.reload)
    end
    response
  end

  def filtered_activities
    activities = Current.account.crm_activities
    activities = activities.includes(:contact, :conversation, :owner, :assignee,
                                     crm_deal: [:contact, :crm_pipeline_stage, :conversation])
    activities = activities.where(crm_deal_id: params[:deal_id]) if params[:deal_id].present?
    activities = activities.where(owner_id: params[:owner_id]) if params[:owner_id].present?
    activities = activities.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    activities = activities.where(kind: params[:kind]) if params[:kind].present?
    activities = activities.where(priority: params[:priority]) if params[:priority].present?
    activities = filter_by_status(activities) unless params[:q].present?
    activities = filter_by_due_range(activities)
    activities = filter_by_search(activities)
    activities = activities.order(Arel.sql('due_at IS NULL, due_at ASC, created_at DESC'))
    requested_limit = params[:limit].to_i
    requested_limit.positive? ? activities.limit([requested_limit, 200].min) : activities
  end

  def activity_update_params
    attrs = params.permit(:crm_deal_id, :contact_id, :conversation_id, :assignee_id,
                          :kind, :title, :description, :priority, :due_at, :reminder_at)
    resolve_activity_references!(attrs)
    resolve_conversation_id!(attrs)
  end

  def resolve_activity_references!(attributes)
    resolve_account_scoped_ids!(
      attributes,
      crm_deal_id: :crm_deals,
      contact_id: :contacts,
      owner_id: :users,
      assignee_id: :users
    )
  end

  def snooze_until
    hours = params[:hours].to_i
    hours = 24 if hours <= 0
    Time.current + hours.hours
  end

  def filter_by_status(scope)
    return scope.overdue if params[:overdue].present?
    return scope.pending if params[:pending].present?

    case params[:status].presence
    when 'pending'
      scope.pending
    when 'completed'
      scope.completed
    when 'overdue'
      scope.overdue
    when 'today'
      scope.due_today
    else
      scope
    end
  end

  def filter_by_due_range(scope)
    scope = scope.where('due_at >= ?', parsed_time(params[:from])) if params[:from].present?
    scope = scope.where('due_at <= ?', parsed_time(params[:to])&.end_of_day) if params[:to].present?
    scope
  end

  def filter_by_search(scope)
    return scope if params[:q].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].to_s.downcase.strip)}%"
    scope.where(
      <<~SQL.squish,
        LOWER(crm_activities.title) LIKE :query
        OR LOWER(COALESCE(crm_activities.description, '')) LIKE :query
        OR LOWER(COALESCE(crm_activities.kind, '')) LIKE :query
        OR LOWER(COALESCE(crm_activities.priority, '')) LIKE :query
        OR EXISTS (
          SELECT 1 FROM contacts
          WHERE contacts.id = crm_activities.contact_id
          AND (
            LOWER(COALESCE(contacts.name, '')) LIKE :query
            OR LOWER(COALESCE(contacts.email, '')) LIKE :query
            OR LOWER(COALESCE(contacts.phone_number, '')) LIKE :query
          )
        )
        OR EXISTS (
          SELECT 1 FROM crm_deals
          LEFT JOIN contacts deal_contacts ON deal_contacts.id = crm_deals.contact_id
          WHERE crm_deals.id = crm_activities.crm_deal_id
          AND (
            LOWER(COALESCE(crm_deals.title, '')) LIKE :query
            OR LOWER(COALESCE(crm_deals.legal_area, '')) LIKE :query
            OR LOWER(COALESCE(crm_deals.case_type, '')) LIKE :query
            OR LOWER(COALESCE(deal_contacts.name, '')) LIKE :query
            OR LOWER(COALESCE(deal_contacts.email, '')) LIKE :query
            OR LOWER(COALESCE(deal_contacts.phone_number, '')) LIKE :query
          )
        )
        OR EXISTS (
          SELECT 1 FROM users
          WHERE users.id IN (crm_activities.owner_id, crm_activities.assignee_id)
          AND (
            LOWER(COALESCE(users.name, '')) LIKE :query
            OR LOWER(COALESCE(users.email, '')) LIKE :query
          )
        )
      SQL
      query: query
    )
  end

  def parsed_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def serialize_activity(activity)
    deal = activity.crm_deal
    contact = activity.contact || deal&.contact
    conversation = activity.conversation || deal&.conversation

    {
      id: activity.id,
      crm_deal_id: activity.crm_deal_id,
      conversation_id: conversation&.id || activity.conversation_id,
      conversation_display_id: conversation&.display_id,
      kind: activity.kind,
      title: activity.title,
      description: activity.description,
      priority: activity.priority,
      due_at: activity.due_at,
      reminder_at: activity.reminder_at,
      completed_at: activity.completed_at,
      outcome: activity.outcome,
      owner_id: activity.owner_id,
      assignee_id: activity.assignee_id,
      external_calendar_event_id: activity.external_calendar_event_id,
      external_calendar_link: activity.external_calendar_link,
      meeting_url: activity.meeting_url,
      external_calendar_synced_at: activity.external_calendar_synced_at,
      calendar_links: calendar_links(activity),
      status: activity.completed_at.present? ? 'completed' : 'pending',
      is_overdue: activity.completed_at.blank? && activity.due_at.present? && activity.due_at < Time.current,
      is_due_today: activity.completed_at.blank? && activity.due_at.present? &&
        activity.due_at.between?(Time.current.beginning_of_day, Time.current.end_of_day),
      created_at: activity.created_at,
      contact: contact ? serialize_contact(contact) : nil,
      deal: deal ? serialize_deal(deal) : nil,
      conversation: conversation ? serialize_conversation(conversation) : nil,
      owner: serialize_user(activity.owner),
      assignee: serialize_user(activity.assignee)
    }
  end

  def serialize_contact(contact)
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      relationship_status: contact.relationship_status,
      lifecycle_stage: contact.lifecycle_stage
    }
  end

  def serialize_deal(deal)
    {
      id: deal.id,
      title: deal.title,
      status: deal.status,
      legal_area: deal.legal_area,
      case_type: deal.case_type,
      urgency_level: deal.urgency_level,
      score_total: deal.score_total,
      stage: deal.crm_pipeline_stage ? {
        id: deal.crm_pipeline_stage.id,
        name: deal.crm_pipeline_stage.name,
        slug: deal.crm_pipeline_stage.slug
      } : nil
    }
  end

  def serialize_conversation(conversation)
    {
      id: conversation.id,
      display_id: conversation.display_id
    }
  end

  def serialize_user(user)
    return nil unless user

    {
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  def audited_changes(record, keys)
    keys.map(&:to_s).each_with_object({}) do |key, changes|
      next unless record.saved_changes.key?(key)

      changes[key] = {
        from: record.saved_changes[key].first,
        to: record.saved_changes[key].last
      }
    end
  end

  def calendar_links(activity)
    return {} if activity.due_at.blank?

    {
      google: google_calendar_url(activity)
    }
  end

  def google_calendar_url(activity)
    start_at = activity.due_at
    end_at = start_at + default_activity_duration(activity).minutes
    query = {
      action: 'TEMPLATE',
      text: activity.title,
      details: calendar_description(activity),
      dates: "#{calendar_time(start_at)}/#{calendar_time(end_at)}"
    }

    "https://calendar.google.com/calendar/render?#{query.to_query}"
  end

  def calendar_payload(activities)
    lines = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ChusteRM//CRM Agenda//PT-BR',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:ChusteRM CRM'
    ]
    activities.each { |activity| lines.concat(calendar_event(activity)) }
    lines << 'END:VCALENDAR'
    "#{lines.join("\r\n")}\r\n"
  end

  def calendar_event(activity)
    start_at = activity.due_at
    end_at = start_at + default_activity_duration(activity).minutes
    [
      'BEGIN:VEVENT',
      "UID:crm-activity-#{activity.id}@chusterm",
      "DTSTAMP:#{calendar_time(Time.current)}",
      "DTSTART:#{calendar_time(start_at)}",
      "DTEND:#{calendar_time(end_at)}",
      "SUMMARY:#{escape_ical(activity.title)}",
      "DESCRIPTION:#{escape_ical(calendar_description(activity))}",
      "STATUS:#{activity.completed_at.present? ? 'COMPLETED' : 'CONFIRMED'}",
      'END:VEVENT'
    ]
  end

  def calendar_description(activity)
    contact = activity.contact || activity.crm_deal&.contact
    [
      activity.description,
      ("Contato: #{contact.name}" if contact&.name.present?),
      ("Telefone: #{contact.phone_number}" if contact&.phone_number.present?),
      ("Caso: #{activity.crm_deal.title}" if activity.crm_deal&.title.present?),
      ("Responsavel: #{activity.assignee&.name || activity.owner&.name}" if activity.assignee || activity.owner)
    ].compact_blank.join("\n")
  end

  def default_activity_duration(activity)
    activity.kind == 'reuniao' ? 60 : 30
  end

  def calendar_time(time)
    time.utc.strftime('%Y%m%dT%H%M%SZ')
  end

  def escape_ical(value)
    value.to_s
         .gsub('\\', '\\\\')
         .gsub("\n", '\\n')
         .gsub(',', '\\,')
         .gsub(';', '\\;')
  end
end
