class CrmAuditEventPolicy < ApplicationPolicy
  def index?
    account_user.present?
  end
end
