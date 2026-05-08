class CreateCrmCadenceEnrollments < ActiveRecord::Migration[7.1]
  def change
    create_table :crm_cadence_enrollments do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_cadence_id, null: false
      t.bigint :crm_deal_id, null: false
      t.integer :current_step_position, null: false, default: 0
      t.string :status, null: false, default: 'active'
      t.datetime :next_step_at
      t.datetime :completed_at
      t.datetime :paused_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :crm_cadence_enrollments, :account_id, name: :idx_crm_cadence_enrollments_account
    add_index :crm_cadence_enrollments, [:crm_cadence_id, :crm_deal_id],
              unique: true, name: :idx_crm_cadence_enrollments_unique
    add_index :crm_cadence_enrollments, [:status, :next_step_at],
              name: :idx_crm_cadence_enrollments_due
    add_index :crm_cadence_enrollments, :crm_deal_id, name: :idx_crm_cadence_enrollments_deal

    add_foreign_key :crm_cadence_enrollments, :accounts
    add_foreign_key :crm_cadence_enrollments, :crm_cadences
    add_foreign_key :crm_cadence_enrollments, :crm_deals
  end
end
