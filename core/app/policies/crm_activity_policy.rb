class CrmActivityPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def complete?
    true
  end

  def snooze?
    update?
  end

  def destroy?
    update?
  end
end
