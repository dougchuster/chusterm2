# Documento do cofre (PROJETO-COFRE-DOCUMENTOS.md §4.2). Pertence sempre ao
# contato; o negócio é referência opcional. O nome físico (`file_name`) é
# derivado pela nomenclatura e só deixa de ser recalculado quando a equipe
# renomeia à mão (`name_locked`).
class CrmDocument < ApplicationRecord
  SOURCES = %w[whatsapp email instagram chat upload portal system].freeze
  STATUSES = %w[received approved rejected obsolete].freeze
  DEFAULT_TIME_ZONE = 'America/Sao_Paulo'.freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :crm_document_folder, optional: true
  belongs_to :crm_deal, optional: true
  belongs_to :uploaded_by_user, class_name: 'User', optional: true
  # Mensagem de origem (captura automática). Sem FK: a mensagem pode ser
  # apagada e o documento continua — a cópia do arquivo é própria.
  belongs_to :source_message, class_name: 'Message', optional: true

  has_one_attached :file

  before_validation :assign_file_name
  before_validation :assign_expiry

  validates :source, inclusion: { in: SOURCES }
  validates :status, inclusion: { in: STATUSES }
  validates :file_name, presence: true
  validates :description, length: { maximum: 200 }
  validates :review_note, presence: true, if: -> { status == 'rejected' }
  validate :doc_type_in_catalog
  validate :folder_belongs_to_contact
  validate :deal_belongs_to_account

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(created_at: :desc, id: :desc) }

  def document_type
    return if doc_type.blank? || account.nil?

    @document_type = nil if @document_type && @document_type.slug != doc_type
    @document_type ||= account.crm_document_types.find_by(slug: doc_type)
  end

  def received_at
    created_at || Time.current
  end

  def time_zone
    ActiveSupport::TimeZone[account&.reporting_timezone.presence || DEFAULT_TIME_ZONE] || Time.zone
  end

  def archived?
    archived_at.present?
  end

  def in_triage?
    doc_type.blank?
  end

  private

  def assign_file_name
    return if name_locked? && file_name.present?
    return if account.nil?

    self.file_name = Crm::Documents::Naming::FileNamer.call(self)
  end

  # Validade pelo catálogo (certidão 90 dias, CNIS 30): conta da data do
  # documento ou do recebimento. Data informada à mão não é sobrescrita.
  def assign_expiry
    return if will_save_change_to_expires_on? || !expiry_inputs_changed?

    days = document_type&.validity_days
    self.expires_on = days ? (document_date || received_at.in_time_zone(time_zone).to_date) + days : nil
  end

  def expiry_inputs_changed?
    new_record? || will_save_change_to_doc_type? || will_save_change_to_document_date?
  end

  def doc_type_in_catalog
    return if doc_type.blank? || document_type.present?

    errors.add(:doc_type, 'não existe no catálogo de tipos da conta')
  end

  def folder_belongs_to_contact
    return if crm_document_folder.nil?
    return if crm_document_folder.contact_id == contact_id && crm_document_folder.account_id == account_id

    errors.add(:crm_document_folder, 'não pertence a este contato')
  end

  def deal_belongs_to_account
    return if crm_deal.nil? || crm_deal.account_id == account_id

    errors.add(:crm_deal, 'não pertence a esta conta')
  end
end
