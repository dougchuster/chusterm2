# F1.5 do PLANO-KANBAN-CRM-2026.md — quando o negocio entrou na etapa atual.
#
# Sem isso nao da para responder "tempo medio na etapa" (cabecalho de coluna da
# F2.3) nem "parado ha Xd" (rotting da F2.5). Derivar de `crm_audit_events` a
# cada pintada do board seria caro e so funcionaria para negocios que ja se
# moveram alguma vez.
#
# **Nao ha backfill de proposito.** A coluna nasce nula e toda leitura usa
# `COALESCE(stage_entered_at, created_at)`: para quem nunca se moveu, a data de
# criacao e a resposta certa. Isso evita um UPDATE em toda a tabela no deploy.
class AddStageEnteredAtToCrmDeals < ActiveRecord::Migration[7.2]
  def change
    add_column :crm_deals, :stage_entered_at, :datetime, null: true
  end
end
