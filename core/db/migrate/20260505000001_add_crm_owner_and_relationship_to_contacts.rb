class AddCrmOwnerAndRelationshipToContacts < ActiveRecord::Migration[7.1]
  def change
    add_column :contacts, :relationship_status, :string, default: 'lead', null: false
    add_column :contacts, :crm_owner_id, :integer
    add_column :contacts, :crm_owner_assigned_at, :datetime
    add_column :contacts, :crm_owner_source, :string

    add_index :contacts, [:account_id, :relationship_status],
              name: 'index_contacts_on_account_id_and_relationship_status'
    add_index :contacts, [:account_id, :crm_owner_id],
              name: 'index_contacts_on_account_id_and_crm_owner_id'

    add_foreign_key :contacts, :users, column: :crm_owner_id, on_delete: :nullify
  end
end
