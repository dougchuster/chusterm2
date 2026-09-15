class CreateCrmAutomationRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_automation_runs do |t|
      t.bigint  :account_id,             null: false
      t.bigint  :crm_automation_rule_id, null: false
      t.bigint  :crm_deal_id,            null: false
      t.string  :status,                 null: false, default: 'executed'
      t.string  :skip_reason,            limit: 80
      t.text    :error
      t.jsonb   :payload,                null: false, default: {}
      t.datetime :started_at,            null: false
      t.datetime :finished_at

      t.timestamps
    end

    add_indexes_and_foreign_keys
  end

  private

  def add_indexes_and_foreign_keys
    add_index :crm_automation_runs, :account_id,
              name: :idx_crm_automation_runs_account_id
    add_index :crm_automation_runs, :crm_automation_rule_id,
              name: :idx_crm_automation_runs_rule_id
    add_index :crm_automation_runs, [:account_id, :crm_deal_id, :started_at],
              name: :idx_crm_automation_runs_deal_started

    add_foreign_key :crm_automation_runs, :accounts
    add_foreign_key :crm_automation_runs, :crm_automation_rules
    add_foreign_key :crm_automation_runs, :crm_deals
  end
end
