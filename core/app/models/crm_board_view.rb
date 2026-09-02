# F2.7 do PLANO-KANBAN-CRM-2026.md — uma visao salva do board.
#
# Lacuna K-05: sem isso, cada atendente remonta o mesmo filtro todo dia. A
# decisao de produto que a tabela carrega e **minha ou da equipe**: compartilhar
# muda quem enxerga e quem pode apagar, e por isso e coluna e nao convencao.
class CrmBoardView < ApplicationRecord
  include AccountAssociationScoped

  GROUP_BY_OPTIONS = %w[stage owner score_band legal_area source operational_status].freeze

  belongs_to :account
  belongs_to :user

  validates :name, presence: true, length: { maximum: 120 }
  validates :name,
            uniqueness: {
              scope: [:account_id, :user_id]
              # `:taken` e a chave padrao do Rails, ja traduzida.
            }
  validates :group_by, inclusion: { in: GROUP_BY_OPTIONS }

  before_validation :place_at_the_end, on: :create

  scope :ordered, -> { order(:position, :id) }
  scope :shared, -> { where(is_shared: true) }

  # Minhas visoes mais o que a equipe compartilhou — nunca a visao privada de
  # outra pessoa, e nunca nada de outra conta.
  scope :visible_to, lambda { |user|
    where(account_id: user.account_ids)
      .where('crm_board_views.user_id = :id OR crm_board_views.is_shared = TRUE', id: user.id)
  }

  def editable_by?(candidate)
    user_id == candidate&.id
  end

  private

  # Visao nova entra no fim do menu. Cair no meio da lista de alguem seria
  # reordenar o trabalho do atendente sem ele pedir.
  def place_at_the_end
    return if position.to_i.positive?

    self.position = (account&.crm_board_views&.maximum(:position) || 0) + 1
  end
end
