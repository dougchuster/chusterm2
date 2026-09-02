# Chave unica do lock consultivo por etapa do Kanban.
#
# Existe para que o backfill da F1.2 e o rebalanceamento da F1.3-a disputem a
# **mesma** chave: os dois renumeram uma coluna inteira, e rodar os dois juntos
# na mesma etapa produziria posicoes duplicadas em silencio. Uma constante
# copiada em dois arquivos seria exatamente o padrao que gerou a divida B-01.
module Crm::StageAdvisoryLock
  # Namespace nos bits altos, id da etapa nos baixos, dentro dos 64 bits que o
  # `pg_advisory_lock` aceita.
  NAMESPACE = 27_490
  STAGE_BITS = 40

  module_function

  def key_for(stage_id)
    (NAMESPACE << STAGE_BITS) | (stage_id.to_i & ((1 << STAGE_BITS) - 1))
  end

  # Nao bloqueante: quem nao pegou o lock desiste e tenta depois. Usado pelo
  # backfill, que roda no deploy e nao pode ficar pendurado.
  def try_lock(stage_id, connection: ActiveRecord::Base.connection)
    connection.select_value(
      ActiveRecord::Base.sanitize_sql_array(['SELECT pg_try_advisory_xact_lock(?)', key_for(stage_id)])
    )
  end

  # Bloqueante: usado pelo rebalanceamento, que atende um clique do atendente e
  # precisa terminar o servico.
  # `execute` e nao `select_value`: a funcao devolve void, e o adapter reclama
  # de OID desconhecido ao tentar tipar o resultado.
  def lock!(stage_id, connection: ActiveRecord::Base.connection)
    connection.execute(
      ActiveRecord::Base.sanitize_sql_array(['SELECT pg_advisory_xact_lock(?)', key_for(stage_id)])
    )
    true
  end
end
