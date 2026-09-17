class CreateMarketingLeads < ActiveRecord::Migration[7.1]
  def change
    create_table :marketing_leads do |t|
      t.bigint  :account_id,                 null: false
      t.bigint  :crm_external_connection_id
      t.bigint  :contact_id
      t.bigint  :crm_deal_id
      t.string  :leadgen_id,                 null: false
      t.string  :form_id
      t.string  :form_name
      t.string  :campaign_id
      t.string  :adset_id
      t.string  :ad_id
      t.string  :platform,                   limit: 30
      t.string  :status,                     null: false, default: 'new', limit: 20
      t.jsonb   :field_data,                 null: false, default: {}
      t.jsonb   :metadata,                   null: false, default: {}
      t.datetime :converted_at

      t.timestamps
    end

    add_indexes_and_foreign_keys
  end

  private

  def add_indexes_and_foreign_keys
    add_index :marketing_leads, :account_id,
              name: :idx_marketing_leads_account
    add_index :marketing_leads, [:account_id, :leadgen_id],
              unique: true,
              name: :idx_marketing_leads_unique
    add_index :marketing_leads, [:account_id, :status],
              name: :idx_marketing_leads_status

    add_foreign_key :marketing_leads, :accounts
    add_foreign_key :marketing_leads, :crm_external_connections
    add_foreign_key :marketing_leads, :contacts
    add_foreign_key :marketing_leads, :crm_deals
  end
end
