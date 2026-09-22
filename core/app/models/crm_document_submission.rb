# Um envio feito pelo formulário: protocolo, respostas e resultado da
# identificação do contato (PROJETO-COFRE-DOCUMENTOS.md §4.8).
class CrmDocumentSubmission < ApplicationRecord
  MATCH_STATUSES = %w[link matched_phone matched_email new_contact].freeze
  REVIEW_STATUSES = %w[new done spam].freeze

  belongs_to :account
  belongs_to :crm_document_form, optional: true
  belongs_to :crm_document_form_link, optional: true
  belongs_to :contact, optional: true
  belongs_to :crm_deal, optional: true
  belongs_to :reviewed_by_user, class_name: 'User', optional: true

  validates :protocol, presence: true, uniqueness: { scope: :account_id }
  validates :match_status, inclusion: { in: MATCH_STATUSES }
  validates :review_status, inclusion: { in: REVIEW_STATUSES }

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def documents
    CrmDocument.where(account_id: account_id).where("meta->>'submission_id' = ?", id.to_s)
  end
end
