class CreateCaptainFlows < ActiveRecord::Migration[7.1]
  def change
    create_table :captain_flows do |t|
      t.references :account, null: false, foreign_key: true
      t.references :captain_assistant, null: true, foreign_key: { to_table: :captain_assistants }
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :status, null: false, default: 'draft'
      t.integer :version, null: false, default: 1
      t.datetime :published_at

      t.timestamps
    end

    add_index :captain_flows, [:account_id, :slug], unique: true
    add_index :captain_flows, :status
  end
end
