# frozen_string_literal: true

class DeduplicateLegacyInboxForeignKeys < ActiveRecord::Migration[7.1]
  LEGACY_INBOX_TABLES = %w[novacrm_ai_flows nova_ai_agent_inboxes].freeze

  def up
    LEGACY_INBOX_TABLES.each do |table_name|
      next unless table_exists?(table_name)
      next unless column_exists?(table_name, :inbox_id)

      drop_inbox_foreign_keys(table_name).each do |constraint_name|
        execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{quote_table_name(constraint_name)}"
      end

      add_foreign_key table_name,
                      :inboxes,
                      column: :inbox_id,
                      on_delete: :cascade,
                      validate: false
    end
  end

  def down
    # Keep the deduplicated cascade behavior; it protects inbox deletion.
  end

  private

  def drop_inbox_foreign_keys(table_name)
    select_values(<<~SQL.squish)
      SELECT con.conname
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = ANY(con.conkey)
      WHERE rel.relname = #{quote(table_name)}
        AND att.attname = 'inbox_id'
        AND con.contype = 'f'
    SQL
  end
end
