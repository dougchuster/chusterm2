# F1.3 do PLANO-KANBAN-CRM-2026.md — quem decide a posicao de um card e o
# servidor, nao o navegador. O cliente manda apenas entre quais vizinhos o card
# caiu; assim dois atendentes arrastando ao mesmo tempo nao gravam a mesma
# posicao a partir de estados de tela diferentes.
#
# Convencao dos parametros — le-se "coloque depois de A e antes de B":
#   after_id  -> o negocio que fica **acima** do card movido (posicao menor)
#   before_id -> o negocio que fica **abaixo** (posicao maior)
#
# Basta um dos dois: o outro vizinho e descoberto no banco. Sem nenhum, o card
# vai para o topo da coluna, que e onde o board de hoje (ordenado por
# `created_at DESC`) ja colocaria um negocio recem-chegado.
class Crm::DealPositioner
  GAP = BigDecimal(1_000)

  # Abaixo deste intervalo entre vizinhos nao ha mais bisseccao util: com escala
  # 10, o ponto medio comecaria a arredondar para um valor ja existente e, como
  # `position` nao tem indice unico, a colisao seria silenciosa — o atendente
  # simplesmente perderia a capacidade de reordenar naquele ponto da fila.
  REBALANCE_THRESHOLD = BigDecimal('0.001')

  def initialize(stage:, before_id: nil, after_id: nil, excluding_id: nil)
    @stage = stage
    @before_id = before_id.presence
    @after_id = after_id.presence
    # O proprio negocio que esta sendo movido nao pode contar como vizinho de si
    # mesmo: se ele e o unico card posicionado da coluna, sem essa exclusao cada
    # reordenacao dividiria a posicao dele pela metade sem motivo.
    @excluding_id = excluding_id
  end

  def call
    position = compute
    return position unless position.nil?

    rebalance!
    compute_after_rebalance
  end

  private

  attr_reader :stage

  def compute
    low, high = bounds
    midpoint(low, high)
  end

  def compute_after_rebalance
    reset_neighbours!
    low, high = bounds
    result = midpoint(low, high)
    raise "Nao foi possivel posicionar o negocio na etapa #{stage.id} nem apos o rebalanceamento" if result.nil?

    result
  end

  # Devolve o par (limite inferior, limite superior). `nil` no limite superior
  # significa "o card vai para o fim da coluna". O limite inferior `nil` so
  # aparece em coluna vazia ou quando o card vai para o topo — nos dois casos a
  # posicao anda um gap inteiro em vez de bisseccionar.
  #
  # Os vizinhos que o cliente reporta sao um retrato da tela dele, que pode ter
  # segundos de atraso. Se entraram cards entre os dois desde entao, confiar no
  # par informado grava todo mundo no mesmo ponto medio — duplicata silenciosa,
  # porque `position` nao tem indice unico. Por isso o teto e o **menor** entre
  # o vizinho informado e o vizinho real: o card cai logo abaixo da ancora que
  # o atendente mirou, e nunca em cima de ninguem.
  def bounds
    validate_order!

    return [nil, stage_deals.minimum(:position)] if after_deal.nil? && before_deal.nil?

    [
      after_deal&.position || previous_position_of(before_deal),
      [before_deal&.position, next_position_of(after_deal)].compact.min
    ]
  end

  # Devolve `nil` quando o intervalo entre dois vizinhos acabou — o chamador
  # rebalanceia e tenta de novo.
  #
  # Topo e fundo da coluna nunca bisseccionam: andam um gap inteiro. Bisseccionar
  # o topo (dividir o minimo por dois a cada insercao) parece inofensivo, mas
  # esgota a escala em ~20 movimentos — e um "mover em massa" de 100 negocios
  # para a mesma etapa disparava 4 rebalanceamentos de coluna inteira dentro de
  # uma requisicao HTTP. Andar um gap cheio nunca perde precisao. A posicao pode
  # ficar negativa, e tudo bem: a coluna nao tem piso, e o rebalanceamento
  # devolve todo mundo para o positivo quando de fato precisar acontecer.
  def midpoint(low, high)
    return GAP if low.nil? && high.nil?
    return low + GAP if high.nil?
    return high - GAP if low.nil?
    return nil if (high - low) < REBALANCE_THRESHOLD

    (low + high) / 2
  end

  def previous_position_of(deal)
    return nil if deal.nil?

    stage_deals.where(position: ...deal.position).maximum(:position)
  end

  def next_position_of(deal)
    return nil if deal.nil?

    stage_deals.where('position > ?', deal.position).minimum(:position)
  end

  # Posicoes iguais nao sao erro de cliente: sao duplicatas que ja existem na
  # coluna (`position` nao tem indice unico). Deixa passar, para o intervalo
  # zero cair no rebalanceamento — que e o conserto certo.
  def validate_order!
    return if after_deal.nil? || before_deal.nil?
    return if after_deal.position <= before_deal.position

    raise ArgumentError, 'Vizinhos informados na ordem errada: after_id precisa estar acima de before_id'
  end

  def after_deal
    return @after_deal if defined?(@after_deal)

    @after_deal = find_neighbour(@after_id)
  end

  def before_deal
    return @before_deal if defined?(@before_deal)

    @before_deal = find_neighbour(@before_id)
  end

  def reset_neighbours!
    remove_instance_variable(:@after_deal) if defined?(@after_deal)
    remove_instance_variable(:@before_deal) if defined?(@before_deal)
  end

  # Vizinho que sumiu (foi movido, arquivado, apagado) nao e erro: o cliente
  # estava com a tela de um segundo atras. Vizinho de outra coluna e erro, e
  # denuncia bug de cliente.
  def find_neighbour(id)
    return nil if id.nil?
    # O card movido nao e vizinho de si mesmo. `stage_deals` ja garante isso nas
    # buscas por posicao; sem repetir aqui, um cliente que mandasse o proprio id
    # como vizinho furaria o invariante que a classe declara.
    return nil if @excluding_id && id.to_s == @excluding_id.to_s

    deal = stage.account.crm_deals.find_by(id: id)
    return nil if deal.nil? || deal.position.nil?

    raise ArgumentError, "O negocio #{deal.id} nao pertence a etapa #{stage.id}" unless deal.crm_pipeline_stage_id == stage.id

    deal
  end

  def stage_deals
    scope = stage.crm_deals.where.not(position: nil)
    @excluding_id ? scope.where.not(id: @excluding_id) : scope
  end

  # F1.3-a. Renumera a etapa inteira preservando a ordem atual, em SQL cru pelo
  # mesmo motivo do backfill: nenhum atendente precisa ver 200 eventos de
  # realtime porque o vizinho de alguem foi renumerado.
  def rebalance!
    ActiveRecord::Base.transaction do
      Crm::StageAdvisoryLock.lock!(stage.id)
      CrmDeal.connection.exec_update(
        CrmDeal.sanitize_sql_array([REBALANCE_SQL, stage.id, GAP.to_i, stage.id])
      )
    end
  end

  REBALANCE_SQL = <<~SQL.squish.freeze
    WITH ordered AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY position ASC, created_at DESC, id DESC) AS rn
      FROM crm_deals
      WHERE crm_pipeline_stage_id = ?
        AND position IS NOT NULL
    )
    UPDATE crm_deals
    SET position = ordered.rn * ?
    FROM ordered
    WHERE crm_deals.id = ordered.id
      AND crm_deals.crm_pipeline_stage_id = ?
  SQL
end
