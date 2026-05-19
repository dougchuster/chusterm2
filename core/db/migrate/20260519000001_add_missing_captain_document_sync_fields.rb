class AddMissingCaptainDocumentSyncFields < ActiveRecord::Migration[7.0]
  def change
    add_column :captain_documents, :sync_step, :string, if_not_exists: true
    add_column :captain_documents, :last_sync_error_code, :string, if_not_exists: true
    add_column :captain_documents, :content_fingerprint, :string, if_not_exists: true
    add_index :captain_documents, :content_fingerprint, if_not_exists: true
  end
end
