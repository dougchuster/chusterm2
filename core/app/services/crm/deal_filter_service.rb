# PERF-04: filtro de deals extraído do DealsController para ser reutilizado
# pelo controller (index/bulk/export) e pelo Crm::DealsExportJob.
#
# F1.4 do PLANO-KANBAN-CRM-2026.md: os critérios do board passam a ser
# resolvidos aqui, no servidor. A lacuna K-01 era o board buscar todos os
# negócios do pipeline e filtrar em JavaScript — o que quebra por volta de mil
# negócios e força um re-render inteiro a cada filtro.
#
# Contrato: todo filtro de igualdade aceita valor único **ou** lista. Nada aqui
# assume que o cliente mandou um formato só, porque a barra de pills da F2.6
# manda listas e a query string antiga manda escalares.
module Crm
  class DealFilterService
    UNASSIGNED = '__unassigned'.freeze

    # As duas listas sao a **fonte de verdade** das chaves de filtro. O
    # controller nao mantem uma copia: ele pede a allowlist aqui. Copia foi
    # exatamente o que produziu o bug que a revisao da F1.4 pegou — o board
    # filtrava por duas dispositions, a exportacao descartava a chave inteira
    # em silencio porque a lista de la nao tinha sido atualizada junto.
    LIST_KEYS = %i[
      pipeline_id stage_id owner_id status operational_status source disposition_reason
      conversation_id contact_id inbox_id legal_area urgency urgency_level ai_mode label
    ].freeze

    SCALAR_KEYS = %i[
      score_min score_max value_min value_max created_after created_before
      stale has_pending_activity search q
    ].freeze

    # Aceita `ActionController::Parameters` (controller) ou Hash (job, spec).
    # Toda chave de lista e declarada nas duas formas porque a query string
    # antiga manda escalar e a barra de pills da F2.6 manda array.
    def self.permitted_filters(source)
      return {} if source.blank?
      return source.to_h.symbolize_keys unless source.respond_to?(:permit)

      source.permit(*SCALAR_KEYS, *LIST_KEYS, *LIST_KEYS.map { |key| { key => [] } }).to_h
    end

    def initialize(scope:, filters:, account: nil)
      @scope = scope
      @filters = normalize(filters)
      # Escopar as subconsultas por conta e defesa em profundidade, nao
      # correcao: os ids sao globais e o CrmDeal valida
      # `validates_same_account_for :contact, :conversation`, entao nao ha
      # vazamento hoje. Depender dessa invariante de outro modelo para nao vazar
      # e frágil, e a busca por etiqueta sem conta varre `taggings` de **todos**
      # os inquilinos.
      @account = account
    end

    def perform
      scope = filter_by_columns(@scope)
      scope = filter_by_owner(scope)
      scope = filter_by_ranges(scope)
      scope = filter_by_activity(scope)
      scope = filter_by_ai_mode(scope)
      scope = filter_by_labels(scope)
      filter_by_search(scope)
    end

    private

    def normalize(filters)
      raw = filters.respond_to?(:to_unsafe_h) ? filters.to_unsafe_h : filters
      ActiveSupport::HashWithIndifferentAccess.new(raw.presence || {})
    end

    # `where(coluna: valor)` aceita escalar e array sem ajuda, então a lista sai
    # de graça em todos estes.
    def filter_by_columns(scope)
      scope = scope.by_pipeline(@filters[:pipeline_id]) if list(:pipeline_id).present?
      scope = scope.by_stage(list(:stage_id)) if list(:stage_id).present?
      scope = scope.where(legal_area: expanded_legal_areas) if list(:legal_area).present?
      scope = scope.where(urgency_level: urgency) if urgency.present?

      %i[status operational_status source disposition_reason conversation_id contact_id inbox_id].each do |key|
        next if list(key).blank?

        scope = scope.where(key => list(key))
      end

      scope
    end

    # `__unassigned` é uma pseudo-opção da interface: "sem dono". Pode vir
    # sozinha ou misturada com donos reais, e no segundo caso as duas condições
    # são alternativas, não um `AND` que não devolveria nada.
    def filter_by_owner(scope)
      owners = list(:owner_id)
      return scope if owners.blank?

      unassigned = owners.any? { |value| value.to_s == UNASSIGNED }
      ids = owners.reject { |value| value.to_s == UNASSIGNED }

      return scope.where(owner_id: nil) if unassigned && ids.blank?
      return scope.where(owner_id: ids) unless unassigned

      scope.where(owner_id: ids).or(scope.where(owner_id: nil))
    end

    def filter_by_ranges(scope)
      scope = scope.where(score_total: ..integer(:score_max)) if integer(:score_max)
      scope = scope.where(score_total: integer(:score_min)..) if integer(:score_min)
      scope = scope.where(value_estimate_cents: ..integer(:value_max)) if integer(:value_max)
      scope = scope.where(value_estimate_cents: integer(:value_min)..) if integer(:value_min)
      scope = scope.where(created_at: parsed_time(:created_after)..) if parsed_time(:created_after)
      scope = scope.where(created_at: ..parsed_time(:created_before)) if parsed_time(:created_before)
      scope
    end

    # Numero ilegivel recebe o mesmo tratamento que data ilegivel: e ignorado.
    # `to_i` cego virava zero, e `score_max=abc` calava o board inteiro sem
    # avisar ninguem.
    def integer(key)
      @integers ||= {}
      return @integers[key] if @integers.key?(key)

      @integers[key] = Integer(@filters[key].to_s, exception: false)
    end

    # Data ilegível é filtro que o cliente errou, não intenção de esvaziar o
    # board. Ignorar é menos danoso do que devolver zero resultados sem explicar.
    def parsed_time(key)
      return @parsed_times[key] if defined?(@parsed_times) && @parsed_times.key?(key)

      @parsed_times ||= {}
      @parsed_times[key] = begin
        Time.zone.parse(@filters[key].to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end

    # `stale` e `has_pending_activity` sao os dois lados da mesma pergunta do
    # plano: "qual e a proxima acao e quando?". Aceitam `false` de proposito —
    # negocio aberto **sem** proxima acao e o estado mais alarmante do board.
    def filter_by_activity(scope)
      scope = apply_exists(scope, pending_activities, boolean(:has_pending_activity)) unless boolean(:has_pending_activity).nil?
      scope = apply_exists(scope, stale_activities, boolean(:stale)) unless boolean(:stale).nil?
      scope
    end

    # EXISTS correlacionado, e nao `id IN (subconsulta)`, por um motivo concreto:
    # `crm_activities.crm_deal_id` e anulavel (agenda avulsa nao tem negocio) e
    # `NOT IN` com um unico NULL na subconsulta devolve **zero linhas**. O board
    # inteiro sumiria ao pedir "sem proxima acao", sem erro nenhum. `NOT EXISTS`
    # nao tem esse buraco e ainda usa o indice `index_crm_activities_on_crm_deal_id`.
    def apply_exists(scope, relation, wanted)
      condition = relation.arel.exists
      scope.where(wanted ? condition : condition.not)
    end

    def pending_activities
      CrmActivity.pending.select(1).where('crm_activities.crm_deal_id = crm_deals.id')
    end

    # Rotting e a atividade de follow-up que o StaleDetectorJob cria sozinho —
    # follow-up criado por gente e trabalho agendado, nao abandono.
    def stale_activities
      pending_activities.where(kind: 'follow_up', created_by_type: 'system')
    end

    def filter_by_ai_mode(scope)
      modes = list(:ai_mode)
      return scope if modes.blank?

      # `conversation_id` é único por conta, então a subconsulta não precisa de
      # escopo de conta para não vazar: um negócio da conta A só casa com estado
      # de conversa da conta A.
      state = conversation_states.where(ai_mode: modes)
                                 .select(1)
                                 .where('captain_conversation_states.conversation_id = crm_deals.conversation_id')

      scope.where(state.arel.exists)
    end

    # Etiqueta não vive no negócio: o LegalLabelSync escreve na conversa e no
    # contato. Filtrar pelo negócio significa, então, "cuja conversa ou cujo
    # contato carrega a etiqueta".
    def filter_by_labels(scope)
      labels = list(:label)
      return scope if labels.blank?

      scope.where(
        'crm_deals.conversation_id IN (:conversations) OR crm_deals.contact_id IN (:contacts)',
        conversations: conversations_scope.tagged_with(labels, any: true).reselect(:id),
        contacts: contacts_scope.tagged_with(labels, any: true).reselect(:id)
      )
    end

    def filter_by_search(scope)
      return scope if search_term.blank?

      query = search_term.downcase.strip
      digits = query.gsub(/\D/, '')

      scope.left_joins(:contact).where(
        search_conditions(digits).join(' OR '),
        query: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%",
        digits: "%#{ActiveRecord::Base.sanitize_sql_like(digits)}%"
      )
    end

    def search_conditions(digits)
      conditions = [
        'LOWER(crm_deals.title) LIKE :query',
        'LOWER(COALESCE(crm_deals.legal_area, \'\')) LIKE :query',
        'LOWER(COALESCE(crm_deals.case_type, \'\')) LIKE :query',
        'LOWER(contacts.name) LIKE :query',
        'LOWER(contacts.email) LIKE :query'
      ]
      return conditions if digits.blank?

      conditions << "regexp_replace(COALESCE(contacts.phone_number, ''), '[^0-9]', '', 'g') LIKE :digits"
    end

    # `q` é o nome curto que a barra de busca do board usa; `search` é o nome
    # antigo, que a exportação e a query string existente continuam mandando.
    def search_term
      @search_term ||= (@filters[:search].presence || @filters[:q]).to_s
    end

    def urgency
      @urgency ||= list(:urgency).presence || list(:urgency_level)
    end

    def expanded_legal_areas
      list(:legal_area).flat_map { |area| Crm::DomainOptions.equivalent_legal_areas(area) }.uniq
    end

    def conversation_states
      @account&.captain_conversation_states || CaptainConversationState
    end

    def conversations_scope
      @account&.conversations || Conversation
    end

    def contacts_scope
      @account&.contacts || Contact
    end

    def boolean(key)
      ActiveModel::Type::Boolean.new.cast(@filters[key])
    end

    def list(key)
      Array.wrap(@filters[key]).compact_blank
    end
  end
end
