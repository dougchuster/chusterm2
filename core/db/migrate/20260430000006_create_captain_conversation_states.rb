class CreateCaptainConversationStates < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_conversation_states do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true, index: { unique: true }
      t.references :contact, foreign_key: true
      t.references :captain_assistant, foreign_key: { to_table: :captain_assistants }
      t.bigint :crm_deal_id
      t.string :ai_mode, null: false, default: 'auto'
      t.text :handoff_reason
      t.datetime :handoff_at
      t.bigint :handoff_by_id
      t.integer :score_total, null: false, default: 0
      t.string :score_classification
      t.jsonb :score_payload, null: false, default: {}
      t.text :context_summary
      t.string :current_node_id
      t.datetime :last_ai_message_at

      t.timestamps
    end

    add_index :captain_conversation_states, :ai_mode
    add_index :captain_conversation_states, :crm_deal_id
    add_index :captain_conversation_states, :handoff_by_id
    add_foreign_key :captain_conversation_states, :users, column: :handoff_by_id
  end
end
