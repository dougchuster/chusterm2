class AddGoogleCalendarFieldsToCrmActivities < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_activities, :external_calendar_event_id, :string
    add_column :crm_activities, :external_calendar_link, :string
    add_column :crm_activities, :meeting_url, :string
    add_column :crm_activities, :external_calendar_synced_at, :datetime

    add_index :crm_activities, [:account_id, :external_calendar_event_id],
              unique: true,
              where: 'external_calendar_event_id IS NOT NULL',
              name: 'idx_crm_activities_account_calendar_event'
  end
end
