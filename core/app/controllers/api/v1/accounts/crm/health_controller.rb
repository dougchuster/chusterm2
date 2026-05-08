class Api::V1::Accounts::Crm::HealthController < Api::V1::Accounts::Crm::BaseController
  def show
    authorize CrmDeal, :index?

    render json: Crm::HealthCheckService.new(account: Current.account).perform
  end
end
