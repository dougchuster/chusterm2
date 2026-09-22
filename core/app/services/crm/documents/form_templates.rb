# Formulário inicial de cada modelo de documentos (`default_form` no preset;
# modelos sem um próprio usam o do Geral). É só o ponto de partida: a conta
# edita campos, documentos e textos pela tela.
module Crm::Documents::FormTemplates
  module_function

  def default_attributes(account)
    template = Crm::Documents::Defaults.config(account)['default_form'] ||
               Crm::Documents::Presets.fetch(Crm::Documents::Presets::DEFAULT)['default_form']
    known = account.crm_document_types.pluck(:slug)
    {
      name: template['name'], settings: template['settings'].to_h, fields: template['fields'].to_a,
      document_items: template['document_items'].to_a.map { |item| drop_unknown_type(item, known) }
    }
  end

  def drop_unknown_type(item, known)
    item['doc_type'].present? && known.exclude?(item['doc_type']) ? item.except('doc_type') : item
  end
end
