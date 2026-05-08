class CreateCrmExternalConnections < ActiveRecord::Migration[7.0]
  def change
    create_table :crm_external_connections do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :user, foreign_key: true, index: true
      t.string :provider, null: false
      t.string :name
      t.string :status, null: false, default: 'active'
      t.text :access_token
      t.text :refresh_token
      t.datetime :expires_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :crm_external_connections,
              [:account_id, :provider],
              unique: true,
              name: 'idx_crm_external_connections_account_provider'
  end
end
