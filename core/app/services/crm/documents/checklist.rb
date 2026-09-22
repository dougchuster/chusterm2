# "X de Y" de um negócio (PROJETO-COFRE-DOCUMENTOS.md §8.6). Parte do checklist
# do tipo de caso (crm_checklist_templates, itens `kind: document`) e marca
# cada item pelos documentos do cliente — sem ninguém reler a conversa.
#
# - Documento pessoal (RG, comprovante) vale para qualquer processo do cliente;
#   documento de processo (CNIS, laudo) só vale se for deste negócio.
# - Rejeitado não conta. Aprovado aparece como aprovado.
# - A equipe pode escolher outro checklist e marcar item "entregue em papel".
#   Os dois ficam em crm_deals.custom_fields['documents_checklist'].
class Crm::Documents::Checklist
  STORE_KEY = 'documents_checklist'.freeze
  DOCUMENT_KIND = 'document'.freeze
  STATUS_RANK = { 'approved' => 3, 'received' => 2, 'obsolete' => 1, 'rejected' => 0 }.freeze

  def initialize(deal)
    @deal = deal
    @account = deal.account
  end

  def call
    items = template ? document_items.map { |item| evaluate(item) } : []
    { template_id: template&.id, template_name: template&.name, templates: available_templates, items: items }
      .merge(counts(items))
  end

  def choose_template!(template_id)
    chosen = template_id.present? ? @account.crm_checklist_templates.active.find(template_id).id : nil
    store!('template_id' => chosen)
  end

  def mark!(key, done:)
    marks = Array(stored['marks']) - [key.to_s]
    store!('marks' => done ? marks + [key.to_s] : marks)
  end

  private

  def template
    return @template if defined?(@template)

    chosen = stored['template_id']
    @template = chosen ? @account.crm_checklist_templates.active.find_by(id: chosen) : nil
    @template ||= Crm::ApplyChecklistTemplate.best_template_for(@deal)
  end

  def document_items
    template.items.select { |item| item['kind'].to_s == DOCUMENT_KIND }
  end

  def evaluate(item)
    key = item['key'].to_s
    types = Crm::Documents::ChecklistMatcher.new(@account).types_for(item)
    document = best_document(types)
    { key: key, title: item['title'], required: item['required'] == true, doc_types: types, status: status_for(key, document),
      document_id: document&.id }
  end

  def status_for(key, document)
    return 'manual' if Array(stored['marks']).include?(key)
    return 'missing' if document.nil?

    document.status == 'obsolete' ? 'received' : document.status
  end

  def counts(items)
    required = items.select { |item| item[:required] }
    { total: items.size, done: items.count { |item| done?(item) },
      required_total: required.size, required_done: required.count { |item| done?(item) } }
  end

  def best_document(types)
    candidates.select { |doc| types.include?(doc.doc_type) && eligible?(doc) }
              .max_by { |doc| [STATUS_RANK.fetch(doc.status, 0), doc.created_at] }
  end

  def eligible?(document)
    return true unless case_types.include?(document.doc_type)

    document.crm_deal_id == @deal.id
  end

  def candidates
    @candidates ||= CrmDocument.active.where(account_id: @account.id, contact_id: @deal.contact_id)
                               .where.not(doc_type: nil).to_a
  end

  def case_types
    @case_types ||= @account.crm_document_types.select(&:case_folder_target?).map(&:slug)
  end

  def done?(item)
    %w[received approved manual].include?(item[:status])
  end

  def available_templates
    @account.crm_checklist_templates.active.ordered.map { |t| { id: t.id, name: t.name } }
  end

  def stored
    (@deal.custom_fields || {}).fetch(STORE_KEY, {}) || {}
  end

  def store!(changes)
    fields = (@deal.custom_fields || {}).merge(STORE_KEY => stored.merge(changes))
    @deal.update!(custom_fields: fields)
    remove_instance_variable(:@template) if defined?(@template)
  end
end
