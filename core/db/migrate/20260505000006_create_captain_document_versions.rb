class CreateCaptainDocumentVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_document_versions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :assistant, null: false, foreign_key: { to_table: :captain_assistants }
      t.references :document, null: false, foreign_key: { to_table: :captain_documents }
      t.integer :version_number, null: false
      t.string :name
      t.string :external_link
      t.text :content
      t.string :content_digest, null: false
      t.jsonb :metadata, default: {}, null: false
      t.datetime :published_at

      t.timestamps
    end

    add_index :captain_document_versions, [:document_id, :version_number], unique: true,
                                                                      name: 'idx_captain_document_versions_number'
    add_index :captain_document_versions, [:document_id, :content_digest], unique: true,
                                                                     name: 'idx_captain_document_versions_digest'
  end
end
