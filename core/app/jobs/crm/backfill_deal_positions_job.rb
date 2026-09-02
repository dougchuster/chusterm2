# F1.2 do PLANO-KANBAN-CRM-2026.md — preenche `crm_deals.position`, que nasceu
# NULL na F1.1, em lotes e por etapa.
#
# Ordem: ROW_NUMBER() * 1000 sobre `created_at DESC`, que e exatamente a ordem
# que o board ja renderiza hoje (`DealsController#index` faz
# `order(created_at: :desc)`). O gap de 1000 sustenta ~43 bisseccoes antes de a
# F1.3 precisar reequilibrar a coluna.
#
# Tres invariantes governam o desenho:
#
# 1. **O backfill nao muda o que o atendente ve.** Negocio que ja tem `position`
#    foi colocado ali por alguem — nao se mexe. Negocio sem `position` o board ja
#    joga para o fim da coluna (`NULLS LAST`), entao ele entra *abaixo* do maior
#    valor existente na etapa. Numa etapa inteiramente NULL, que e o caso do
#    primeiro run real, o maior valor e zero e o resultado e o `ROW_NUMBER() *
#    1000` puro do plano.
# 2. **Rodar de novo nao estraga nada.** So linhas NULL sao tocadas, e duas
#    execucoes simultaneas na mesma etapa nao se atropelam (lock consultivo).
# 3. **O backfill nao entra no barramento de realtime.** O UPDATE e SQL cru de
#    proposito: `update_all`/`save` passariam pelo `after_update_commit
#    :dispatch_updated_event` do CrmDeal e despejariam um evento por negocio —
#    5.000 eventos para uma mudanca que nenhum atendente precisa ver acontecer.
class Crm::BackfillDealPositionsJob < ApplicationJob
  queue_as :async_database_migration

  DEFAULT_BATCH_SIZE = 1_000
  POSITION_GAP = 1_000


  # `id DESC` desempata `created_at` identico. Sem ele, dois negocios criados no
  # mesmo instante ganhariam ordem arbitraria a cada run — e o job deixaria de
  # ser deterministico.
  #
  # ROW_NUMBER() e calculado sobre todo o conjunto NULL da etapa e so depois o
  # LIMIT corta; como o ORDER BY externo repete o da janela, o lote recebe
  # sempre rn = 1..batch_size.
  #
  # O WHERE do UPDATE **repete** o predicado do CTE (`position IS NULL` e a
  # etapa). O CTE enxerga o snapshot do inicio do statement; se, entre esse
  # snapshot e a escrita, alguem mover o card ou gravar uma posicao, o
  # READ COMMITTED do Postgres reavalia o WHERE do UPDATE contra a versao nova
  # da linha e a descarta. Sem essa repeticao, o backfill sobrescreveria em
  # silencio a posicao escolhida por um atendente — quebrando a invariante 1.
  BATCH_SQL = <<~SQL.squish.freeze
    WITH ordered AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY created_at DESC, id DESC) AS rn
      FROM crm_deals
      WHERE crm_pipeline_stage_id = ?
        AND position IS NULL
      ORDER BY created_at DESC, id DESC
      LIMIT ?
    )
    UPDATE crm_deals
    SET position = ? + ordered.rn * ?
    FROM ordered
    WHERE crm_deals.id = ordered.id
      AND crm_deals.position IS NULL
      AND crm_deals.crm_pipeline_stage_id = ?
  SQL

  # Devolve quantos negocios foram posicionados, para o log e para o relatorio
  # de execucao.
  def perform(account_id: nil, batch_size: DEFAULT_BATCH_SIZE)
    size = [batch_size.to_i, 1].max

    pending_stage_ids(account_id).sum { |stage_id| backfill_stage(stage_id, size) }
  end

  # Publico para o spec: a chave precisa ser reproduzivel de fora para simular
  # uma execucao concorrente. A chave e compartilhada com o rebalanceamento da
  # F1.3-a — os dois renumeram a coluna inteira e nao podem rodar juntos.
  def advisory_lock_key(stage_id)
    Crm::StageAdvisoryLock.key_for(stage_id)
  end

  private

  def pending_stage_ids(account_id)
    scope = CrmDeal.where(position: nil)
    scope = scope.where(account_id: account_id) if account_id.present?
    scope.distinct.pluck(:crm_pipeline_stage_id)
  end

  def backfill_stage(stage_id, batch_size)
    positioned = 0

    loop do
      updated = position_next_batch(stage_id, batch_size)

      # nil = outra execucao esta cuidando desta etapa agora. Nao ha o que
      # esperar: o job e idempotente e a outra execucao termina o servico.
      if updated.nil?
        Rails.logger.info("[Crm::BackfillDealPositionsJob] etapa #{stage_id} ja esta sendo posicionada por outra execucao; pulando")
        break
      end

      break if updated.zero?

      positioned += updated
    end

    positioned
  end

  # Um lote por transacao. `base` e o UPDATE precisam da mesma transacao e do
  # mesmo lock: lidos separadamente, duas execucoes concorrentes veriam o mesmo
  # `base` (nenhuma commitou ainda) e gravariam posicoes duplicadas na etapa.
  #
  # O lock e `try` e nao bloqueante de proposito — isto roda no deploy, e um job
  # que fica pendurado esperando lock e pior do que um job que sai e volta.
  def position_next_batch(stage_id, batch_size)
    CrmDeal.transaction do
      next nil unless stage_lock_acquired?(stage_id)

      base = CrmDeal.where(crm_pipeline_stage_id: stage_id).maximum(:position) || 0

      CrmDeal.connection.exec_update(batch_sql(stage_id, batch_size, base))
    end
  end

  def stage_lock_acquired?(stage_id)
    Crm::StageAdvisoryLock.try_lock(stage_id, connection: CrmDeal.connection)
  end

  # Monta o statement do lote. Ver BATCH_SQL para o porque de cada clausula.
  def batch_sql(stage_id, batch_size, base)
    CrmDeal.sanitize_sql_array([BATCH_SQL, stage_id, batch_size, base, POSITION_GAP, stage_id])
  end
end
