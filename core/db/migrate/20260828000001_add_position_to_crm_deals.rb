class AddPositionToCrmDeals < ActiveRecord::Migration[7.2]
  # F1.1 do PLANO-KANBAN-CRM-2026.md — ordenacao dentro da coluna do Kanban.
  #
  # `decimal(20,10)` permite ordenacao fracionaria (estilo LexoRank): inserir
  # entre A e B e gravar (A+B)/2, sem reescrever o resto da coluna. Com escala
  # 10 cabem ~33 divisoes sucessivas no mesmo ponto antes de esgotar a precisao.
  #
  # A coluna nasce NULL de proposito: o backfill (F1.2) roda em lotes, por job,
  # e so depois disso faz sentido discutir NOT NULL. Adicionar uma coluna
  # anulavel sem default nao reescreve a tabela no PostgreSQL.
  def change
    add_column :crm_deals, :position, :decimal, precision: 20, scale: 10, null: true
  end
end
