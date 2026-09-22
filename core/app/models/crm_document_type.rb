# Catálogo de tipos de documento da conta (PROJETO-COFRE-DOCUMENTOS.md §5.4).
# `target_slot` aponta para o papel da pasta de destino, nunca para o nome.
class CrmDocumentType < ApplicationRecord
  CURRENT_FOLDER_SLOT = 'current'.freeze

  belongs_to :account

  validates :slug, presence: true, format: { with: /\A[a-z0-9_]+\z/ }, uniqueness: { scope: :account_id }
  validates :label, :target_slot, presence: true
  validates :validity_days, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :label) }

  def case_folder_target?
    target_slot.start_with?('processo_')
  end
end
