class CrmPipelineStage < ApplicationRecord
  include AccountAssociationScoped

  belongs_to :account
  belongs_to :crm_pipeline
  has_many :crm_deals, dependent: :restrict_with_error
  has_many :crm_automation_rules, dependent: :destroy

  before_validation :ensure_slug

  validates :account, :crm_pipeline, :name, :slug, presence: true
  validates_same_account_for :crm_pipeline
  validates :slug, uniqueness: { scope: :crm_pipeline_id }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(position: :asc) }

  def archive!
    update!(archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  private

  def ensure_slug
    return if slug.present? || name.blank?

    base_slug = name.parameterize.presence || 'etapa'
    candidate = base_slug
    suffix = 2

    while self.class.where(crm_pipeline_id: crm_pipeline_id, slug: candidate).where.not(id: id).exists?
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
