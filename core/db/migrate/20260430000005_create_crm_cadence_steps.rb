class CreateCrmCadenceSteps < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_cadence_steps do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_cadence_id, null: false
      t.integer :position, null: false, default: 0
      t.string :name, null: false
      t.string :channel, null: false, default: 'whatsapp'
      t.string :action_type, null: false, default: 'send_message'
      t.integer :wait_hours, null: false, default: 24
      t.text :template_body
      t.jsonb :action_config, null: false, default: {}
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end

    add_index :crm_cadence_steps, :account_id, name: :idx_crm_cadence_steps_account_id
    add_index :crm_cadence_steps, :crm_cadence_id, name: :idx_crm_cadence_steps_cadence_id
    add_index :crm_cadence_steps, [:crm_cadence_id, :position], name: :idx_crm_cadence_steps_cadence_position

    add_foreign_key :crm_cadence_steps, :accounts
    add_foreign_key :crm_cadence_steps, :crm_cadences
  end
end
