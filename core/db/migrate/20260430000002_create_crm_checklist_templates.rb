class CreateCrmChecklistTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_checklist_templates do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :case_type
      t.string :legal_area
      t.jsonb :items, null: false, default: []
      t.integer :position, null: false, default: 0
      t.datetime :archived_at

      t.timestamps
    end

    add_index :crm_checklist_templates, %i[account_id case_type], name: :idx_crm_checklist_templates_account_case_type
    add_index :crm_checklist_templates, %i[account_id legal_area], name: :idx_crm_checklist_templates_account_legal_area

    add_foreign_key :crm_checklist_templates, :accounts
  end
end
