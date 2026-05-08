class AddLgpdFieldsToCrmDeals < ActiveRecord::Migration[7.0]
  def change
    add_column :crm_deals, :consent_channel, :string
    add_column :crm_deals, :consent_collected_at, :datetime
    add_column :crm_deals, :data_retention_until, :date

    add_index :crm_deals, :data_retention_until
  end
end
