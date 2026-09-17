class Api::V1::Accounts::Crm::DealsController < Api::V1::Accounts::Crm::BaseController
  before_action :deal, only: [:show, :update, :destroy, :move, :mark_won, :mark_lost, :reopen,
                              :archive, :discard, :mark_base_client]

  def index
    authorize CrmDeal, :index?

    scope = filtered_deals(Current.account.crm_deals)
           .order(Arel.sql(index_order))
           .includes(*DEAL_INCLUDES)

    total = scope.count
    per_page = bounded(params[:per_page], default: 50, max: 200)
    page = [params[:page].to_i, 1].max
    deals = scope.offset((page - 1) * per_page).limit(per_page).to_a

    render json: {
      data: serialize_board_deals(deals),
      meta: { total: total, page: page, per_page: per_page, total_pages: (total.to_f / per_page).ceil }
    }
  end

  # F1.5 do PLANO-KANBAN-CRM-2026.md — o board inteiro numa requisicao.
  #
  # Fica no DealsController, e nao no PipelinesController, porque a coluna
  # devolve **cards**: reusar `serialize_deal` e os mapas agregados aqui custa
  # zero, e move-los para outro lugar seria um refactor de 300 linhas no
  # serializador de um sistema em producao. A rota continua sendo
  # `/crm/pipelines/:pipeline_id/board`, como o plano pede.
  def board
    authorize CrmDeal, :index?

    pipeline = Current.account.crm_pipelines.find(params[:pipeline_id] || params[:id])
    grouping = Crm::BoardGrouping.for(params[:group_by], pipeline: pipeline, account: Current.account)
    scope = filtered_deals(pipeline.crm_deals)
    per_column = bounded(params[:per_column], default: 25, max: 100)

    aggregates = column_aggregates(scope, grouping)
    cards = column_cards(scope, grouping, per_column)
    serialized = serialize_grouped_cards(cards)

    render json: {
      pipeline: { id: pipeline.id, name: pipeline.name, slug: pipeline.slug, kind: pipeline.kind },
      columns: grouping.buckets.map do |bucket|
        serialize_column(bucket, aggregates[bucket[:id]], serialized[bucket[:id]])
      end,
      meta: {
        per_column: per_column,
        group_by: grouping.group_by,
        # O board so oferece arrasto quando ha o que persistir: mover entre
        # faixas de score nao salva nada, porque score e calculado.
        movable: grouping.movable?
      }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Pipeline not found' }, status: :not_found
  end

  def show
    authorize @deal, :show?

    render json: serialize_deal(@deal, detailed: true)
  end

  def create
    authorize CrmDeal, :create?

    deal = Crm::DealCreator.new(account: Current.account, params: deal_params, actor: Current.user).perform
    render json: serialize_deal(deal), status: :created
  rescue ActiveRecord::RecordNotFound
    render_conversation_not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @deal, :update?

    attributes = deal_update_params
    resolve_account_scoped_ids!(attributes, contact_id: :contacts, owner_id: :users, assignee_id: :users)
    resolve_conversation_id!(attributes)
    before_lgpd = @deal.slice(*CrmDeal::LGPD_FIELDS)
    @deal.update!(attributes)
    changes = audited_changes(@deal, attributes.keys)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'deal_updated',
      target: @deal,
      payload: { changes: changes }
    )
    log_lgpd_update(before_lgpd, @deal) if lgpd_changed?(changes)
    render json: serialize_deal(@deal)
  rescue ActiveRecord::RecordNotFound
    render_conversation_not_found
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    authorize @deal, :destroy?

    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'deal_destroyed', target: @deal)
    @deal.destroy!
    head :no_content
  end

  def move
    authorize @deal, :move?

    stage = Current.account.crm_pipeline_stages.find(params[:stage_id])
    # F1.3: o cliente reporta entre quais vizinhos o card caiu; quem calcula a
    # posicao e o servidor (Crm::DealPositioner), para que dois atendentes
    # arrastando ao mesmo tempo nao gravem o mesmo numero.
    Crm::DealMover.new(
      deal: @deal,
      stage_id: stage.id,
      actor: Current.user,
      before_id: params[:before_id],
      after_id: params[:after_id]
    ).perform
    render json: serialize_deal(@deal.reload)
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Stage not found' }, status: :not_found
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def mark_won
    authorize @deal, :mark_won?

    @deal.mark_won!(actor: Current.user)
    render json: serialize_deal(@deal.reload)
  end

  def mark_lost
    authorize @deal, :mark_lost?

    loss_reason = Current.account.crm_loss_reasons.active.find_by(id: params[:loss_reason_id])
    return render(
      json: { error: 'Selecione um motivo de perda válido.' },
      status: :unprocessable_entity
    ) unless loss_reason

    @deal.mark_lost!(
      loss_reason_id: loss_reason.id,
      note: params[:note],
      actor: Current.user
    )
    render json: serialize_deal(@deal.reload)
  end

  def reopen
    authorize @deal, :reopen?

    @deal.reopen!(actor: Current.user)
    render json: serialize_deal(@deal.reload)
  end

  def archive
    authorize @deal, :update?

    @deal.archive!(
      reason: params[:reason].presence || 'arquivado',
      note: params[:note],
      operational_status: params[:operational_status].presence || 'archived',
      actor: Current.user
    )
    render json: serialize_deal(@deal.reload)
  end

  def discard
    authorize @deal, :update?

    reason = normalized_disposition_reason(params[:reason] || params[:disposition_reason])
    @deal.discard!(reason: reason, note: params[:note], actor: Current.user)
    render json: serialize_deal(@deal.reload)
  end

  def mark_base_client
    authorize @deal, :update?

    @deal.mark_base_client!(note: params[:note], actor: Current.user)
    render json: serialize_deal(@deal.reload)
  end

  def bulk_action
    authorize CrmDeal, bulk_destroy_requested? ? :destroy? : :update?

    return render json: { error: 'Ação em lote inválida.' }, status: :unprocessable_entity if requested_bulk_action.blank?

    deals = bulk_deals_scope
    requested_count = select_all_requested? ? deals.count : Array(params[:deal_ids]).compact_blank.size
    return render json: { error: 'Nenhum lead selecionado.' }, status: :unprocessable_entity if requested_count.zero?

    result = { requested: requested_count, processed: 0, failed: [] }

    deals.find_each do |deal|
      process_bulk_deal!(deal)
      result[:processed] += 1
    rescue StandardError => e
      result[:failed] << { id: deal.id, error: e.message }
    end

    render json: result
  end

  def purge_orphans
    authorize CrmDeal, :destroy?

    orphan_deals = Current.account.crm_deals
                         .where.not(conversation_id: nil)
                         .where.not(conversation_id: Current.account.conversations.select(:id))

    count = orphan_deals.count
    if count.zero?
      render json: { message: 'Nenhum deal orfao encontrado.', purged: 0 }
      return
    end

    orphan_deals.find_each do |deal|
      Crm::AuditLogger.log(
        account: Current.account,
        actor: Current.user,
        action: 'deal_orphan_purged',
        target: deal,
        payload: { conversation_id: deal.conversation_id }
      )
      deal.destroy!
    end

    render json: { message: "#{count} deal(s) orfao(s) removido(s).", purged: count }
  end

  # PERF-04: export roda em job (não segura worker Puma); o link chega por email.
  def export
    authorize CrmDeal, :export?

    Crm::DealsExportJob.perform_later(Current.account.id, Current.user.id, export_filter_params)

    render json: {
      message: 'Exportação em processamento. Você receberá um email com o link para download.'
    }, status: :accepted
  end

  private

  DEAL_INCLUDES = [
    :crm_pipeline, :crm_pipeline_stage, :crm_loss_reason, :crm_lead_scores,
    :contact, :inbox, :conversation
  ].freeze

  # A coluna ordena por `position`; quem o backfill da F1.2 ainda nao alcancou
  # cai no fim, que e onde o board ja o mostrava.
  BOARD_ORDER = 'crm_deals.position ASC NULLS LAST, crm_deals.created_at DESC'.freeze

  # F1.6 do PLANO-KANBAN-CRM-2026.md — rolar dentro da coluna.
  #
  # O board (F1.5) manda os primeiros 25 de cada coluna; o resto vem por aqui.
  # Sem `order=board`, a pagina 2 volta a ordenar por data e devolve cards que a
  # coluna ja mostrou — medido: pedir a pagina 2 de uma coluna de 30 devolvia
  # cinco cards repetidos da pagina 1.
  #
  # O padrao continua sendo o mais recente primeiro: `AllLeads`, a exportacao e a
  # query string existente dependem disso, e trocar o padrao nao e trabalho desta
  # fase. Ordenacao desconhecida cai no padrao em vez de derrubar a requisicao.
  INDEX_ORDERS = {
    'board' => BOARD_ORDER,
    'recent' => 'crm_deals.created_at DESC'
  }.freeze

  def index_order
    INDEX_ORDERS.fetch(params[:order].to_s, INDEX_ORDERS.fetch('recent'))
  end

  def bounded(value, default:, max:)
    parsed = value.to_i
    parsed.positive? ? [parsed, max].min : default
  end

  # PERF-01: os quatro mapas agregados que o card precisa, numa query cada, em
  # vez de uma por negocio. Extraido do `index` para servir tambem ao `board`.
  def serialize_board_deals(deals)
    return [] if deals.blank?

    ids = deals.map(&:id)
    pending_counts = CrmActivity.pending.where(crm_deal_id: ids).group(:crm_deal_id).count
    stale_ids = CrmActivity.pending
                           .where(crm_deal_id: ids, kind: 'follow_up', created_by_type: 'system')
                           .distinct.pluck(:crm_deal_id).to_set
    next_due = CrmActivity.pending
                          .where(crm_deal_id: ids).where.not(due_at: nil)
                          .group(:crm_deal_id).minimum(:due_at)
    ai_states = Current.account.captain_conversation_states
                              .where(conversation_id: deals.filter_map(&:conversation_id))
                              .index_by(&:conversation_id)

    deals.map do |deal|
      serialize_deal(
        deal,
        pending_activities_count: pending_counts.fetch(deal.id, 0),
        is_stale: stale_ids.include?(deal.id),
        next_activity_due_at: next_due[deal.id],
        ai_state: ai_states[deal.conversation_id]
      )
    end
  end

  # Uma query para todas as colunas, qualquer que seja o agrupamento (F2.8).
  #
  # `count` acompanha os cards que a coluna mostra, para o cabecalho nao mentir.
  # Mas **WIP e idade sao so dos negocios abertos**, e isso nao e detalhe:
  # `mark_won!`/`mark_lost!` nao tiram o card da etapa, entao um negocio ganho ha
  # tres meses continua morando em "Qualificado". Conta-lo como trabalho em
  # andamento faz o teto de WIP disparar sozinho e o tempo medio virar ficcao.
  def column_aggregates(scope, grouping)
    key = Arel.sql(grouping.key_sql)

    scope.group(key)
         .pluck(
           key,
           Arel.sql('COUNT(*)'),
           Arel.sql("COUNT(*) FILTER (WHERE crm_deals.status = 'open')"),
           Arel.sql('COALESCE(SUM(value_estimate_cents), 0)'),
           Arel.sql(
             'AVG(EXTRACT(EPOCH FROM (NOW() - COALESCE(stage_entered_at, crm_deals.created_at))) / 86400.0) ' \
             "FILTER (WHERE crm_deals.status = 'open')"
           )
         )
         .to_h do |bucket, count, open_count, sum, avg|
           [bucket.to_s, { count: count, open_count: open_count, sum: sum, avg: avg }]
         end
  end

  # Duas etapas de proposito. A primeira pega **so os ids** de cada coluna. A
  # segunda carrega todos os cards do board de uma vez.
  #
  # Fazer `.includes(*DEAL_INCLUDES)` dentro do laco por coluna parecia "uma
  # query por coluna", mas cada preload dispara uma query propria — medido: 35
  # queries por requisicao contra 23 assim.
  def column_cards(scope, grouping, per_column)
    ids_by_bucket = grouping.buckets.index_by { |bucket| bucket[:id] }.transform_values do |bucket|
      scope.where("#{grouping.key_sql} = ?", bucket[:id])
           .order(Arel.sql(BOARD_ORDER))
           .limit(per_column)
           .pluck(:id)
    end

    loaded = CrmDeal.where(id: ids_by_bucket.values.flatten)
                    .includes(*DEAL_INCLUDES)
                    .index_by(&:id)

    ids_by_bucket.transform_values { |ids| ids.filter_map { |id| loaded[id] } }
  end

  # Serializa uma vez so, e devolve agrupado pela coluna a que cada card
  # pertence — o serializador nao sabe de agrupamento.
  def serialize_grouped_cards(cards_by_bucket)
    flat = cards_by_bucket.values.flatten
    serialized = serialize_board_deals(flat).index_by { |card| card[:id] }

    cards_by_bucket.transform_values do |deals|
      deals.filter_map { |deal| serialized[deal.id] }
    end
  end

  # A coluna fala a mesma lingua qualquer que seja o agrupamento: o
  # `CRMBoardColumn` do front nao muda. Cor, teto de WIP e prazo so existem
  # quando a coluna e uma etapa — nas outras vem nulos, e o cabecalho
  # simplesmente nao os desenha.
  def serialize_column(bucket, aggregate, cards)
    count = aggregate&.fetch(:count) || 0
    open_count = aggregate&.fetch(:open_count) || 0

    {
      id: bucket[:id],
      # Nulo em qualquer agrupamento que nao seja por etapa: e o que impede o
      # front de tentar mover ou paginar uma coluna que nao e uma etapa.
      stage_id: bucket[:stage_id],
      name: bucket[:name],
      color: bucket[:color],
      expected_duration_hours: bucket[:expected_duration_hours],
      count: count,
      open_count: open_count,
      sum_value_cents: aggregate ? aggregate.fetch(:sum).to_i : 0,
      avg_days_in_stage: aggregate&.fetch(:avg)&.to_f&.round(2),
      wip_limit: bucket[:wip_limit],
      over_wip: bucket[:wip_limit].present? && open_count > bucket[:wip_limit],
      deals: cards || []
    }
  end

  def deal
    @deal = Current.account.crm_deals.find(params[:id])
  end

  def deal_params
    sanitize_custom_fields(
      params.permit(:title, :contact_id, :conversation_id, :inbox_id, :team_id, :owner_id,
                    :assignee_id, :crm_pipeline_id, :crm_pipeline_stage_id, :legal_area,
                    :case_type, :urgency_level, :source, :source_detail, :operational_status,
                    :value_estimate_cents, :lgpd_basis,
                    :consent_status, :consent_channel, :consent_collected_at,
                    :data_retention_until, :contact_name, :contact_phone_number, :contact_email,
                    custom_fields: {}, attribution: {})
    )
  end

  def deal_update_params
    sanitize_custom_fields(
      params.permit(:title, :contact_id, :conversation_id, :owner_id, :assignee_id,
                    :legal_area, :case_type, :urgency_level, :source, :source_detail,
                    :operational_status, :disposition_reason, :disposition_note,
                    :value_estimate_cents,
                    :probability_pct, :lgpd_basis, :consent_status, :summary,
                    :next_best_action, :conflict_check_status, :documents_status,
                    :consent_channel, :consent_collected_at, :data_retention_until,
                    custom_fields: {}, attribution: {})
    )
  end

  # `captain_triage` é uma chave reservada de custom_fields: só
  # LegalTriageAnalyzer/TriageFromConversation podem gravá-la. Se a API
  # aceitasse a chave, um atendente poderia inflar o próprio score ou forçar
  # data_quality 'insufficient' (LeadScoreCalculator#captain_triage).
  def sanitize_custom_fields(attributes)
    custom_fields = attributes[:custom_fields]
    return attributes unless custom_fields.respond_to?(:delete)

    custom_fields.delete('captain_triage')
    custom_fields.delete(:captain_triage)
    attributes
  end

  def serialize_deal(deal, detailed: false, pending_activities_count: nil, is_stale: nil, next_activity_due_at: :not_loaded, ai_state: :not_loaded)
    ai_state = deal.conversation&.captain_conversation_state if ai_state == :not_loaded
    avatar_url = contact_avatar_url(deal.contact)

    base = {
      id: deal.id,
      title: deal.title,
      status: deal.status,
      legal_area: deal.legal_area,
      legal_area_label: Crm::DomainOptions.legal_area_label(deal.legal_area),
      case_type: deal.case_type,
      urgency_level: deal.urgency_level,
      source: deal.source,
      source_detail: deal.source_detail,
      operational_status: deal.operational_status,
      crm_loss_reason_id: deal.crm_loss_reason_id,
      loss_reason: deal.crm_loss_reason ? { id: deal.crm_loss_reason.id, name: deal.crm_loss_reason.name, slug: deal.crm_loss_reason.slug } : nil,
      lost_reason_note: deal.lost_reason_note,
      disposition_reason: deal.disposition_reason,
      disposition_note: deal.disposition_note,
      disposed_at: deal.disposed_at,
      archived_at: deal.archived_at,
      value_estimate_cents: deal.value_estimate_cents,
      probability_pct: deal.probability_pct,
      score_total: deal.score_total,
      score_classification: deal.score_classification,
      conflict_check_status: deal.conflict_check_status,
      documents_status: deal.documents_status,
      lgpd_basis: deal.lgpd_basis,
      consent_status: deal.consent_status,
      consent_channel: deal.consent_channel,
      consent_collected_at: deal.consent_collected_at,
      data_retention_until: deal.data_retention_until,
      lgpd_ready: deal.lgpd_ready?,
      retention_due: deal.retention_due?,
      summary: deal.summary,
      next_best_action: deal.next_best_action,
      crm_pipeline_id: deal.crm_pipeline_id,
      crm_pipeline_stage_id: deal.crm_pipeline_stage_id,
      pipeline: deal.crm_pipeline ? { id: deal.crm_pipeline.id, name: deal.crm_pipeline.name, inbox_id: deal.crm_pipeline.inbox_id } : nil,
      inbox_id: deal.inbox_id,
      inbox: serialize_deal_inbox(deal),
      contact_id: deal.contact_id,
      contact_name: deal.contact&.name,
      contact_phone_number: deal.contact&.phone_number,
      contact_email: deal.contact&.email,
      contact_thumbnail: avatar_url,
      contact_avatar_url: avatar_url,
      conversation_id: deal.conversation_id,
      conversation_display_id: deal.conversation&.display_id,
      owner_id: deal.owner_id,
      assignee_id: deal.assignee_id,
      position: deal.position,
      # F1.5: nulo significa "nunca se moveu", e a data de criacao e a resposta
      # certa para o rotting. Quem consome resolve o COALESCE.
      stage_entered_at: deal.stage_entered_at || deal.created_at,
      closed_at: deal.closed_at,
      created_at: deal.created_at,
      updated_at: deal.updated_at,
      stage: deal.crm_pipeline_stage ? { id: deal.crm_pipeline_stage.id, name: deal.crm_pipeline_stage.name, slug: deal.crm_pipeline_stage.slug } : nil,
      pending_activities_count: pending_activities_count || deal.crm_activities.pending.count,
      is_stale: is_stale.nil? ? deal.crm_activities.pending.where(kind: 'follow_up', created_by_type: 'system').exists? : is_stale,
      next_activity_due_at: next_activity_due_at == :not_loaded ? deal.crm_activities.pending.where.not(due_at: nil).minimum(:due_at) : next_activity_due_at,
      captain_ai_mode: ai_state&.ai_mode,
      captain_handoff_reason_code: ai_state&.handoff_reason_code,
      latest_score: serialize_lead_score(latest_lead_score_for(deal))
    }
    if detailed
      base.merge!(
        contact: serialize_contact(deal.contact),
        conversation: serialize_conversation(deal.conversation),
        messages: serialize_messages_for(deal),
        attachments: serialize_attachments_for(deal),
        campaign_events: serialize_campaign_events_for(deal),
        activities: deal.crm_activities.order(created_at: :desc).map { |a| serialize_activity(a) },
        intake_answers: deal.crm_intake_answers.map { |ia| { question_key: ia.question_key, answer_text: ia.answer_text } }
      )
    end
    base
  end

  def serialize_activity(activity)
    {
      id: activity.id,
      kind: activity.kind,
      title: activity.title,
      description: activity.description,
      priority: activity.priority,
      due_at: activity.due_at,
      reminder_at: activity.reminder_at,
      completed_at: activity.completed_at,
      outcome: activity.outcome,
      status: activity.completed_at.present? ? 'completed' : 'pending'
    }
  end

  def serialize_contact(contact)
    return nil unless contact

    avatar_url = contact_avatar_url(contact)

    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      thumbnail: avatar_url,
      avatar_url: avatar_url,
      relationship_status: contact.try(:relationship_status),
      lifecycle_stage: contact.try(:lifecycle_stage),
      crm_owner_id: contact.try(:crm_owner_id),
      crm_owner: serialize_user(contact.try(:crm_owner)),
      labels: contact.label_list.to_a,
      created_at: contact.created_at,
      last_activity_at: contact.last_activity_at
    }
  end

  def contact_avatar_url(contact)
    return '' unless contact

    [
      contact.try(:thumbnail),
      contact.try(:avatar_url),
      avatar_attribute(contact.additional_attributes, 'avatar_url'),
      avatar_attribute(contact.additional_attributes, 'thumbnail'),
      avatar_attribute(contact.additional_attributes, 'profile_pic'),
      avatar_attribute(contact.additional_attributes, 'profile_picture'),
      avatar_attribute(contact.additional_attributes, 'profile_image'),
      avatar_attribute(contact.custom_attributes, 'avatar_url'),
      avatar_attribute(contact.custom_attributes, 'thumbnail')
    ].find(&:present?) || ''
  end

  def avatar_attribute(attributes, key)
    return nil unless attributes.respond_to?(:[])

    attributes[key] || attributes[key.to_sym]
  end

  def serialize_conversation(conversation)
    return nil unless conversation

    {
      id: conversation.id,
      display_id: conversation.display_id,
      status: conversation.status,
      priority: conversation.priority,
      labels: conversation.label_list.to_a,
      assignee: serialize_user(conversation.assignee),
      inbox: conversation.inbox ? { id: conversation.inbox_id, name: conversation.inbox.name, channel_type: conversation.inbox.channel_type } : nil,
      campaign: serialize_campaign(conversation.campaign),
      created_at: conversation.created_at,
      last_activity_at: conversation.last_activity_at
    }
  end

  def serialize_deal_inbox(deal)
    inbox = deal.inbox || deal.conversation&.inbox
    return nil unless inbox

    { id: inbox.id, name: inbox.name, channel_type: inbox.channel_type }
  end

  # Mensagens de sistema (activity) não são conversa — viram ruído na aba
  # Mensagens do drawer.
  def serialize_messages_for(deal)
    return [] unless deal.conversation

    deal.conversation.messages
        .where.not(message_type: :activity)
        .includes(:sender, attachments: { file_attachment: :blob })
        .order(created_at: :desc)
        .limit(30)
        .reverse
        .map { |message| serialize_message(message) }
  end

  def serialize_message(message)
    {
      id: message.id,
      content: message.content,
      # Transcrição de áudio como campo explícito (não o payload inteiro de
      # content_for_llm, que expõe formatação interna de LLM).
      transcription: message_transcription(message),
      message_type: message.message_type,
      content_type: message.content_type,
      status: message.status,
      private: message.private,
      sender_type: message.sender_type,
      sender_name: message.sender.try(:name) || message.sender.try(:email),
      created_at: message.created_at,
      attachments: message.attachments.map { |attachment| serialize_attachment(attachment) }
    }
  end

  def message_transcription(message)
    message.attachments.filter_map do |attachment|
      (attachment.meta || {})['transcribed_text'].presence
    end.join("\n").presence
  end

  # A aba de anexos não precisa varrer o histórico inteiro — as 50 mensagens
  # mais recentes cobrem o uso operacional e limitam o payload.
  def serialize_attachments_for(deal)
    return [] unless deal.conversation

    deal.conversation.messages
        .includes(attachments: { file_attachment: :blob })
        .order(created_at: :desc)
        .limit(50)
        .flat_map do |message|
          message.attachments.map { |attachment| serialize_attachment(attachment).merge(message_created_at: message.created_at) }
        end.first(100)
  end

  def serialize_attachment(attachment)
    attachment.push_event_data.merge(
      meta: attachment.meta || {},
      created_at: attachment.created_at,
      fallback_title: attachment.fallback_title,
      external_url: attachment.external_url
    )
  rescue StandardError
    {
      id: attachment.id,
      message_id: attachment.message_id,
      file_type: attachment.file_type,
      meta: attachment.meta || {},
      created_at: attachment.created_at
    }
  end

  def serialize_campaign_events_for(deal)
    return [] unless deal.contact_id || deal.conversation_id

    scope = Current.account.campaign_delivery_events.includes(:campaign)
    conditions = []
    values = {}
    if deal.contact_id
      conditions << 'contact_id = :contact_id'
      values[:contact_id] = deal.contact_id
    end
    if deal.conversation_id
      conditions << 'conversation_id = :conversation_id'
      values[:conversation_id] = deal.conversation_id
    end
    scope = scope.where(conditions.join(' OR '), values)
    scope.order(occurred_at: :desc).limit(30).map do |event|
      {
        id: event.id,
        event_type: event.event_type,
        provider: event.provider,
        external_id: event.external_id,
        metadata: event.metadata || {},
        occurred_at: event.occurred_at,
        campaign: serialize_campaign(event.campaign)
      }
    end
  end

  def serialize_campaign(campaign)
    return nil unless campaign

    {
      id: campaign.id,
      title: campaign.title,
      campaign_type: campaign.campaign_type,
      status: campaign.campaign_status
    }
  end

  def serialize_user(user)
    return nil unless user

    {
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  def serialize_lead_score(score)
    return nil unless score

    {
      id: score.id,
      total_score: score.total_score,
      classification: score.classification,
      reason: score.reason,
      factors: score.factors || {},
      calculated_by: score.calculated_by,
      calculated_at: score.calculated_at
    }
  end

  def latest_lead_score_for(deal)
    deal.crm_lead_scores.max_by { |score| score.calculated_at || score.created_at || Time.zone.at(0) }
  end

  def normalized_disposition_reason(value)
    reason = value.to_s.presence || 'invalid'
    allowed = %w[invalid spam duplicated no_lead archived]
    allowed.include?(reason) ? reason : 'invalid'
  end

  def process_bulk_deal!(deal)
    case requested_bulk_action
    when 'move'
      stage = Current.account.crm_pipeline_stages.find(params[:stage_id])
      Crm::DealMover.new(deal: deal, stage_id: stage.id, actor: Current.user).perform
    when 'archive'
      deal.archive!(
        reason: params[:reason].presence || 'arquivado',
        note: params[:note],
        operational_status: params[:operational_status].presence || 'archived',
        actor: Current.user
      )
    when 'discard'
      deal.discard!(
        reason: normalized_disposition_reason(params[:reason] || params[:disposition_reason]),
        note: params[:note],
        actor: Current.user
      )
    when 'mark_base_client'
      deal.mark_base_client!(note: params[:note], actor: Current.user)
    when 'update_source'
      deal.update!(source: params[:source], source_detail: params[:source_detail])
      Crm::AuditLogger.log(
        account: Current.account,
        actor: Current.user,
        action: 'deal_source_updated',
        target: deal,
        payload: { source: params[:source], source_detail: params[:source_detail] }
      )
    when 'assign_owner'
      owner = params[:owner_id].present? ? Current.account.users.find(params[:owner_id]) : nil
      Crm::DealOwnerAssigner.new(
        deal: deal,
        owner: owner,
        actor: Current.user,
        sync_assignee: :always,
        sync_contact: true,
        contact_source: 'manual'
      ).perform
      Crm::AuditLogger.log(
        account: Current.account,
        actor: Current.user,
        action: 'deal_owner_assigned',
        target: deal,
        payload: { owner_id: owner&.id }
      )
    when 'apply_label'
      apply_label_to_deal!(deal, params[:label_title])
    when 'destroy', 'delete', 'purge'
      Crm::AuditLogger.log(
        account: Current.account,
        actor: Current.user,
        action: 'deal_destroyed',
        target: deal,
        payload: { bulk: true }
      )
      deal.destroy!
    else
      raise ArgumentError, 'Ação em lote inválida.'
    end
  end

  # PERF-04: lógica de filtro extraída para reuso pelo Crm::DealsExportJob.
  #
  # F1.4: a allowlist mora no serviço, que é quem sabe quais chaves existem e
  # quais aceitam lista. O controller manter a própria cópia foi o que fez a
  # exportação descartar filtros em silêncio.
  def filtered_deals(scope, filters = filter_params)
    Crm::DealFilterService.new(scope: scope, filters: filters, account: Current.account).perform
  end

  def filter_params
    Crm::DealFilterService.permitted_filters(params)
  end

  # A exportação usa exatamente os mesmos critérios do board: quem filtrou a
  # tela espera exportar aquilo, não o pipeline inteiro.
  def export_filter_params
    filter_params
  end

  def bulk_deals_scope
    selected = Crm::DealFilterService.permitted_filters(params[:filters])
    return filtered_deals(Current.account.crm_deals, selected) if select_all_requested?

    Current.account.crm_deals.where(id: Array(params[:deal_ids]).compact_blank)
  end

  # BUG-04: sem fallback para params[:action] (que no Rails é o nome da action
  # da rota, 'bulk_action') — só aceita ação explícita e dentro da whitelist.
  ALLOWED_BULK_ACTIONS = %w[move archive discard mark_base_client update_source
                            assign_owner apply_label destroy delete purge].freeze

  def requested_bulk_action
    requested = request.request_parameters['bulk_action'].presence || params[:bulk_action].presence
    requested = requested.to_s
    ALLOWED_BULK_ACTIONS.include?(requested) ? requested : nil
  end

  def bulk_destroy_requested?
    %w[destroy delete purge].include?(requested_bulk_action)
  end

  def select_all_requested?
    ActiveModel::Type::Boolean.new.cast(params[:select_all])
  end

  def apply_label_to_deal!(deal, label_title)
    title = label_title.to_s.strip
    raise ArgumentError, 'Etiqueta inválida.' if title.blank?

    label = Current.account.labels.find_by(title: title) || Current.account.labels.find_by(slug: title)
    title = label.title if label

    [deal.contact, deal.conversation].compact.each do |record|
      current_titles = record.label_list.to_a
      next if current_titles.include?(title)

      record.update!(label_list: current_titles + [title])
    end

    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'deal_label_applied',
      target: deal,
      payload: { label_title: title }
    )
  end

  def audited_changes(record, keys)
    keys.map(&:to_s).each_with_object({}) do |key, changes|
      next unless record.saved_changes.key?(key)

      changes[key] = {
        from: record.saved_changes[key].first,
        to: record.saved_changes[key].last
      }
    end
  end

  def lgpd_changed?(changes)
    (changes.keys & CrmDeal::LGPD_FIELDS).any?
  end

  def log_lgpd_update(before_lgpd, deal)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'lgpd_updated',
      target: deal,
      payload: {
        before: before_lgpd,
        after: deal.slice(*CrmDeal::LGPD_FIELDS)
      }
    )
  end
end
