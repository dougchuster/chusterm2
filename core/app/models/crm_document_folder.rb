# Pasta da gaveta do cliente (PROJETO-COFRE-DOCUMENTOS.md §4.1). Pastas
# `system` vêm do modelo e não podem ser arquivadas; `slot` identifica o papel
# da pasta e sobrevive a renomeações (o roteamento por tipo usa o slot).
class CrmDocumentFolder < ApplicationRecord
  KINDS = %w[system custom].freeze
  MAX_DEPTH = 5
  NAME_MAX_LENGTH = 80

  belongs_to :account
  belongs_to :contact
  belongs_to :parent, class_name: 'CrmDocumentFolder', optional: true
  belongs_to :crm_deal, optional: true

  has_many :children, class_name: 'CrmDocumentFolder', foreign_key: :parent_id, inverse_of: :parent, dependent: nil
  has_many :crm_documents, dependent: nil

  before_validation :sanitize_name

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validate :parent_belongs_to_same_contact
  validate :parent_is_not_descendant
  validate :depth_within_limit
  validate :name_unique_among_siblings

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position, :name, :id) }
  scope :roots, -> { where(parent_id: nil) }

  def system?
    kind == 'system'
  end

  def archived?
    archived_at.present?
  end

  # Da raiz até a própria pasta. Limitado a MAX_DEPTH para nunca girar em
  # ciclo, mesmo com dado corrompido.
  def lineage
    chain = [self]
    chain.unshift(chain.first.parent) while chain.first.parent && chain.size <= MAX_DEPTH
    chain
  end

  def depth
    lineage.size
  end

  private

  def sanitize_name
    self.name = Crm::Documents::Naming::Sanitizer.call(name, max: NAME_MAX_LENGTH, fallback: '') if name
  end

  def parent_belongs_to_same_contact
    return if parent.nil?
    return if parent.contact_id == contact_id && parent.account_id == account_id

    errors.add(:parent, 'não pertence a este contato')
  end

  def parent_is_not_descendant
    return if parent.nil? || new_record?
    return unless parent.lineage.any? { |folder| folder.id == id }

    errors.add(:parent, 'não pode ser a própria pasta nem uma subpasta dela')
  end

  def depth_within_limit
    return if parent.nil? || parent.depth < MAX_DEPTH

    errors.add(:parent, "permite no máximo #{MAX_DEPTH} níveis")
  end

  def name_unique_among_siblings
    return if name.blank? || archived?

    siblings = self.class.active.where(account_id: account_id, contact_id: contact_id, parent_id: parent_id)
                   .where('lower(name) = ?', name.downcase)
    siblings = siblings.where.not(id: id) if persisted?
    errors.add(:name, 'já existe nesta pasta') if siblings.exists?
  end
end
