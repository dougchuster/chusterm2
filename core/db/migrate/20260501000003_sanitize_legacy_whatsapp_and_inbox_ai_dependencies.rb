# frozen_string_literal: true

class SanitizeLegacyWhatsappAndInboxAiDependencies < ActiveRecord::Migration[7.1]
  LEGACY_INBOX_TABLES = %w[novacrm_ai_flows nova_ai_agent_inboxes].freeze

  def up
    normalize_legacy_evolution_provider
    allow_legacy_inbox_dependencies_to_cascade
  end

  def down
    # Data normalization and FK cascade repair are intentionally not reversed.
  end

  private

  def normalize_legacy_evolution_provider
    return unless table_exists?(:channel_whatsapp)
    return unless column_exists?(:channel_whatsapp, :provider)

    execute <<~SQL.squish
      UPDATE channel_whatsapp
      SET provider = 'evolution'
      WHERE provider = 'evolution_api'
    SQL
  end

  def allow_legacy_inbox_dependencies_to_cascade
    LEGACY_INBOX_TABLES.each do |table_name|
      next unless table_exists?(table_name)
      next unless column_exists?(table_name, :inbox_id)

      replace_inbox_foreign_key_with_cascade(table_name)
    end
  end

  def replace_inbox_foreign_key_with_cascade(table_name)
    constraint_names = select_values(<<~SQL.squish)
      SELECT con.conname
      FROM pg_constraint con
      JOIN pg_class rel ON rel.oid = con.conrelid
      JOIN pg_attribute att ON att.attrelid = rel.oid AND att.attnum = ANY(con.conkey)
      WHERE rel.relname = #{quote(table_name)}
        AND att.attname = 'inbox_id'
        AND con.contype = 'f'
    SQL

    constraint_names.each do |constraint_name|
      execute "ALTER TABLE #{quote_table_name(table_name)} DROP CONSTRAINT #{quote_table_name(constraint_name)}"
    end

    add_foreign_key table_name,
                    :inboxes,
                    column: :inbox_id,
                    on_delete: :cascade,
                    validate: false
  end
end
