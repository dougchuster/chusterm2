class Api::V1::Accounts::CampaignsController < Api::V1::Accounts::BaseController
  before_action :campaign, except: [:index, :create, :audience_count, :audience_preview]
  before_action :check_authorization

  def index
    @campaigns = Current.account.campaigns
  end

  def show; end

  def create
    @campaign = Current.account.campaigns.create!(campaign_params)
  end

  def audience_count
    render json: Campaigns::AudienceResolver.new(Current.account, params[:audience] || [], Current.user).summary
  end

  def audience_preview
    render json: Campaigns::AudienceResolver.new(Current.account, params[:audience] || [], Current.user).preview
  end

  def update
    @campaign.update!(campaign_params)
  end

  def destroy
    @campaign.destroy!
    head :ok
  end

  def track_event
    event = Campaigns::DeliveryTracker.new(@campaign).record!(
      campaign_event_params[:event_type],
      contact: campaign_event_contact,
      conversation: campaign_event_conversation,
      message: campaign_event_message,
      provider: campaign_event_params[:provider],
      external_id: campaign_event_params[:external_id],
      metadata: campaign_event_params[:metadata] || {}
    )

    render json: {
      event_id: event.respond_to?(:id) ? event.id : nil,
      delivery_stats: @campaign.reload.scoring_config['delivery_stats'] || {}
    }
  end

  private

  def campaign
    @campaign ||= Current.account.campaigns.find_by(display_id: params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:title, :description, :message, :enabled, :trigger_only_during_business_hours, :inbox_id, :sender_id,
                                     :scheduled_at, audience: [:type, :id, :name], trigger_rules: {}, template_params: {}, scoring_config: {})
  end

  def campaign_event_params
    params.permit(:event_type, :contact_id, :conversation_id, :message_id, :provider, :external_id, metadata: {})
  end

  def campaign_event_contact
    return if campaign_event_params[:contact_id].blank?

    Current.account.contacts.find(campaign_event_params[:contact_id])
  end

  def campaign_event_conversation
    return if campaign_event_params[:conversation_id].blank?

    Current.account.conversations.find(campaign_event_params[:conversation_id])
  end

  def campaign_event_message
    return if campaign_event_params[:message_id].blank?

    Current.account.messages.find(campaign_event_params[:message_id])
  end
end
