class AddCaptainRoutingToCampaigns < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :captain_flow_id, :bigint
    add_column :campaigns, :captain_assistant_id, :bigint
    add_index :campaigns, :captain_flow_id
    add_index :campaigns, :captain_assistant_id
    add_foreign_key :campaigns, :captain_flows, column: :captain_flow_id
    add_foreign_key :campaigns, :captain_assistants, column: :captain_assistant_id
  end
end
