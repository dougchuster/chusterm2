class CrmPipeline < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true
  has_many :crm_pipeline_stages, -> { order(position: :asc) }, dependent: :destroy
  has_many :crm_deals, dependent: :restrict_with_error

  before_validation :ensure_slug

  validates :account, :name, :slug, presence: true
  validates :slug, uniqueness: { scope: :account_id }
  validates :inbox_id, uniqueness: { scope: :account_id }, allow_nil: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :default_first, -> { order(is_default: :desc, position: :asc) }

  def archive!
    update!(archived_at: Time.current)
  end

  def restore!
    update!(archived_at: nil)
  end

  private

  def ensure_slug
    return if slug.present? || name.blank?

    base_slug = name.parameterize.presence || 'pipeline'
    candidate = base_slug
    suffix = 2

    while self.class.where(account_id: account_id, slug: candidate).where.not(id: id).exists?
      candidate = "#{base_slug}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end
end
