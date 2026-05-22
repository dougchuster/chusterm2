class PreventDuplicateOpenCrmDealsPerContactPipeline < ActiveRecord::Migration[7.1]
  INDEX_NAME = 'idx_crm_deals_open_contact_pipeline_unique'

  def up
    archive_duplicate_open_deals

    add_index :crm_deals,
              [:account_id, :crm_pipeline_id, :contact_id],
              unique: true,
              where: "status = 'open' AND contact_id IS NOT NULL",
              name: INDEX_NAME,
              if_not_exists: true
  end

  def down
    remove_index :crm_deals, name: INDEX_NAME, if_exists: true
  end

  private

  def archive_duplicate_open_deals
    execute <<~SQL.squish
      WITH ranked_deals AS (
        SELECT
          crm_deals.id,
          ROW_NUMBER() OVER (
            PARTITION BY crm_deals.account_id, crm_deals.crm_pipeline_id, crm_deals.contact_id
            ORDER BY COALESCE(crm_pipeline_stages.position, 0) DESC, crm_deals.updated_at DESC, crm_deals.id DESC
          ) AS duplicate_rank
        FROM crm_deals
        LEFT JOIN crm_pipeline_stages ON crm_pipeline_stages.id = crm_deals.crm_pipeline_stage_id
        WHERE crm_deals.status = 'open'
          AND crm_deals.contact_id IS NOT NULL
      )
      UPDATE crm_deals
      SET
        status = 'archived',
        operational_status = 'duplicated',
        disposition_reason = 'duplicated',
        disposition_note = 'Arquivado automaticamente: lead aberto duplicado do mesmo contato no mesmo kanban.',
        archived_at = COALESCE(archived_at, CURRENT_TIMESTAMP),
        disposed_at = COALESCE(disposed_at, CURRENT_TIMESTAMP),
        closed_at = COALESCE(closed_at, CURRENT_TIMESTAMP),
        updated_at = CURRENT_TIMESTAMP
      WHERE id IN (
        SELECT id FROM ranked_deals WHERE duplicate_rank > 1
      )
    SQL
  end
end
