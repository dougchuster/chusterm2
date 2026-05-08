class Api::V1::Accounts::Crm::AgendaEventsController < Api::V1::Accounts::Crm::BaseController
  def index
    authorize CrmActivity, :index?

    render json: filtered_events.sort_by { |event| event[:start_at].to_i }
  end

  private

  def filtered_events
    events = []
    events.concat(activity_events) if include_activity_events?
    events.concat(lead_contact_events) if include_lead_contact_events?
    filter_events_by_query(events)
  end

  def include_activity_events?
    params[:source].blank? || params[:source] == 'crm_activity'
  end

  def include_lead_contact_events?
    return false if params[:sync_status].present?

    params[:source].blank? || params[:source] == 'lead_contact'
  end

  def activity_events
    scope = Current.account.crm_activities
                           .where.not(due_at: nil)
                           .includes(:contact, :conversation, :owner, :assignee,
                                     crm_deal: [:contact, :conversation, :crm_pipeline_stage])
                           .where(due_at: from_time..to_time)

    scope = scope.where(priority: params[:priority]) if params[:priority].present?
    scope = filter_activity_assignee(scope)
    scope = filter_activity_sync_status(scope)

    scope.map { |activity| serialize_activity_event(activity) }
  end

  def lead_contact_events
    conversations_scope = permitted_conversations
    conversations_scope = filter_conversation_assignee(conversations_scope)

    first_messages = Message.incoming
                            .where(account_id: Current.account.id, private: false)
                            .where(conversation_id: conversations_scope.select(:id))
                            .reorder(nil)
                            .group(:conversation_id)
                            .having('MIN(messages.created_at) >= ? AND MIN(messages.created_at) <= ?', from_time, to_time)
                            .minimum(:created_at)

    return [] if first_messages.blank?

    conversations = conversations_scope
                    .where(id: first_messages.keys)
                    .includes(:contact, :inbox, :assignee)
                    .index_by(&:id)
    deals_by_conversation = Current.account.crm_deals
                                    .where(conversation_id: first_messages.keys)
                                    .includes(:contact, :crm_pipeline_stage)
                                    .order(created_at: :desc)
                                    .group_by(&:conversation_id)

    first_messages.filter_map do |conversation_id, first_contact_at|
      conversation = conversations[conversation_id]
      next unless conversation

      serialize_lead_contact_event(
        conversation,
        first_contact_at,
        deals_by_conversation[conversation_id]&.first
      )
    end
  end

  def permitted_conversations
    Conversations::PermissionFilterService.new(
      Current.account.conversations,
      Current.user,
      Current.account
    ).perform
  end

  def filter_activity_assignee(scope)
    return scope if params[:assignee_id].blank?
    return scope.where(assignee_id: nil, owner_id: nil) if params[:assignee_id] == 'none'

    scope.where(
      'crm_activities.assignee_id = :assignee_id OR crm_activities.owner_id = :assignee_id',
      assignee_id: params[:assignee_id]
    )
  end

  def filter_conversation_assignee(scope)
    return scope if params[:assignee_id].blank?
    return scope.where(assignee_id: nil) if params[:assignee_id] == 'none'

    scope.where(assignee_id: params[:assignee_id])
  end

  def filter_activity_sync_status(scope)
    case params[:sync_status].presence
    when 'synced'
      scope.where.not(external_calendar_event_id: nil)
    when 'unsynced'
      scope.where(external_calendar_event_id: nil)
    else
      scope
    end
  end

  def filter_events_by_query(events)
    return events if params[:q].blank?

    query = normalize_text(params[:q])
    events.select { |event| normalize_text(searchable_event_text(event)).include?(query) }
  end

  def searchable_event_text(event)
    [
      event[:title],
      event[:kind],
      event[:status],
      event.dig(:contact, :name),
      event.dig(:contact, :email),
      event.dig(:contact, :phone_number),
      event.dig(:deal, :title),
      event.dig(:deal, :legal_area),
      event.dig(:deal, :stage, :name),
      event.dig(:conversation, :display_id),
      event.dig(:assignee, :name),
      event.dig(:assignee, :email),
      event.dig(:inbox, :name)
    ].compact_blank.join(' ')
  end

  def normalize_text(value)
    I18n.transliterate(value.to_s).downcase.strip
  end

  def serialize_activity_event(activity)
    deal = activity.crm_deal
    contact = activity.contact || deal&.contact
    conversation = activity.conversation || deal&.conversation
    end_at = activity.due_at + default_activity_duration(activity).minutes

    {
      id: activity.id,
      event_key: "crm_activity-#{activity.id}",
      source: 'crm_activity',
      title: activity.title,
      description: activity.description,
      kind: activity.kind,
      start_at: activity.due_at,
      end_at: end_at,
      status: activity.completed_at.present? ? 'completed' : activity_status(activity),
      priority: activity.priority,
      editable: true,
      activity: serialize_activity(activity),
      activity_id: activity.id,
      contact: contact ? serialize_contact(contact) : nil,
      deal: deal ? serialize_deal(deal) : nil,
      conversation: conversation ? serialize_conversation(conversation) : nil,
      assignee: serialize_user(activity.assignee || activity.owner),
      owner: serialize_user(activity.owner),
      inbox: conversation&.inbox ? serialize_inbox(conversation.inbox) : nil,
      links: activity_links(activity, deal, conversation)
    }
  end

  def serialize_lead_contact_event(conversation, first_contact_at, deal)
    contact = conversation.contact

    {
      id: conversation.id,
      event_key: "lead_contact-#{conversation.id}",
      source: 'lead_contact',
      title: "Entrada de lead - #{contact&.name.presence || "Atendimento ##{conversation.display_id}"}",
      description: 'Primeira mensagem recebida do lead.',
      kind: 'lead_contact',
      start_at: first_contact_at,
      end_at: first_contact_at + 15.minutes,
      status: conversation.status,
      priority: conversation.priority || 'normal',
      editable: false,
      activity: nil,
      activity_id: nil,
      contact: contact ? serialize_contact(contact) : nil,
      deal: deal ? serialize_deal(deal) : nil,
      conversation: serialize_conversation(conversation),
      assignee: serialize_user(conversation.assignee),
      owner: serialize_user(conversation.assignee),
      inbox: conversation.inbox ? serialize_inbox(conversation.inbox) : nil,
      links: lead_contact_links(deal, conversation)
    }
  end

  def serialize_activity(activity)
    deal = activity.crm_deal
    contact = activity.contact || deal&.contact
    conversation = activity.conversation || deal&.conversation

    {
      id: activity.id,
      crm_deal_id: activity.crm_deal_id,
      contact_id: contact&.id || activity.contact_id,
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
      status: activity.completed_at.present? ? 'completed' : activity_status(activity),
      is_overdue: activity.completed_at.blank? && activity.due_at.present? && activity.due_at < Time.current,
      is_due_today: activity.completed_at.blank? && activity.due_at.present? &&
        activity.due_at.between?(Time.current.beginning_of_day, Time.current.end_of_day)
    }
  end

  def activity_status(activity)
    return 'overdue' if activity.due_at.present? && activity.due_at < Time.current
    return 'today' if activity.due_at.present? && activity.due_at.between?(Time.current.beginning_of_day, Time.current.end_of_day)

    'scheduled'
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
      display_id: conversation.display_id,
      status: conversation.status,
      priority: conversation.priority,
      created_at: conversation.created_at,
      last_activity_at: conversation.last_activity_at
    }
  end

  def serialize_inbox(inbox)
    {
      id: inbox.id,
      name: inbox.name,
      channel_type: inbox.channel_type
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

  def activity_links(activity, deal, conversation)
    {
      deal: deal ? "/app/accounts/#{Current.account.id}/crm/deals/#{deal.id}" : nil,
      conversation: conversation ? "/app/accounts/#{Current.account.id}/conversations/#{conversation.display_id}" : nil,
      google: activity.external_calendar_link,
      meet: activity.meeting_url
    }.compact
  end

  def lead_contact_links(deal, conversation)
    {
      deal: deal ? "/app/accounts/#{Current.account.id}/crm/deals/#{deal.id}" : nil,
      conversation: "/app/accounts/#{Current.account.id}/conversations/#{conversation.display_id}"
    }.compact
  end

  def default_activity_duration(activity)
    activity.kind == 'reuniao' ? 60 : 30
  end

  def from_time
    @from_time ||= parsed_time(params[:from]) || Time.current.beginning_of_day
  end

  def to_time
    @to_time ||= parsed_time(params[:to]) || from_time.end_of_day
  end

  def parsed_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
