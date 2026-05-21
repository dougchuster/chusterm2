class AddInboxToCrmPipelines < ActiveRecord::Migration[7.0]
  def change
    add_reference :crm_pipelines, :inbox, null: true, foreign_key: { on_delete: :nullify }
    add_index :crm_pipelines,
              [:account_id, :inbox_id],
              unique: true,
              where: 'inbox_id IS NOT NULL',
              name: 'idx_crm_pipelines_account_inbox_unique'
    add_index :crm_deals, :inbox_id unless index_exists?(:crm_deals, :inbox_id)
  end
end
