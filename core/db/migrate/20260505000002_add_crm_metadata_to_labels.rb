class AddCrmMetadataToLabels < ActiveRecord::Migration[7.1]
  def change
    add_column :labels, :category, :string
    add_column :labels, :slug, :string
    add_column :labels, :scope, :string, default: 'both', null: false
    add_column :labels, :is_system, :boolean, default: false, null: false

    add_index :labels, [:account_id, :category],
              name: 'index_labels_on_account_id_and_category'
    add_index :labels, [:account_id, :slug],
              unique: true,
              where: 'slug IS NOT NULL',
              name: 'index_labels_on_account_id_and_slug'
  end
end
