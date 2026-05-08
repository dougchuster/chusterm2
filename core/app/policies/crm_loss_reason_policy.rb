class CrmLossReasonPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    administrator?
  end

  def update?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
