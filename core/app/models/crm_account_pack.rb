# frozen_string_literal: true

# Registra um pack vertical instalado na conta (legal, sales_default, ...).
# A presença/ausência de packs define a taxonomia exposta ao usuário:
# conta sem pack legal nunca vê terminologia jurídica.
class CrmAccountPack < ApplicationRecord
  include AccountAssociationScoped

  belongs_to :account

  validates :slug, presence: true, uniqueness: { scope: :account_id }

  scope :installed, -> { order(installed_at: :asc) }
end
