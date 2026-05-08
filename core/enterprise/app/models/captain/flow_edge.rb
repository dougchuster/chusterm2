class Captain::FlowEdge < ApplicationRecord
  self.table_name = 'captain_flow_edges'

  belongs_to :account
  belongs_to :captain_flow, class_name: 'Captain::Flow'

  validates :edge_id, :source_node_id, :target_node_id, :captain_flow_id, :account_id, presence: true
  validates :edge_id, uniqueness: { scope: :captain_flow_id }
end
