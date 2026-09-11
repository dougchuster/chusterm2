class CrmAuditEventPolicy < ApplicationPolicy
  # A trilha de auditoria carrega diffs antes/depois (inclusive campos LGPD),
  # então a leitura é restrita a administradores.
  def index?
    administrator?
  end

  def show?
    administrator?
  end

  private

  def administrator?
    account_user&.administrator?
  end
end
