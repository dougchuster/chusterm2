# F1.2 do PLANO-KANBAN-CRM-2026.md — dispara o backfill de `crm_deals.position`
# no deploy, seguindo o padrao de migracao de dados ja usado no repositorio
# (ver `20231219000743_re_run_cache_label_job.rb`).
#
# Enfileira em vez de rodar inline: em producao a tabela tem volume e a
# migracao nao pode segurar o deploy. O job e idempotente, entao reenfileirar a
# mao depois nao causa dano.
class BackfillCrmDealPositions < ActiveRecord::Migration[7.2]
  def up
    Crm::BackfillDealPositionsJob.perform_later
  end

  # Nao ha o que desfazer: `position` so ganhou valor onde estava NULL, e o
  # rollback de `20260828000001` derruba a coluna inteira. Zerar as posicoes
  # aqui destruiria a ordenacao que o atendente montou depois do backfill.
  def down; end
end
