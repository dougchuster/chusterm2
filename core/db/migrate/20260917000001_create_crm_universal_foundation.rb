# frozen_string_literal: true

# Fase 2 (A0): fundação do núcleo universal do CRM.
#
# Estratégia 100% aditiva — nada é renomeado nem removido, então a conta
# jurídica em produção continua idêntica e o rollback é só `down`:
#
# - crm_deals ganha `category`/`subcategory` universais. `legal_area` e
#   `case_type` seguem existindo e o modelo faz dual-write; o backfill copia
#   os valores legados para as novas colunas.
# - crm_account_packs registra quais packs (legal, sales_default, ...) estão
#   instalados por conta — é a fonte para taxonomia, campos e prompts.
# - crm_field_definitions: campos customizados por conta/pack.
# - crm_activity_types: tipos de atividade por conta/pack (universais +
#   específicos do pack), substituindo o KINDS hardcoded jurídico quando a
#   conta roda em modo universal.
class CreateCrmUniversalFoundation < ActiveRecord::Migration[7.2]
  def up
    add_universal_category_columns
    backfill_categories
    create_account_packs_table
    create_field_definitions_table
    create_activity_types_table
  end

  def down
    drop_table :crm_activity_types
    drop_table :crm_field_definitions
    drop_table :crm_account_packs

    remove_index :crm_deals, name: 'index_crm_deals_on_account_and_category'
    remove_column :crm_deals, :subcategory
    remove_column :crm_deals, :category
  end

  private

  def add_universal_category_columns
    add_column :crm_deals, :category, :string
    add_column :crm_deals, :subcategory, :string
    add_index :crm_deals, [:account_id, :category], name: 'index_crm_deals_on_account_and_category'
  end

  # Backfill: o legado jurídico vira a categoria inicial. Idempotente.
  def backfill_categories
    execute <<~SQL.squish
      UPDATE crm_deals
      SET category = legal_area, subcategory = case_type
      WHERE category IS NULL AND (legal_area IS NOT NULL OR case_type IS NOT NULL)
    SQL
  end

  def create_account_packs_table
    create_table :crm_account_packs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :version, null: false, default: '1'
      t.jsonb :settings, default: {}, null: false
      t.datetime :installed_at, null: false
      t.timestamps
    end
    add_index :crm_account_packs, [:account_id, :slug], unique: true, name: 'index_crm_account_packs_on_account_and_slug'
  end

  def create_field_definitions_table
    create_table :crm_field_definitions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :pack_slug
      t.string :key, null: false
      t.string :label, null: false
      t.string :field_type, null: false, default: 'text'
      t.jsonb :options, default: [], null: false
      t.string :applies_to, null: false, default: 'deal'
      t.boolean :required, null: false, default: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_field_definitions, [:account_id, :key], unique: true, name: 'index_crm_field_definitions_on_account_and_key'
  end

  def create_activity_types_table
    create_table :crm_activity_types do |t|
      t.references :account, null: false, foreign_key: true
      t.string :pack_slug
      t.string :key, null: false
      t.string :label, null: false
      t.string :icon
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_activity_types, [:account_id, :key], unique: true, name: 'index_crm_activity_types_on_account_and_key'
  end
end
