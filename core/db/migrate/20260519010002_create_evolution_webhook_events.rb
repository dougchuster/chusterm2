class CreateEvolutionWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :evolution_webhook_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: true, foreign_key: true
      t.references :evolution_instance, null: true, foreign_key: true
      t.string :event_name, null: false
      t.string :instance_name
      t.string :message_id
      t.string :event_uid
      t.string :status, null: false, default: 'received'
      t.jsonb :payload, null: false, default: {}
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :evolution_webhook_events, :event_name
    add_index :evolution_webhook_events, :status
    add_index :evolution_webhook_events, [:evolution_instance_id, :event_uid],
              unique: true,
              where: 'event_uid IS NOT NULL',
              name: 'idx_evo_webhook_events_on_instance_event_uid'
    add_index :evolution_webhook_events, [:evolution_instance_id, :message_id, :event_name],
              name: 'idx_evo_events_instance_message_event'
  end
end
