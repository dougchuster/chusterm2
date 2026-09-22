# Cofre de documentos — universal e formulários (PROJETO-COFRE-DOCUMENTOS.md
# §4.5, §4.8 e §8.7). Tudo aditivo.
#
# - crm_document_settings: modelo de documentos escolhido (geral, jurídico,
#   saúde...), padrões de nome editáveis e opções de captura, por conta.
# - crm_document_forms: formulários montados pela conta (campos, documentos
#   pedidos, textos), com link público fixo.
# - crm_document_form_links: link personalizado de um formulário para um
#   cliente ("o que falta"); só o digest do token é gravado.
# - crm_document_submissions: cada envio, com protocolo e respostas.
class CreateCrmDocumentFormsAndSettings < ActiveRecord::Migration[7.1]
  def change
    create_settings
    create_forms
    create_form_links
    create_submissions
  end

  private

  def create_settings
    create_table :crm_document_settings do |t|
      t.bigint :account_id, null: false
      t.string :preset, null: false, default: 'geral'
      t.jsonb :naming, null: false, default: {}
      t.boolean :capture_outgoing, null: false, default: true
      t.timestamps
    end
    add_index :crm_document_settings, :account_id, unique: true
    add_foreign_key :crm_document_settings, :accounts
  end

  def create_forms
    create_table :crm_document_forms do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.string :public_token, null: false
      t.boolean :active, null: false, default: true
      t.jsonb :fields, null: false, default: []
      t.jsonb :document_items, null: false, default: []
      t.jsonb :settings, null: false, default: {}
      t.bigint :created_by_user_id
      t.integer :submissions_count, null: false, default: 0
      t.datetime :archived_at
      t.timestamps
    end
    add_index :crm_document_forms, :public_token, unique: true
    add_index :crm_document_forms, %i[account_id archived_at]
    add_foreign_key :crm_document_forms, :accounts
  end

  def create_form_links
    create_table :crm_document_form_links do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_document_form_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :crm_deal_id
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.bigint :created_by_user_id
      t.datetime :last_access_at
      t.integer :access_count, null: false, default: 0
      t.integer :submissions_count, null: false, default: 0
      t.timestamps
    end
    link_form_links
  end

  def link_form_links
    add_index :crm_document_form_links, :token_digest, unique: true
    add_index :crm_document_form_links, %i[account_id contact_id]
    add_foreign_key :crm_document_form_links, :accounts
    add_foreign_key :crm_document_form_links, :crm_document_forms, on_delete: :cascade
    add_foreign_key :crm_document_form_links, :contacts, on_delete: :cascade
    add_foreign_key :crm_document_form_links, :crm_deals, on_delete: :nullify
  end

  def create_submissions
    create_table :crm_document_submissions do |t|
      t.bigint :account_id, null: false
      t.bigint :crm_document_form_id
      t.bigint :crm_document_form_link_id
      t.bigint :contact_id
      t.bigint :crm_deal_id
      submission_columns(t)
      t.timestamps
    end
    link_submissions
  end

  def submission_columns(table)
    table.string :protocol, null: false
    table.jsonb :answers, null: false, default: {}
    table.string :match_status, null: false
    table.boolean :verified, null: false, default: false
    table.string :review_status, null: false, default: 'new'
    table.integer :documents_count, null: false, default: 0
    table.datetime :consent_at
    table.string :ip
    table.string :user_agent
    table.bigint :reviewed_by_user_id
    table.datetime :reviewed_at
  end

  def link_submissions
    add_index :crm_document_submissions, %i[account_id protocol], unique: true
    add_index :crm_document_submissions, %i[account_id review_status created_at],
              name: :idx_crm_document_submissions_review
    add_index :crm_document_submissions, :contact_id
    add_foreign_key :crm_document_submissions, :accounts
    add_foreign_key :crm_document_submissions, :crm_document_forms, on_delete: :nullify
    add_foreign_key :crm_document_submissions, :crm_document_form_links, on_delete: :nullify
    # As respostas contêm dados pessoais: somem junto com o contato (LGPD).
    add_foreign_key :crm_document_submissions, :contacts, on_delete: :cascade
    add_foreign_key :crm_document_submissions, :crm_deals, on_delete: :nullify
  end
end
