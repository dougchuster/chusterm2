# frozen_string_literal: true

# Tipo de atividade disponível na conta — instalado por pack ou definido pela
# conta. Em modo universal a validação de CrmActivity#kind consulta esta
# tabela; os KINDS legados continuam aceitos para não invalidar dados
# existentes.
class CrmActivityType < ApplicationRecord
  include AccountAssociationScoped

  belongs_to :account

  validates :key, presence: true, uniqueness: { scope: :account_id }
  validates :label, presence: true

  scope :active, -> { where(active: true).order(position: :asc) }
end
