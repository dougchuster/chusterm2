# F2.8 do PLANO-KANBAN-CRM-2026.md — agrupar o board por algo que nao seja a
# etapa.
#
# O board sempre soube desenhar colunas de etapa. Agrupar por responsavel, faixa
# de score, area ou origem e a mesma tela respondendo outra pergunta: "quem esta
# sobrecarregado", "onde esta o dinheiro", "de onde vem os bons".
#
# Duas decisoes que este servico carrega:
#
# 1. **So o agrupamento por etapa e movivel.** Arrastar um card entre colunas de
#    "faixa de score" nao tem o que persistir — score e calculado, nao escolhido.
#    Dizer isso no servidor evita o board oferecer um arrasto que nao salva nada.
# 2. **Area e origem saem dos dados, nao de constante.** O escritorio e full
#    service (regra de produto 9): uma lista fixa de areas presumiria os nichos
#    que ele atende hoje.
class Crm::BoardGrouping
  DEFAULT = 'stage'.freeze
  OPTIONS = %w[stage owner score_band legal_area source operational_status].freeze

  UNASSIGNED = '__unassigned'.freeze
  NONE = '__none'.freeze

  # As mesmas faixas que o filtro da F2.6 usa. Duas listas divergindo fariam o
  # board agrupar por uma regra e filtrar por outra.
  SCORE_BANDS = [
    { id: 'hot', name: 'Alta prioridade (80+)', min: 80 },
    { id: 'qualified', name: 'Qualificados (60–79)', min: 60, max: 79 },
    { id: 'medium', name: 'Médio potencial (40–59)', min: 40, max: 59 },
    { id: 'cold', name: 'Baixo potencial (até 39)', max: 39 }
  ].freeze

  attr_reader :group_by

  def self.for(group_by, pipeline:, account:)
    new(group_by: group_by, pipeline: pipeline, account: account)
  end

  def initialize(group_by:, pipeline:, account:)
    # Agrupamento desconhecido cai no padrao em vez de derrubar o board: o
    # cliente pode estar com uma visao salva de uma versao anterior.
    @group_by = OPTIONS.include?(group_by.to_s) ? group_by.to_s : DEFAULT
    @pipeline = pipeline
    @account = account
  end

  # Arrastar entre colunas so persiste quando a coluna e a etapa.
  def movable?
    group_by == DEFAULT
  end

  # A expressao SQL que devolve, para cada negocio, a coluna onde ele mora.
  def key_sql
    case group_by
    when 'owner' then "COALESCE(crm_deals.owner_id::text, '#{UNASSIGNED}')"
    when 'score_band' then score_band_sql
    when 'legal_area' then blank_safe('crm_deals.legal_area')
    when 'source' then blank_safe('crm_deals.source')
    when 'operational_status' then blank_safe('crm_deals.operational_status')
    else 'crm_deals.crm_pipeline_stage_id::text'
    end
  end

  # Chamado duas vezes por requisicao (uma para os cards, outra na resposta).
  # O objeto vive uma requisicao e nao muda dentro dela, entao a segunda
  # chamada nao precisa repetir a query de responsaveis, area ou etapas.
  def buckets
    @buckets ||= build_buckets
  end

  private

  def build_buckets
    case group_by
    when 'owner' then owner_buckets
    when 'score_band' then SCORE_BANDS.map { |band| band.slice(:id, :name) }
    when 'legal_area' then value_buckets(:legal_area)
    when 'source' then value_buckets(:source)
    when 'operational_status' then status_buckets
    else stage_buckets
    end
  end

  # Só a etapa carrega cor, teto de WIP e prazo — as outras colunas nao tem
  # equivalente, e inventar um faria o cabecalho mentir.
  def stage_buckets
    @pipeline.crm_pipeline_stages.active.ordered.map do |stage|
      {
        id: stage.id.to_s,
        stage_id: stage.id,
        name: stage.name,
        color: stage.color,
        wip_limit: stage.wip_limit,
        expected_duration_hours: stage.expected_duration_hours
      }
    end
  end

  def owner_buckets
    agents = @account.users.order(:name).map do |user|
      { id: user.id.to_s, name: user.name }
    end

    # "Sem responsavel" e coluna de verdade: e onde o trabalho nao atribuido se
    # acumula, e e a pergunta que o board precisa responder.
    agents + [{ id: UNASSIGNED, name: 'Sem responsável' }]
  end

  # Os valores vem dos dados da conta, e nao de uma constante: o escritorio e
  # full service e a lista de areas muda com o que ele atende.
  def value_buckets(column)
    values = @pipeline.crm_deals.distinct.pluck(column).map(&:presence)

    present = values.compact.sort.map { |value| { id: value, name: value } }
    return present unless values.include?(nil)

    present + [{ id: NONE, name: 'Não informado' }]
  end

  # Lista fechada no modelo: mostrar todas mantem a coluna vazia visivel, que e
  # informacao — "nenhum spam nesta semana" e uma resposta.
  def status_buckets
    CrmDeal::OPERATIONAL_STATUSES.map { |status| { id: status, name: status } }
  end

  def blank_safe(column)
    "COALESCE(NULLIF(#{column}, ''), '#{NONE}')"
  end

  def score_band_sql
    conditions = SCORE_BANDS.filter_map do |band|
      next if band[:min].blank?

      "WHEN crm_deals.score_total >= #{band[:min].to_i} THEN '#{band[:id]}'"
    end

    "CASE #{conditions.join(' ')} ELSE '#{SCORE_BANDS.last[:id]}' END"
  end
end
