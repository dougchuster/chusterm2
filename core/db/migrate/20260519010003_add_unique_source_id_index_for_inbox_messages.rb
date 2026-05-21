class AddUniqueSourceIdIndexForInboxMessages < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :messages, [:inbox_id, :source_id],
              unique: true,
              where: 'source_id IS NOT NULL',
              algorithm: :concurrently,
              name: 'idx_messages_on_inbox_id_source_id_unique'
  end
end
