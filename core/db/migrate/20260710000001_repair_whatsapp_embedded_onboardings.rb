# frozen_string_literal: true

class RepairWhatsappEmbeddedOnboardings < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:whatsapp_embedded_onboardings)

    create_onboardings_table
    add_onboarding_indexes
  end

  private

  def create_onboardings_table
    create_table :whatsapp_embedded_onboardings do |table|
      table.references :account, null: false, foreign_key: true
      table.references :user, null: true, foreign_key: true
      table.references :inbox, null: true, foreign_key: true
      table.bigint :channel_whatsapp_id
      table.string :status, null: false, default: 'not_connected'
      table.string :business_id
      table.string :waba_id
      table.string :phone_number_id
      table.string :flow_type
      table.jsonb :metadata, default: {}
      table.text :last_error
      table.datetime :completed_at
      table.timestamps
    end
  end

  def add_onboarding_indexes
    add_index :whatsapp_embedded_onboardings, :waba_id
    add_index :whatsapp_embedded_onboardings, :status
    add_index :whatsapp_embedded_onboardings,
              %i[account_id waba_id phone_number_id],
              name: 'idx_wa_onboarding_account_waba_phone'
  end
end
