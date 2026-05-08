class Crm::ScheduleSuggestionService
  DEFAULT_DURATION = 60
  SLOT_STEP_MINUTES = 30
  WORK_START_HOUR = 9
  WORK_END_HOUR = 18
  MAX_SUGGESTIONS = 5

  def initialize(account:, owner:, params: {})
    @account = account
    @owner = owner
    @params = params.to_h.with_indifferent_access
  end

  def perform
    {
      draft: draft_activity,
      context: context_payload,
      suggestions: suggestions
    }
  end

  private

  attr_reader :account, :owner, :params

  def suggestions
    @suggestions ||= candidate_slots
                     .reject { |slot| overlaps_existing_activity?(slot[:starts_at], slot[:ends_at]) }
                     .sort_by { |slot| [-slot[:score], slot[:starts_at]] }
                     .first(MAX_SUGGESTIONS)
                     .map { |slot| serialize_slot(slot) }
  end

  def candidate_slots
    slots = []
    cursor = planning_start
    finish = planning_end

    while cursor < finish
      if working_time?(cursor)
        starts_at = cursor.change(sec: 0)
        ends_at = starts_at + duration_minutes.minutes
        slots << build_slot(starts_at, ends_at) if same_working_window?(starts_at, ends_at)
      end

      cursor += SLOT_STEP_MINUTES.minutes
    end

    slots
  end

  def build_slot(starts_at, ends_at)
    {
      starts_at: starts_at,
      ends_at: ends_at,
      duration_minutes: duration_minutes,
      score: slot_score(starts_at),
      reason: reason_for(starts_at)
    }
  end

  def serialize_slot(slot)
    {
      starts_at: slot[:starts_at],
      ends_at: slot[:ends_at],
      duration_minutes: slot[:duration_minutes],
      label: I18n.l(slot[:starts_at], format: '%d/%m/%Y %H:%M'),
      reason: slot[:reason]
    }
  end

  def slot_score(starts_at)
    score = 100
    score += 28 if starts_at.to_date == Time.zone.today
    score += 18 if starts_at.to_date == Time.zone.tomorrow
    score += 20 if high_priority?
    score += 10 if meeting_kind? && starts_at.hour.between?(10, 15)
    score += 8 if starts_at.hour.between?(9, 11)
    score -= starts_at.to_date.cwday
    score
  end

  def reason_for(starts_at)
    return 'Prioridade alta: horario livre mais proximo.' if high_priority?
    return 'Reuniao em horario comercial com melhor janela de atendimento.' if meeting_kind?

    starts_at.to_date == Time.zone.today ? 'Janela livre ainda hoje.' : 'Janela livre nos proximos dias.'
  end

  def overlaps_existing_activity?(starts_at, ends_at)
    occupied_windows.any? do |activity_start, activity_end|
      starts_at < activity_end && ends_at > activity_start
    end
  end

  def occupied_windows
    @occupied_windows ||= begin
      scope = account.crm_activities.pending.where(due_at: planning_start..planning_end)
      scope = scope.where('owner_id = :user_id OR assignee_id = :user_id', user_id: assignee_id) if assignee_id.present?
      scope.map do |activity|
        start_at = activity.due_at
        [start_at, start_at + activity_duration(activity).minutes]
      end
    end
  end

  def draft_activity
    {
      title: params[:title].presence || default_title,
      description: params[:description].presence || default_description,
      kind: kind,
      priority: priority,
      duration_minutes: duration_minutes,
      crm_deal_id: deal&.id,
      contact_id: contact&.id,
      assignee_id: assignee_id
    }
  end

  def context_payload
    {
      planning_from: planning_start,
      planning_to: planning_end,
      working_hours: "#{WORK_START_HOUR}:00-#{WORK_END_HOUR}:00",
      deal_title: deal&.title,
      contact_name: contact&.name,
      owner_name: owner&.name
    }
  end

  def default_title
    base = meeting_kind? ? 'Consulta juridica' : 'Follow-up juridico'
    contact_name = contact&.name.presence
    return base if contact_name.blank?

    "#{base} - #{contact_name}"
  end

  def default_description
    [
      'Sugestao criada pelo agendamento inteligente do CRM.',
      ("Caso: #{deal.title}" if deal&.title.present?),
      ("Contato: #{contact.name}" if contact&.name.present?)
    ].compact.join("\n")
  end

  def planning_start
    @planning_start ||= begin
      parsed_time(params[:from]) || Time.current
    end
  end

  def planning_end
    @planning_end ||= begin
      parsed_time(params[:to]) || planning_start + horizon_days.days
    end
  end

  def working_time?(time)
    !time.saturday? && !time.sunday? && time.hour >= WORK_START_HOUR && time.hour < WORK_END_HOUR
  end

  def same_working_window?(starts_at, ends_at)
    workday_end = starts_at.change(hour: WORK_END_HOUR, min: 0, sec: 0)
    starts_at.to_date == ends_at.to_date && ends_at <= workday_end
  end

  def parsed_time(value)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def horizon_days
    days = params[:horizon_days].to_i
    days.positive? ? [days, 30].min : 14
  end

  def duration_minutes
    minutes = params[:duration_minutes].to_i
    minutes.positive? ? [minutes, 240].min : DEFAULT_DURATION
  end

  def activity_duration(activity)
    activity.kind == 'reuniao' ? 60 : 30
  end

  def kind
    CrmActivity::KINDS.include?(params[:kind].to_s) ? params[:kind].to_s : 'reuniao'
  end

  def priority
    CrmActivity::PRIORITIES.include?(params[:priority].to_s) ? params[:priority].to_s : 'normal'
  end

  def meeting_kind?
    kind == 'reuniao'
  end

  def high_priority?
    %w[alta critica].include?(priority)
  end

  def assignee_id
    params[:assignee_id].presence || owner&.id
  end

  def deal
    @deal ||= account.crm_deals.find_by(id: params[:crm_deal_id])
  end

  def contact
    @contact ||= account.contacts.find_by(id: params[:contact_id]) || deal&.contact
  end
end
