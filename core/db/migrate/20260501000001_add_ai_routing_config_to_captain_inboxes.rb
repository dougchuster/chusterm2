class AddAiRoutingConfigToCaptainInboxes < ActiveRecord::Migration[7.0]
  def change
    add_column :captain_inboxes, :enabled, :boolean, null: false, default: true
    add_column :captain_inboxes, :auto_reply_enabled, :boolean, null: false, default: true
    add_column :captain_inboxes, :ai_mode, :string, null: false, default: 'auto'
    add_column :captain_inboxes, :handoff_strategy, :string, null: false, default: 'human_request_or_score'
    add_column :captain_inboxes, :routing_config, :jsonb, null: false, default: {}

    add_index :captain_inboxes, :enabled
    add_index :captain_inboxes, :ai_mode
  end
end
