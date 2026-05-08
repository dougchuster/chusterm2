class Platform::Api::V1::AccountUsersController < PlatformController
  before_action :set_resource
  before_action :validate_platform_app_permissible

  def index
    render json: @resource.account_users
  end

  def create
    @account_user = @resource.account_users.find_or_initialize_by(user_id: account_user_id)
    @account_user.update!(account_user_attributes)
    render json: @account_user
  end

  def destroy
    @resource.account_users.find_by(user_id: account_user_id)&.destroy!
    head :ok
  end

  private

  def set_resource
    @resource = Account.find(params[:account_id])
  end

  def account_user_id
    params.require(:user_id)
  end

  def account_user_attributes
    role = params[:role].to_s
    raise ActionController::BadRequest, 'Invalid role' if role.present? && AccountUser.roles.exclude?(role)

    role.present? ? { role: role } : {}
  end
end
