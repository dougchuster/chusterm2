class CreateMarketingCampaigns < ActiveRecord::Migration[7.1]
  def change
    create_table :marketing_campaigns do |t|
      t.bigint  :account_id,                  null: false
      t.bigint  :crm_external_connection_id,  null: false
      t.string  :provider,                    null: false, limit: 40
      t.string  :external_id,                 null: false
      t.string  :external_parent_id
      t.string  :level,                       null: false, default: 'campaign', limit: 20
      t.string  :name,                        null: false
      t.string  :status,                                   limit: 40
      t.string  :objective,                                limit: 60
      t.decimal :daily_budget,                precision: 14, scale: 2
      t.string  :currency,                                 limit: 8
      t.jsonb   :metadata,                    null: false, default: {}

      t.timestamps
    end

    add_indexes_and_foreign_keys
  end

  private

  def add_indexes_and_foreign_keys
    add_index :marketing_campaigns, :account_id,
              name: :idx_marketing_campaigns_account
    add_index :marketing_campaigns, [:crm_external_connection_id, :level, :external_id],
              unique: true,
              name: :idx_marketing_campaigns_unique
    add_index :marketing_campaigns, [:account_id, :provider],
              name: :idx_marketing_campaigns_provider

    add_foreign_key :marketing_campaigns, :accounts
    add_foreign_key :marketing_campaigns, :crm_external_connections
  end
end
