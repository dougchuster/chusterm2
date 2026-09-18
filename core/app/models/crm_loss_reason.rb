class CrmLossReason < ApplicationRecord
  belongs_to :account

  # A tela crm/settings/loss-reasons manda só `name`; sem gerar o slug aqui o
  # create devolvia 422 "Slug can't be blank" e ninguém conseguia cadastrar
  # motivo pela UI (mesmo padrão de CrmPipeline/CrmPipelineStage).
  before_validation :ensure_slug

  validates :account, :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :account_id }

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(position: :asc) }

  private

  def ensure_slug
    return if slug.present? || name.blank?

    base_slug = name.parameterize.presence || 'motivo'
    candidate = base_slug
    suffix = 2

    while self.class.where(account_id: account_id, slug: candidate).where.not(id: id).exists?
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
