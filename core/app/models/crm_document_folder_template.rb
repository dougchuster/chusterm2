# Modelo de estrutura de pastas (PROJETO-COFRE-DOCUMENTOS.md §4.4). `client` é
# a raiz da gaveta; `case` são as subpastas de cada processo, por área.
class CrmDocumentFolderTemplate < ApplicationRecord
  SCOPES = %w[client case].freeze
  # A captura, os negócios e o descarte dependem destas pastas na gaveta.
  REQUIRED_CLIENT_SLOTS = %w[triagem processos arquivo].freeze

  belongs_to :account

  validates :name, :legal_area, presence: true
  validates :scope, inclusion: { in: SCOPES }
  validates :legal_area, uniqueness: { scope: %i[account_id scope] }
  validate :tree_shape
  validate :required_client_slots

  scope :client_scope, -> { where(scope: 'client') }
  scope :case_scope, -> { where(scope: 'case') }

  # [{ 'slot' => 'pessoais', 'name' => '01 Documentos Pessoais' }, ...]
  def nodes
    Array(tree).map { |node| node.to_h.stringify_keys.slice('slot', 'name') }
  end

  private

  def required_client_slots
    return unless scope == 'client' && tree.is_a?(Array)

    missing = REQUIRED_CLIENT_SLOTS - nodes.pluck('slot')
    errors.add(:tree, "precisa manter as pastas do sistema (#{missing.join(', ')})") if missing.any?
  end

  def tree_shape
    valid = tree.is_a?(Array) && tree.all? { |node| node.is_a?(Hash) && node['name'].present? && node['slot'].present? }
    errors.add(:tree, 'precisa ser uma lista de pastas com slot e nome') unless valid
  end
end
