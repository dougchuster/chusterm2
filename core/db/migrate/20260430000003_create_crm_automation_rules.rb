class CreateCrmAutomationRules < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_automation_rules do |t|
      t.bigint  :account_id,            null: false
      t.bigint  :crm_pipeline_stage_id, null: false
      t.string  :trigger_event,         null: false, default: 'stage_entered'
      t.string  :action_type,           null: false, default: 'create_activity'
      t.jsonb   :action_config,         null: false, default: {}
      t.string  :name,                  null: false
      t.boolean :is_active,             null: false, default: true
      t.integer :position,              null: false, default: 0

      t.timestamps
    end

    add_index :crm_automation_rules, :account_id,
              name: :idx_crm_automation_rules_account_id
    add_index :crm_automation_rules, :crm_pipeline_stage_id,
              name: :idx_crm_automation_rules_pipeline_stage_id

    add_foreign_key :crm_automation_rules, :accounts
    add_foreign_key :crm_automation_rules, :crm_pipeline_stages
  end
end
