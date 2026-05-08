class CreateCaptainFlowNodes < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_flow_nodes do |t|
      t.references :account, null: false, foreign_key: true
      t.references :captain_flow, null: false, foreign_key: true
      t.string :node_id, null: false
      t.string :node_type, null: false
      t.decimal :position_x, precision: 10, scale: 2, default: 0
      t.decimal :position_y, precision: 10, scale: 2, default: 0
      t.jsonb :config, null: false, default: {}

      t.timestamps
    end

    add_index :captain_flow_nodes, [:captain_flow_id, :node_id], unique: true
    add_index :captain_flow_nodes, :node_type
  end
end
