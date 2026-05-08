class Api::V1::Integrations::WebhooksController < ApplicationController
  def create
    builder = Integrations::Slack::IncomingMessageBuilder.new(permitted_params)
    response = builder.perform
    render json: response
  end

  private

  def permitted_params
    params.permit(
      :api_app_id, :challenge, :event_id, :event_time, :team_id, :token, :type,
      event: [
        :bot_id, :channel, :client_msg_id, :event_ts, :hidden, :subtype, :text, :thread_ts, :ts,
        :type, :user,
        { blocks: {}, files: {}, links: [] }
      ]
    )
  end
end
