class CreateCrmLeadScores < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_lead_scores do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_deal_id, null: false
      t.bigint :contact_id
      t.integer :fit_score, default: 0
      t.integer :urgency_score, default: 0
      t.integer :economic_score, default: 0
      t.integer :documents_score, default: 0
      t.integer :clarity_score, default: 0
      t.integer :engagement_score, default: 0
      t.integer :payment_capacity_score, default: 0
      t.integer :conflict_score, default: 0
      t.integer :total_score, default: 0
      t.string :classification
      t.text :reason
      t.jsonb :factors, default: {}
      t.string :calculated_by, default: 'rule_based'
      t.datetime :calculated_at, null: false
      t.timestamps null: false
    end
    add_index :crm_lead_scores, :crm_deal_id
  end
end
