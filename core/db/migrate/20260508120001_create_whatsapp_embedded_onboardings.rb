# frozen_string_literal: true

class CreateWhatsappEmbeddedOnboardings < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_embedded_onboardings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :inbox, null: true, foreign_key: true
      t.bigint :channel_whatsapp_id
      t.string :status, null: false, default: 'not_connected'
      t.string :business_id
      t.string :waba_id
      t.string :phone_number_id
      t.string :flow_type
      t.jsonb :metadata, default: {}
      t.text :last_error
      t.datetime :completed_at
      t.timestamps
    end

    add_index :whatsapp_embedded_onboardings, :waba_id
    add_index :whatsapp_embedded_onboardings, :status
    add_index :whatsapp_embedded_onboardings,
              %i[account_id waba_id phone_number_id],
              name: 'idx_wa_onboarding_account_waba_phone'
  end
end
