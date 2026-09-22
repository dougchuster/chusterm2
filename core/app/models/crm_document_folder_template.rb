# Modelo de estrutura de pastas (PROJETO-COFRE-DOCUMENTOS.md §4.4). `client` é
# a raiz da gaveta; `case` são as subpastas de cada processo, por área.
class CrmDocumentFolderTemplate < ApplicationRecord
  SCOPES = %w[client case].freeze

  belongs_to :account

  validates :name, :legal_area, presence: true
  validates :scope, inclusion: { in: SCOPES }
  validates :legal_area, uniqueness: { scope: %i[account_id scope] }
  validate :tree_shape

  scope :client_scope, -> { where(scope: 'client') }
  scope :case_scope, -> { where(scope: 'case') }

  # [{ 'slot' => 'pessoais', 'name' => '01 Documentos Pessoais' }, ...]
  def nodes
    Array(tree).map { |node| node.to_h.stringify_keys.slice('slot', 'name') }
  end

  private

  def tree_shape
    valid = tree.is_a?(Array) && tree.all? { |node| node.is_a?(Hash) && node['name'].present? && node['slot'].present? }
    errors.add(:tree, 'precisa ser uma lista de pastas com slot e nome') unless valid
  end
end
