class Api::V1::Accounts::Captain::InboxesController < Api::V1::Accounts::BaseController
  before_action :current_account
  before_action -> { check_authorization(Captain::Assistant) }

  before_action :set_assistant
  def index
    @captain_inboxes = @assistant.captain_inboxes.includes(:inbox)
  end

  def create
    inbox = Current.account.inboxes.find(assistant_params[:inbox_id])
    @captain_inbox = CaptainInbox.find_or_initialize_by(inbox: inbox)
    @captain_inbox.update!(assistant_params.except(:inbox_id).merge(captain_assistant: @assistant))
  end

  def update
    @captain_inbox = @assistant.captain_inboxes.find_by!(inbox_id: permitted_params[:inbox_id])
    @captain_inbox.update!(assistant_params.except(:inbox_id))
  end

  def destroy
    @captain_inbox = @assistant.captain_inboxes.find_by!(inbox_id: permitted_params[:inbox_id])
    @captain_inbox.destroy!
    head :no_content
  end

  private

  def set_assistant
    @assistant = account_assistants.find(permitted_params[:assistant_id])
  end

  def account_assistants
    @account_assistants ||= Current.account.captain_assistants
  end

  def permitted_params
    params.permit(:assistant_id, :id, :inbox_id)
  end

  def assistant_params
    params.require(:inbox).permit(:inbox_id, :enabled, :auto_reply_enabled, :ai_mode, :handoff_strategy, routing_config: {})
  end
end
