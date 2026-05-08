class AddScoringConfigToCampaigns < ActiveRecord::Migration[7.1]
  def change
    add_column :campaigns, :scoring_config, :jsonb, default: {}, null: false
    add_index :campaigns, :scoring_config, using: :gin, name: :idx_campaigns_scoring_config
  end
end
