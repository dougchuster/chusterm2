class CreateCaptainPlaybooks < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_playbooks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :assistant, foreign_key: { to_table: :captain_assistants }
      t.string :name, null: false
      t.string :legal_area
      t.string :case_type
      t.string :objective
      t.text :instructions
      t.jsonb :required_fields, default: [], null: false
      t.jsonb :escalation_rules, default: {}, null: false
      t.jsonb :metadata, default: {}, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :captain_playbooks, [:account_id, :legal_area]
    add_index :captain_playbooks, [:account_id, :active, :position]
  end
end
