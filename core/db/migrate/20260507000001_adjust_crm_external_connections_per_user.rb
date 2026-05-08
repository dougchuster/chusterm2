class AdjustCrmExternalConnectionsPerUser < ActiveRecord::Migration[7.1]
  def up
    remove_index :crm_external_connections,
                 name: 'idx_crm_external_connections_account_provider',
                 if_exists: true

    add_index :crm_external_connections,
              [:account_id, :user_id, :provider],
              unique: true,
              where: 'user_id IS NOT NULL',
              name: 'idx_crm_external_connections_account_user_provider'

    add_index :crm_external_connections,
              [:account_id, :provider],
              unique: true,
              where: 'user_id IS NULL',
              name: 'idx_crm_external_connections_account_provider_legacy'
  end

  def down
    remove_index :crm_external_connections,
                 name: 'idx_crm_external_connections_account_user_provider',
                 if_exists: true
    remove_index :crm_external_connections,
                 name: 'idx_crm_external_connections_account_provider_legacy',
                 if_exists: true

    add_index :crm_external_connections,
              [:account_id, :provider],
              unique: true,
              name: 'idx_crm_external_connections_account_provider'
  end
end
