class CreateCrmActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_activities do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_deal_id
      t.bigint :contact_id
      t.bigint :conversation_id
      t.bigint :owner_id
      t.bigint :assignee_id
      t.string :kind, null: false
      t.string :title, null: false
      t.text :description
      t.string :priority, default: 'normal'
      t.datetime :due_at
      t.datetime :reminder_at
      t.datetime :completed_at
      t.string :outcome
      t.string :created_by_type, default: 'user'
      t.bigint :created_by_id
      t.timestamps null: false
    end
    add_index :crm_activities, :account_id
    add_index :crm_activities, :crm_deal_id
    add_index :crm_activities, :due_at
    add_index :crm_activities, :owner_id
    add_index :crm_activities, :completed_at
  end
end
