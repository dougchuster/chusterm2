class AddMetadataToDataImports < ActiveRecord::Migration[7.1]
  def change
    add_column :data_imports, :metadata, :jsonb, default: {}, null: false unless column_exists?(:data_imports, :metadata)
  end
end
