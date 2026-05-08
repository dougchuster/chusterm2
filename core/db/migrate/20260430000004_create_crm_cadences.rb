class CreateCrmCadences < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_cadences do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :status, null: false, default: 'draft'
      t.string :channel, null: false, default: 'whatsapp'
      t.jsonb :audience_filter, null: false, default: {}
      t.jsonb :enrollment_config, null: false, default: {}
      t.datetime :starts_at
      t.datetime :archived_at
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :crm_cadences, :account_id, name: :idx_crm_cadences_account_id
    add_index :crm_cadences, [:account_id, :status], name: :idx_crm_cadences_account_status
    add_index :crm_cadences, [:account_id, :archived_at], name: :idx_crm_cadences_account_archived

    add_foreign_key :crm_cadences, :accounts
  end
end
