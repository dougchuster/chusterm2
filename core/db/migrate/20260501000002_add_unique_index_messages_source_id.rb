# frozen_string_literal: true

class AddUniqueIndexMessagesSourceId < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    remove_index :messages, :source_id, if_exists: true, algorithm: :concurrently
    add_index :messages, %i[account_id source_id],
              unique: true,
              where: 'source_id IS NOT NULL',
              name: 'index_messages_on_account_id_and_source_id_unique',
              algorithm: :concurrently
  end
end
