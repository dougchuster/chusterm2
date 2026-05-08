class CreateCrmAuditEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_audit_events do |t|
      t.bigint :account_id, null: false
      t.string :actor_type, null: false
      t.bigint :actor_id
      t.string :action, null: false, limit: 120
      t.string :target_type, null: false, limit: 120
      t.bigint :target_id, null: false
      t.jsonb :payload, default: {}
      t.string :ip, limit: 80
      t.text :user_agent
      t.datetime :created_at, null: false
    end
    add_index :crm_audit_events, [:account_id, :target_type, :target_id],
              name: 'idx_crm_audit_events_target'
  end
end
