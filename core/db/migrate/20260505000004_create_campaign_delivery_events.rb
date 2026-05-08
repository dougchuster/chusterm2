class CreateCampaignDeliveryEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_delivery_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :campaign, null: false, foreign_key: true
      t.references :contact, foreign_key: true
      t.references :conversation, foreign_key: true
      t.references :message, foreign_key: true
      t.string :event_type, null: false
      t.string :provider
      t.string :external_id
      t.jsonb :metadata, default: {}, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :campaign_delivery_events, [:campaign_id, :event_type]
    add_index :campaign_delivery_events, [:account_id, :event_type, :occurred_at],
              name: 'idx_campaign_delivery_events_account_event_time'
    add_index :campaign_delivery_events, [:campaign_id, :event_type, :contact_id],
              unique: true,
              where: 'contact_id IS NOT NULL',
              name: 'idx_campaign_delivery_events_unique_contact'
    add_index :campaign_delivery_events, [:provider, :event_type, :external_id],
              unique: true,
              where: 'external_id IS NOT NULL',
              name: 'idx_campaign_delivery_events_unique_external'
  end
end
