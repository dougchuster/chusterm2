class Api::V1::Accounts::Crm::BaseController < Api::V1::Accounts::BaseController
  before_action :check_crm_authorization

  private

  def check_crm_authorization
    access_denied unless current_account_user
  end

  def current_account_user
    @current_account_user ||= Current.account_user
  end

  def administrator?
    current_account_user&.administrator?
  end
end
