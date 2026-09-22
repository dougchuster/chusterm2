# Quais tipos de documento atendem um item de checklist: tipos declarados no
# item (`doc_types`), apelido do catálogo (rg_cpf → RG/CPF/CNH), slug igual à
# chave, ou — por último — o classificador aplicado ao título do item.
class Crm::Documents::ChecklistMatcher
  def initialize(account)
    @account = account
  end

  def types_for(item)
    declared = Array(item['doc_types']).map(&:to_s)
    return declared if declared.any?

    key = item['key'].to_s
    aliases = Crm::Documents::Defaults.config(@account).fetch('checklist_aliases', {}).to_h[key]
    return aliases if aliases.present?
    return [key] if slugs.include?(key)

    suggestion = classifier.suggest(caption: item['title'], filename: '')
    suggestion ? [suggestion] : []
  end

  private

  def slugs
    @slugs ||= @account.crm_document_types.pluck(:slug)
  end

  def classifier
    @classifier ||= Crm::Documents::Classifier.new(@account)
  end
end
