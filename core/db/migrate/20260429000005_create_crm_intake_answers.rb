class CreateCrmIntakeAnswers < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_intake_answers do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_deal_id, null: false
      t.bigint :contact_id
      t.bigint :conversation_id
      t.string :question_key, null: false, limit: 120
      t.text :question_text, null: false
      t.text :answer_text
      t.jsonb :answer_json, default: {}
      t.string :collected_by, default: 'captain'
      t.timestamps null: false
    end
    add_index :crm_intake_answers, :crm_deal_id
  end
end
