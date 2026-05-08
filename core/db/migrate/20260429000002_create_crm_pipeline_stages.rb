class CreateCrmPipelineStages < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_pipeline_stages do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_pipeline_id, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, default: 0
      t.integer :probability_pct, default: 0
      t.integer :expected_duration_hours
      t.jsonb :required_fields, default: {}
      t.string :color
      t.datetime :archived_at
      t.timestamps null: false
    end
    add_index :crm_pipeline_stages, :account_id
    add_index :crm_pipeline_stages, :crm_pipeline_id
    add_index :crm_pipeline_stages, [:crm_pipeline_id, :slug], unique: true
  end
end
