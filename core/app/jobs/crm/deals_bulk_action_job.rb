# B14: `select_all` sobre o filtro do board pode abranger milhares de deals —
# roda fora do request. O controller mantém a execução síncrona apenas para
# lotes pequenos com `deal_ids` explícitos.
class Crm::DealsBulkActionJob < ApplicationJob
  queue_as :medium

  def perform(account_id:, user_id:, action:, filters: {}, params: {})
    account = Account.find(account_id)
    user = account.users.find(user_id)

    scope = account.crm_deals.visible_to(user, account)
    scope = scope.where(id: params[:deal_ids]) if params[:deal_ids].present?
    scope = Crm::DealFilterService.new(scope: scope, filters: filters, account: account).perform

    result = Crm::DealsBulkAction.new(account: account, user: user, action: action, params: params).perform(scope)

    Rails.logger.info(
      "[CRM BulkAction] account=#{account.id} action=#{action} " \
      "requested=#{result[:requested]} processed=#{result[:processed]} failed=#{result[:failed].size}"
    )
  end
end
