class Captain::FlowNode < ApplicationRecord
  self.table_name = 'captain_flow_nodes'

  belongs_to :account
  belongs_to :captain_flow, class_name: 'Captain::Flow'

  validates :node_id, :node_type, :captain_flow_id, :account_id, presence: true
  validates :node_id, uniqueness: { scope: :captain_flow_id }
  validates :node_type, inclusion: { in: Captain::Flow::NODE_TYPES }
end
