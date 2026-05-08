class CreateCrmPipelines < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_pipelines do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.string :kind, default: 'legal_intake'
      t.boolean :is_default, default: false
      t.integer :position, default: 0
      t.datetime :archived_at
      t.timestamps null: false
    end
    add_index :crm_pipelines, :account_id
    add_index :crm_pipelines, [:account_id, :slug], unique: true
  end
end
