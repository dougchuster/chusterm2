class MakeCaptainHandoffRequestDriven < ActiveRecord::Migration[7.0]
  def up
    change_column_default :captain_inboxes, :handoff_strategy, from: 'human_request_or_score', to: 'human_request'
    execute <<~SQL.squish
      UPDATE captain_inboxes
      SET handoff_strategy = 'human_request'
      WHERE handoff_strategy IN ('human_request_or_score', 'score_threshold')
    SQL

    execute <<~SQL.squish if column_exists?(:campaigns, :scoring_config)
      UPDATE campaigns
      SET scoring_config = COALESCE(scoring_config, '{}'::jsonb) || '{"auto_move_on_score": false}'::jsonb
      WHERE COALESCE((scoring_config ->> 'auto_move_on_score')::boolean, false) = true
    SQL

    execute <<~SQL.squish if column_exists?(:crm_pipelines, :scoring_config)
      UPDATE crm_pipelines
      SET scoring_config = COALESCE(scoring_config, '{}'::jsonb) || '{"auto_move_on_score": false}'::jsonb
      WHERE COALESCE((scoring_config ->> 'auto_move_on_score')::boolean, false) = true
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'The previous handoff/scoring values cannot be reconstructed; restore the pre-deploy database backup.'
  end
end
