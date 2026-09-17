class CreateMarketingEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :marketing_events do |t|
      t.bigint  :account_id,                 null: false
      t.bigint  :crm_external_connection_id
      t.bigint  :crm_deal_id
      t.bigint  :marketing_lead_id
      t.string  :provider,                   null: false, limit: 30
      t.string  :direction,                  null: false, default: 'outbound', limit: 10
      t.string  :event_name,                 null: false
      t.string  :event_id,                   null: false
      t.string  :status,                     null: false, default: 'pending', limit: 20
      t.jsonb   :payload,                    null: false, default: {}
      t.jsonb   :response,                   null: false, default: {}
      t.datetime :sent_at

      t.timestamps
    end

    add_indexes_and_foreign_keys
  end

  private

  def add_indexes_and_foreign_keys
    add_index :marketing_events, :account_id,
              name: :idx_marketing_events_account
    add_index :marketing_events, [:account_id, :event_id],
              unique: true,
              name: :idx_marketing_events_unique
    add_index :marketing_events, [:account_id, :status],
              name: :idx_marketing_events_status

    add_foreign_key :marketing_events, :accounts
    add_foreign_key :marketing_events, :crm_external_connections
    add_foreign_key :marketing_events, :crm_deals
    add_foreign_key :marketing_events, :marketing_leads
  end
end
