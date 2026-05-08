class AddLifecycleStageToContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :lifecycle_stage, :string, default: 'visitor', null: false
    add_column :contacts, :lifecycle_stage_changed_at, :datetime
    add_column :contacts, :became_lead_at, :datetime
    add_column :contacts, :became_customer_at, :datetime
    add_column :contacts, :first_deal_won_at, :datetime
    add_column :contacts, :last_crm_interaction_at, :datetime
    add_column :contacts, :lifetime_value_cents, :bigint, default: 0, null: false
    add_column :contacts, :total_deals_count, :integer, default: 0, null: false
    add_column :contacts, :won_deals_count, :integer, default: 0, null: false

    add_index :contacts, :lifecycle_stage
    add_index :contacts, [:account_id, :lifecycle_stage]
  end
end
