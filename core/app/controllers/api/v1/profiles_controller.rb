class Api::V1::ProfilesController < Api::BaseController
  before_action :set_user

  def show; end

  def update
    if password_params[:password].present?
      render_could_not_create_error('Invalid current password') and return unless @user.valid_password?(password_params[:current_password])

      @user.update!(password_params.except(:current_password))
    end

    # A tela de perfil exige nome; a API aceitava '' e o usuário aparecia sem nome
    # na lista de agentes. O model não valida porque AgentBuilder cria convidados
    # sem nome de propósito — a regra vale para quem edita o próprio perfil.
    if profile_params.key?(:name) && profile_params[:name].blank?
      render_could_not_create_error(I18n.t('errors.validations.presence', default: 'Nome não pode ficar em branco')) and return
    end

    @user.assign_attributes(profile_params)
    @user.custom_attributes.merge!(custom_attributes_params)
    @user.save!
  end

  def avatar
    @user.avatar.attachment.destroy! if @user.avatar.attached?
    @user.reload
  end

  def auto_offline
    @user.account_users.find_by!(account_id: profile_account_id).update!(auto_offline: auto_offline_params[:auto_offline] || false)
  end

  def availability
    @user.account_users.find_by!(account_id: profile_account_id).update!(availability: availability_params[:availability])
  end

  def set_active_account
    @user.account_users.find_by!(account_id: profile_account_id).update!(active_at: Time.current)
    head :ok
  end

  def resend_confirmation
    @user.send_confirmation_instructions unless @user.confirmed?
    head :ok
  end

  def reset_access_token
    @user.access_token.regenerate_token
    @user.reload
  end

  private

  def set_user
    @user = current_user
  end

  def availability_params
    params.require(:profile).permit(:availability)
  end

  def auto_offline_params
    params.require(:profile).permit(:auto_offline)
  end

  def profile_params
    params.require(:profile).permit(
      :email,
      :name,
      :display_name,
      :avatar,
      :message_signature,
      ui_settings: {}
    )
  end

  def profile_account_id
    params.require(:profile).require(:account_id)
  end

  def custom_attributes_params
    params.require(:profile).permit(:phone_number)
  end

  def password_params
    params.require(:profile).permit(
      :current_password,
      :password,
      :password_confirmation
    )
  end
end
