class CreateCaptainFlowEdges < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_flow_edges do |t|
      t.references :account, null: false, foreign_key: true
      t.references :captain_flow, null: false, foreign_key: true
      t.string :edge_id, null: false
      t.string :source_node_id, null: false
      t.string :target_node_id, null: false
      t.string :label
      t.jsonb :condition, null: false, default: {}

      t.timestamps
    end

    add_index :captain_flow_edges, [:captain_flow_id, :edge_id], unique: true
    add_index :captain_flow_edges, [:captain_flow_id, :source_node_id]
  end
end
