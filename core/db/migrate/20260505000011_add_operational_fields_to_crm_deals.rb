class AddOperationalFieldsToCrmDeals < ActiveRecord::Migration[7.0]
  def change
    add_column :crm_deals, :operational_status, :string, default: 'active', null: false
    add_column :crm_deals, :source_detail, :string
    add_column :crm_deals, :disposition_reason, :string
    add_column :crm_deals, :disposition_note, :text
    add_column :crm_deals, :disposed_at, :datetime
    add_column :crm_deals, :archived_at, :datetime

    add_index :crm_deals, :operational_status
    add_index :crm_deals, :source
    add_index :crm_deals, :disposition_reason
    add_index :crm_deals, :archived_at
  end
end
