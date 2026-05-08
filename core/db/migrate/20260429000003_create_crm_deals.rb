class CreateCrmDeals < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_deals do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id
      t.bigint :conversation_id
      t.bigint :inbox_id
      t.bigint :team_id
      t.bigint :owner_id
      t.bigint :assignee_id
      t.bigint :crm_pipeline_id, null: false
      t.bigint :crm_pipeline_stage_id, null: false
      t.string :title, null: false
      t.string :status, default: 'open'
      t.string :legal_area
      t.string :case_type
      t.string :urgency_level
      t.string :source
      t.bigint :value_estimate_cents, default: 0
      t.integer :probability_pct, default: 0
      t.integer :score_total, default: 0
      t.string :score_classification
      t.string :conflict_check_status, default: 'pending'
      t.string :documents_status, default: 'pending'
      t.string :lgpd_basis
      t.string :consent_status
      t.text :summary
      t.text :next_best_action
      t.text :score_reason
      t.bigint :crm_loss_reason_id
      t.text :lost_reason_note
      t.datetime :closed_at
      t.jsonb :custom_fields, default: {}
      t.jsonb :attribution, default: {}
      t.timestamps null: false
    end
    add_index :crm_deals, :account_id
    add_index :crm_deals, :contact_id
    add_index :crm_deals, :conversation_id
    add_index :crm_deals, [:crm_pipeline_id, :crm_pipeline_stage_id]
    add_index :crm_deals, :owner_id
    add_index :crm_deals, :status
    add_index :crm_deals, :legal_area
    add_index :crm_deals, :score_total
  end
end
