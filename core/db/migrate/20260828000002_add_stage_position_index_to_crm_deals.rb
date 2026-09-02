class AddStagePositionIndexToCrmDeals < ActiveRecord::Migration[7.2]
  # Indice composto que serve a consulta do board: "os negocios desta etapa, na
  # ordem da coluna". `crm_pipeline_stage_id` ja implica a conta (a etapa
  # pertence a um pipeline, que pertence a uma conta), entao incluir
  # `account_id` so inflaria o indice sem ganho de seletividade.
  #
  # Vai concurrently para nao travar escrita em producao — mesma convencao dos
  # outros indices deste repositorio.
  disable_ddl_transaction!

  INDEX_NAME = 'index_crm_deals_on_stage_and_position'.freeze

  # `up`/`down` explicitos em vez de `change` por dois motivos, os dois
  # relevantes para producao:
  #
  # 1. `CREATE INDEX CONCURRENTLY` interrompido deixa no Postgres um indice
  #    INVALID com o mesmo nome. `if_not_exists: true` olha so o nome, nao a
  #    validade — uma segunda tentativa reportaria sucesso e deixaria o indice
  #    quebrado em producao, invisivel para o planner. Derrubamos o invalido
  #    antes de recriar.
  # 2. O `change` inverteria `add_index` reusando `if_not_exists: true`, opcao
  #    que `remove_index` ignora. Depois de uma criacao parcialmente falha o
  #    rollback estouraria `PG::UndefinedObject`. O `down` usa `if_exists`.
  def up
    drop_invalid_index!

    add_index :crm_deals,
              [:crm_pipeline_stage_id, :position],
              name: INDEX_NAME,
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :crm_deals,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
  end

  private

  def drop_invalid_index!
    return if select_value(invalid_index_query).blank?

    say "Indice #{INDEX_NAME} existe mas esta INVALID (criacao concorrente interrompida); derrubando antes de recriar."
    execute "DROP INDEX CONCURRENTLY IF EXISTS #{connection.quote_table_name(INDEX_NAME)}"
  end

  def invalid_index_query
    <<~SQL.squish
      SELECT 1
      FROM pg_index i
      JOIN pg_class c ON c.oid = i.indexrelid
      WHERE c.relname = #{connection.quote(INDEX_NAME)}
        AND NOT i.indisvalid
    SQL
  end
end
