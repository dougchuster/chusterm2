class CreateEvolutionApiConfigurations < ActiveRecord::Migration[7.1]
  def change
    create_table :evolution_api_configurations do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :base_url, null: false
      t.string :webhook_base_url, null: false
      t.text :global_api_key
      t.string :webhook_secret_digest
      t.string :health_status, null: false, default: 'unknown'
      t.datetime :last_health_check_at
      t.text :last_health_error
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end
  end
end
