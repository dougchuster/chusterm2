class Api::V1::Accounts::Marketing::LeadsController < Api::V1::Accounts::BaseController
  before_action :check_feature_flag
  before_action :set_lead, only: [:show, :discard, :convert]

  def index
    leads = filtered_leads.limit(200)
    render json: {
      leads: leads.map { |lead| serialize_lead(lead) },
      counts: status_counts
    }
  end

  def show
    render json: { lead: serialize_lead(@lead, detailed: true) }
  end

  def discard
    @lead.update!(status: 'discarded')
    render json: { lead: serialize_lead(@lead) }
  end

  def convert
    return render json: { error: 'already_converted' }, status: :unprocessable_entity if @lead.crm_deal_id.present?

    Marketing::LeadToCrmService.new(
      account: Current.account,
      connection: @lead.crm_external_connection,
      leadgen_id: @lead.leadgen_id,
      fields: @lead.field_data.merge('_meta' => @lead.metadata || {}),
      context: {}
    ).perform
    render json: { lead: serialize_lead(@lead.reload) }
  end

  private

  def check_feature_flag
    render json: { error: 'feature_disabled' }, status: :forbidden unless Current.account.feature_enabled?('marketing')
  end

  def set_lead
    @lead = Current.account.marketing_leads.find(params[:id])
  end

  def filtered_leads
    scope = Current.account.marketing_leads.recent_first
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(campaign_id: params[:campaign_id]) if params[:campaign_id].present?
    scope
  end

  def status_counts
    Current.account.marketing_leads.group(:status).count
  end

  def serialize_lead(lead, detailed: false)
    payload = {
      id: lead.id,
      leadgen_id: lead.leadgen_id,
      display_name: lead.display_name,
      email: lead.email,
      phone: lead.phone,
      status: lead.status,
      form_id: lead.form_id,
      campaign_id: lead.campaign_id,
      campaign_name: campaign_name(lead),
      platform: lead.platform,
      contact_id: lead.contact_id,
      crm_deal_id: lead.crm_deal_id,
      converted_at: lead.converted_at,
      created_at: lead.created_at
    }
    payload[:field_data] = lead.field_data if detailed
    payload
  end

  def campaign_name(lead)
    return if lead.campaign_id.blank?

    @campaign_names ||= Current.account.marketing_campaigns.pluck(:external_id, :name).to_h
    @campaign_names[lead.campaign_id]
  end
end
