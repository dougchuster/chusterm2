class CrmDealPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    administrator?
  end

  def move?
    true
  end

  def mark_won?
    true
  end

  def mark_lost?
    true
  end

  def reopen?
    administrator_or_agent?
  end

  def export?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end

  def administrator_or_agent?
    administrator? || account_user&.role == 'agent'
  end
end
