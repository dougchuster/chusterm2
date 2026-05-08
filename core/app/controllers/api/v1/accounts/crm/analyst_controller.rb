class Api::V1::Accounts::Crm::AnalystController < Api::V1::Accounts::Crm::BaseController
  def create
    render json: Crm::AnalystService.new(
      account: Current.account,
      question: params[:question],
      period_days: params[:period_days]
    ).perform
  end
end
