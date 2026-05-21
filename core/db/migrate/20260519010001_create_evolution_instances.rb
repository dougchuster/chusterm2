class CreateEvolutionInstances < ActiveRecord::Migration[7.1]
  def change
    create_table :evolution_instances do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: true, foreign_key: true
      t.references :channel_whatsapp, null: true, foreign_key: { to_table: :channel_whatsapp }
      t.references :evolution_api_configuration, null: false, foreign_key: true, index: { name: 'idx_evo_instances_on_configuration_id' }
      t.string :instance_name, null: false
      t.string :external_instance_id
      t.string :webhook_token, null: false
      t.string :connection_state, null: false, default: 'unknown'
      t.string :provisioning_status, null: false, default: 'pending'
      t.string :phone_number
      t.string :profile_name
      t.string :profile_picture_url
      t.text :latest_qr
      t.string :latest_qr_hash
      t.datetime :latest_qr_at
      t.datetime :last_connected_at
      t.datetime :last_disconnected_at
      t.datetime :last_sync_at
      t.integer :failure_count, null: false, default: 0
      t.datetime :circuit_open_until
      t.text :last_error
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :evolution_instances, [:account_id, :instance_name], unique: true
    add_index :evolution_instances, :webhook_token, unique: true
    add_index :evolution_instances, :connection_state
    add_index :evolution_instances, :provisioning_status
  end
end
