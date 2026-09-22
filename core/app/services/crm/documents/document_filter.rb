# Filtros da listagem de documentos de um contato: pasta, processo, situação,
# tipo, busca textual e arquivados.
class Crm::Documents::DocumentFilter
  BOOLEAN = ActiveModel::Type::Boolean.new

  def initialize(contact:, params:)
    @contact = contact
    @params = params
  end

  def scope
    records = CrmDocument.where(account_id: @contact.account_id, contact_id: @contact.id)
    records = BOOLEAN.cast(@params[:archived]) ? records.archived : records.active
    records = filter_equal(records)
    records = search(records, @params[:q]) if @params[:q].present?
    records.ordered
  end

  private

  def filter_equal(records)
    records = records.where(crm_document_folder_id: @params[:folder_id]) if @params[:folder_id].present?
    records = records.where(crm_deal_id: @params[:deal_id]) if @params[:deal_id].present?
    records = records.where(status: @params[:status]) if CrmDocument::STATUSES.include?(@params[:status])
    records = records.where(doc_type: @params[:doc_type]) if @params[:doc_type].present?
    records
  end

  def search(records, term)
    like = "%#{ActiveRecord::Base.sanitize_sql_like(term.to_s.strip)}%"
    records.where('file_name ILIKE :like OR description ILIKE :like OR original_filename ILIKE :like', like: like)
  end
end
