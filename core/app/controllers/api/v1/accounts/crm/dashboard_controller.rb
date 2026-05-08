class Api::V1::Accounts::Crm::DashboardController < Api::V1::Accounts::Crm::BaseController
  def index
    authorize CrmDeal, :index?

    account = Current.account
    deals = filtered_deals(account.crm_deals)
    activities = filtered_activities(account.crm_activities)
    open_deals = deals.open_deals
    won_deals = deals.where(status: 'won')
    lost_deals = deals.where(status: 'lost')

    render json: {
      open_deals: open_deals.count,
      total_open_deals: open_deals.count,
      qualified_deals: open_deals.where('score_total >= 60').count,
      priority_deals: open_deals.where('score_total >= 80').count,
      overdue_activities: activities.overdue.count,
      new_leads_today: deals.where('created_at >= ?', Time.current.beginning_of_day).count,
      new_leads_7_days: deals.where('created_at >= ?', 7.days.ago).count,
      won_deals: won_deals.count,
      won_deals_this_month: won_deals.where('closed_at >= ?', Time.current.beginning_of_month).count,
      lost_deals: lost_deals.count,
      base_clients: deals.where(operational_status: 'base_client').count,
      returning_clients: deals.where(operational_status: 'returning_client').count,
      discarded_deals: deals.where(operational_status: %w[invalid spam duplicated no_lead archived]).count,
      average_score: open_deals.average(:score_total)&.round(1) || 0,
      deals_by_legal_area: open_deals.group(:legal_area).count,
      deals_by_urgency: open_deals.group(:urgency_level).count,
      deals_by_source: deals.group(:source).count,
      deals_by_operational_status: deals.group(:operational_status).count,
      deals_by_stage: serialize_stage_breakdown(open_deals),
      activities_by_priority: activities.pending.group(:priority).count,
      filters: permitted_filters.to_h
    }
  end

  private

  def filtered_deals(scope)
    filters = permitted_filters
    scope = scope.where(crm_pipeline_id: filters[:pipeline_id]) if filters[:pipeline_id].present?
    scope = scope.where(crm_pipeline_stage_id: filters[:stage_id]) if filters[:stage_id].present?
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(legal_area: filters[:legal_area]) if filters[:legal_area].present?
    scope = scope.where(urgency_level: filters[:urgency_level]) if filters[:urgency_level].present?
    scope = scope.where(owner_id: filters[:owner_id]) if filters[:owner_id].present?
    scope = scope.where(assignee_id: filters[:assignee_id]) if filters[:assignee_id].present?
    scope = scope.where(source: filters[:source]) if filters[:source].present?
    scope = scope.where(operational_status: filters[:operational_status]) if filters[:operational_status].present?
    scope = scope.where('created_at >= ?', parsed_time(filters[:from])) if filters[:from].present?
    scope = scope.where('created_at <= ?', parsed_time(filters[:to])&.end_of_day) if filters[:to].present?
    scope
  end

  def filtered_activities(scope)
    filters = permitted_filters
    scope = scope.where(crm_deal_id: filtered_deals(Current.account.crm_deals).select(:id))
    scope = scope.where(owner_id: filters[:owner_id]) if filters[:owner_id].present?
    scope = scope.where(assignee_id: filters[:assignee_id]) if filters[:assignee_id].present?
    scope
  end

  def serialize_stage_breakdown(scope)
    stages = Current.account.crm_pipeline_stages.where(id: scope.select(:crm_pipeline_stage_id))
    counts = scope.group(:crm_pipeline_stage_id).count

    stages.index_by(&:id).transform_values do |stage|
      {
        name: stage.name,
        slug: stage.slug,
        count: counts[stage.id] || 0
      }
    end
  end

  def parsed_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def permitted_filters
    params.permit(:pipeline_id, :stage_id, :status, :legal_area, :urgency_level,
                  :owner_id, :assignee_id, :source, :operational_status, :from, :to)
  end
end
