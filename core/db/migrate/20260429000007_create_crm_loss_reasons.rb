class CreateCrmLossReasons < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_loss_reasons do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.string :legal_area
      t.integer :position, default: 0
      t.datetime :archived_at
      t.timestamps null: false
    end
    add_index :crm_loss_reasons, :account_id
    add_index :crm_loss_reasons, [:account_id, :slug], unique: true
  end
end
