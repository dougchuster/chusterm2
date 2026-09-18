class AddTerminalOutcomeToCrmPipelineStages < ActiveRecord::Migration[7.1]
  WON_SLUGS = %w[fechamento ganho].freeze
  LOST_SLUGS = %w[perdido-arquivado perdido].freeze

  def up
    add_column :crm_pipeline_stages, :terminal_outcome, :string
    add_index :crm_pipeline_stages, %i[crm_pipeline_id terminal_outcome],
              name: 'idx_crm_stages_terminal_outcome'

    # D2: funis existentes (prod) ganham a etapa terminal pelo slug padrão —
    # mark_won!/mark_lost! passam a mover o card para a coluna certa.
    CrmPipelineStage.where(slug: WON_SLUGS).find_each { |stage| stage.update!(terminal_outcome: 'won') }
    CrmPipelineStage.where(slug: LOST_SLUGS).find_each { |stage| stage.update!(terminal_outcome: 'lost') }
  end

  def down
    remove_index :crm_pipeline_stages, name: 'idx_crm_stages_terminal_outcome'
    remove_column :crm_pipeline_stages, :terminal_outcome
  end
end
