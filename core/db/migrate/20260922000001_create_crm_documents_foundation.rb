# Cofre de documentos — F1 (PROJETO-COFRE-DOCUMENTOS.md §4).
# Tudo aditivo: nenhuma tabela existente é alterada. Solicitações, envios do
# portal e estado de sincronização (espelho/Drive) chegam nas fases F4/F5.
class CreateCrmDocumentsFoundation < ActiveRecord::Migration[7.1]
  def change
    create_document_types
    create_folder_templates
    create_folders
    index_folders
    create_documents
    index_documents
    link_documents
  end

  private

  def create_document_types
    create_table :crm_document_types do |t|
      t.bigint :account_id, null: false
      t.string :slug, null: false
      t.string :label, null: false
      t.string :target_slot, null: false
      t.integer :validity_days
      t.jsonb :patterns, null: false, default: []
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :crm_document_types, %i[account_id slug], unique: true, name: :idx_crm_document_types_account_slug
    add_foreign_key :crm_document_types, :accounts
  end

  def create_folder_templates
    create_table :crm_document_folder_templates do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :legal_area, null: false, default: 'geral'
      t.string :scope, null: false
      t.jsonb :tree, null: false, default: []
      t.boolean :default, null: false, default: false
      t.timestamps
    end
    add_index :crm_document_folder_templates, %i[account_id scope legal_area],
              unique: true, name: :idx_crm_document_folder_templates_scope_area
    add_foreign_key :crm_document_folder_templates, :accounts
  end

  def create_folders
    create_table :crm_document_folders do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :parent_id
      t.bigint :crm_deal_id
      t.string :name, null: false
      t.string :slot
      t.string :kind, null: false, default: 'custom'
      t.integer :position, null: false, default: 0
      t.datetime :archived_at
      t.timestamps
    end
  end

  def index_folders
    add_index :crm_document_folders, %i[account_id contact_id], name: :idx_crm_document_folders_account_contact
    add_index :crm_document_folders, :parent_id
    add_index :crm_document_folders, :crm_deal_id
    # Irmãos não repetem nome (sem diferenciar maiúsculas); raiz usa parent 0.
    add_index :crm_document_folders, 'account_id, contact_id, COALESCE(parent_id, 0), lower(name)',
              unique: true, where: 'archived_at IS NULL', name: :idx_crm_document_folders_sibling_name
    add_foreign_key :crm_document_folders, :accounts
    # Pastas são só metadados: somem junto com o contato ou com a pasta-mãe.
    add_foreign_key :crm_document_folders, :contacts, on_delete: :cascade
    add_foreign_key :crm_document_folders, :crm_document_folders, column: :parent_id, on_delete: :cascade
    add_foreign_key :crm_document_folders, :crm_deals, on_delete: :nullify
  end

  def create_documents
    create_table :crm_documents do |t|
      t.bigint :account_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :crm_document_folder_id
      t.bigint :crm_deal_id
      document_naming_columns(t)
      document_provenance_columns(t)
      document_review_columns(t)
      t.datetime :archived_at
      t.timestamps
    end
  end

  def document_naming_columns(table)
    table.string :doc_type
    table.string :description
    table.date :document_date
    table.string :file_name, null: false
    table.boolean :name_locked, null: false, default: false
    table.string :original_filename
    table.string :content_type
    table.bigint :byte_size
    table.string :checksum
  end

  def document_provenance_columns(table)
    table.string :source, null: false
    table.bigint :source_attachment_id
    table.bigint :source_message_id
    table.bigint :uploaded_by_user_id
    table.boolean :uploaded_by_contact, null: false, default: false
  end

  def document_review_columns(table)
    table.string :status, null: false, default: 'received'
    table.text :review_note
    table.jsonb :tags, null: false, default: []
    table.date :expires_on
    table.integer :versions_count, null: false, default: 1
    table.jsonb :meta, null: false, default: {}
  end

  def index_documents
    add_index :crm_documents, %i[account_id contact_id archived_at], name: :idx_crm_documents_account_contact
    add_index :crm_documents, %i[account_id crm_deal_id], name: :idx_crm_documents_account_deal
    add_index :crm_documents, %i[account_id crm_document_folder_id], name: :idx_crm_documents_account_folder
    add_index :crm_documents, %i[account_id contact_id checksum], name: :idx_crm_documents_contact_checksum
    add_index :crm_documents, %i[account_id status], name: :idx_crm_documents_account_status
    add_index :crm_documents, %i[account_id source_attachment_id],
              unique: true, where: 'source_attachment_id IS NOT NULL', name: :idx_crm_documents_source_attachment
    add_index :crm_documents, :tags, using: :gin
  end

  def link_documents
    add_foreign_key :crm_documents, :accounts
    # Sem cascade: documento tem arquivo no disco e só pode sair pelo model
    # (Contact has_many dependent: :destroy), que apaga o blob junto.
    add_foreign_key :crm_documents, :contacts
    add_foreign_key :crm_documents, :crm_document_folders, on_delete: :nullify
    add_foreign_key :crm_documents, :crm_deals, on_delete: :nullify
  end
end
