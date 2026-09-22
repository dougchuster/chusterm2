# Permissões por ação do cofre. O recorte por registro (qual contato o agente
# atende) fica em Crm::Documents::Access: fora dele o controller responde 404.
class CrmDocumentPolicy < ApplicationPolicy
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
    true
  end

  def restore?
    true
  end

  def download?
    true
  end

  # D4: apagar de vez (arquivo incluso) é só do administrador.
  def purge?
    account_user&.administrator?
  end
end
