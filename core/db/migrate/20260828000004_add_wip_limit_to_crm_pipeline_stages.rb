# F1.5 do PLANO-KANBAN-CRM-2026.md — teto de trabalho em andamento por etapa.
#
# Nulo significa "sem teto", que e o comportamento de hoje e continua sendo o
# padrao. Coluna anulavel sem default nao reescreve a tabela no PostgreSQL.
class AddWipLimitToCrmPipelineStages < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_pipeline_stages, :wip_limit, :integer, null: true
  end
end
