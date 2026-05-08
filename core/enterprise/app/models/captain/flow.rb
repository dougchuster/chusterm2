class Captain::Flow < ApplicationRecord
  STATUSES = %w[draft published archived].freeze
  NODE_TYPES = %w[start message question condition score crm_action handoff end].freeze

  self.table_name = 'captain_flows'

  belongs_to :account
  belongs_to :captain_assistant, class_name: 'Captain::Assistant', optional: true
  has_many :flow_nodes, class_name: 'Captain::FlowNode', foreign_key: :captain_flow_id, dependent: :destroy
  has_many :flow_edges, class_name: 'Captain::FlowEdge', foreign_key: :captain_flow_id, dependent: :destroy

  validates :name, :slug, :account_id, presence: true
  validates :slug, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where.not(status: 'archived') }
  scope :published, -> { where(status: 'published') }
  scope :ordered, -> { order(created_at: :desc) }
  scope :for_account, ->(account_id) { where(account_id: account_id) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  def publish!
    raise ActiveRecord::RecordInvalid, self if flow_nodes.none?

    update!(status: 'published', published_at: Time.current, version: version + 1)
  end

  def save_graph!(nodes:, edges:, actor: nil)
    ActiveRecord::Base.transaction do
      flow_nodes.destroy_all
      flow_edges.destroy_all

      nodes.each { |n| flow_nodes.create!(n.merge(account: account)) }
      edges.each { |e| flow_edges.create!(e.merge(account: account)) }
    end
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
