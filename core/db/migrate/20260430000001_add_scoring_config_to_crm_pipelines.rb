class AddScoringConfigToCrmPipelines < ActiveRecord::Migration[7.1]
  def change
    add_column :crm_pipelines, :scoring_config, :jsonb, default: {}, null: false

    # Índice GIN para queries JSONB futuras
    add_index :crm_pipelines, :scoring_config, using: :gin, name: :idx_crm_pipelines_scoring_config
  end
end
