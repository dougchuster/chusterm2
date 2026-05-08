class AddCaptainFlowToCaptainConversationStates < ActiveRecord::Migration[7.1]
  def change
    add_column :captain_conversation_states, :captain_flow_id, :bigint
    add_index :captain_conversation_states, :captain_flow_id
    add_foreign_key :captain_conversation_states, :captain_flows, column: :captain_flow_id
  end
end
