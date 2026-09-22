# Garante a gaveta do cliente com as pastas do modelo (PROJETO-COFRE-DOCUMENTOS.md
# §5.2). Cria só o que falta, identificando cada pasta pelo `slot` — se a equipe
# renomeou "01 Documentos Pessoais", a pasta continua sendo a de `pessoais`.
class Crm::Documents::DrawerProvisioner
  def initialize(contact)
    @contact = contact
    @account = contact.account
  end

  # Devolve as pastas raiz ativas, na ordem do modelo.
  def ensure!
    Crm::Documents::Defaults.ensure!(@account)
    template = @account.crm_document_folder_templates.client_scope.first
    template.nodes.each_with_index { |node, index| ensure_folder(node, index, parent: nil) }
    roots
  end

  def folder_for_slot(slot)
    ensure! if roots.none? { |folder| folder.slot == slot }
    roots.find { |folder| folder.slot == slot }
  end

  private

  def roots
    CrmDocumentFolder.active.roots.where(account_id: @account.id, contact_id: @contact.id).ordered.to_a
  end

  def ensure_folder(node, index, parent:)
    scope = CrmDocumentFolder.active.where(account_id: @account.id, contact_id: @contact.id, parent_id: parent&.id)
    scope.find_by(slot: node['slot']) || create_folder(scope, node, index, parent)
  end

  def create_folder(scope, node, index, parent)
    CrmDocumentFolder.transaction(requires_new: true) do
      CrmDocumentFolder.create!(
        account: @account, contact: @contact, parent: parent, name: node['name'],
        slot: node['slot'], kind: 'system', position: index
      )
    end
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Corrida com outra requisição, ou a equipe criou uma pasta comum com o
    # mesmo nome: reaproveita a existente em vez de falhar.
    scope.find_by(slot: node['slot']) || scope.where('lower(name) = ?', node['name'].downcase).first!
  end
end
