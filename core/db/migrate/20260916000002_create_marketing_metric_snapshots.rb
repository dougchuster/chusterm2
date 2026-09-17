class CreateMarketingMetricSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :marketing_metric_snapshots do |t|
      t.bigint  :account_id,             null: false
      t.bigint  :marketing_campaign_id,  null: false
      t.date    :date,                   null: false
      t.bigint  :impressions,            null: false, default: 0
      t.bigint  :clicks,                 null: false, default: 0
      t.decimal :spend,                  null: false, default: 0, precision: 14, scale: 4
      t.bigint  :leads,                  null: false, default: 0
      t.bigint  :conversions,            null: false, default: 0
      t.decimal :conversion_value,       null: false, default: 0, precision: 14, scale: 2
      t.jsonb   :metadata,               null: false, default: {}

      t.timestamps
    end

    add_indexes_and_foreign_keys
  end

  private

  def add_indexes_and_foreign_keys
    add_index :marketing_metric_snapshots, :account_id,
              name: :idx_marketing_snapshots_account
    add_index :marketing_metric_snapshots, [:marketing_campaign_id, :date],
              unique: true,
              name: :idx_marketing_snapshots_campaign_date
    add_index :marketing_metric_snapshots, [:account_id, :date],
              name: :idx_marketing_snapshots_date

    add_foreign_key :marketing_metric_snapshots, :accounts
    add_foreign_key :marketing_metric_snapshots, :marketing_campaigns
  end
end
