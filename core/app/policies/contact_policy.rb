class ContactPolicy < ApplicationPolicy
  def index?
    true
  end

  def active?
    true
  end

  def import?
    @account_user.administrator?
  end

  def imports?
    true
  end

  def export?
    @account_user.administrator?
  end

  def search?
    true
  end

  def filter?
    true
  end

  def update?
    true
  end

  def contactable_inboxes?
    true
  end

  def destroy_custom_attributes?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def avatar?
    true
  end

  def destroy?
    @account_user.administrator?
  end

  # CRM-045: exportar e apagar dados do titular são operações sensíveis —
  # restritas a administradores (mesmo nível de `destroy?`).
  def data_export?
    @account_user.administrator?
  end

  def data_erasure?
    @account_user.administrator?
  end
end
