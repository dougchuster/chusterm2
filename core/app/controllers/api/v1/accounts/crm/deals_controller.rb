class Api::V1::Accounts::Crm::DealsController < Api::V1::Accounts::Crm::BaseController
  before_action :deal, only: [:show, :update, :destroy, :move, :mark_won, :mark_lost, :reopen,
                              :archive, :discard, :mark_base_client]

  def index
    authorize CrmDeal, :index?

    @deals = filtered_deals(Current.account.crm_deals)
    @deals = @deals.order(created_at: :desc).includes(:crm_pipeline, :crm_pipeline_stage, :crm_loss_reason, :crm_lead_scores, :crm_activities, :contact, :inbox)

    total = @deals.count
    per_page_param = params[:per_page].to_i
    per_page = per_page_param.positive? ? [per_page_param, 200].min : 50
    page = [params[:page].to_i, 1].max
    @deals = @deals.offset((page - 1) * per_page).limit(per_page)

    render json: {
      data: @deals.map { |d| serialize_deal(d) },
      meta: { total: total, page: page, per_page: per_page, total_pages: (total.to_f / per_page).ceil }
    }
  end

  def show
    authorize @deal, :show?

    render json: serialize_deal(@deal, detailed: true)
  end

  def create
    authorize CrmDeal, :create?

    deal = Crm::DealCreator.new(account: Current.account, params: deal_params, actor: Current.user).perform
    render json: serialize_deal(deal), status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @deal, :update?

    before_lgpd = @deal.slice(*CrmDeal::LGPD_FIELDS)
    @deal.update!(deal_update_params)
    changes = audited_changes(@deal, deal_update_params.keys)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'deal_updated',
      target: @deal,
      payload: { changes: changes }
    )
    log_lgpd_update(before_lgpd, @deal) if lgpd_changed?(changes)
    render json: serialize_deal(@deal)
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
    Crm::DealMover.new(deal: @deal, stage_id: stage.id, actor: Current.user).perform
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

    @deal.mark_lost!(
      loss_reason_id: params[:loss_reason_id],
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
                         .where.not(conversation_id: Conversation.select(:id))

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

  def export
    authorize CrmDeal, :export?

    @deals = filtered_deals(Current.account.crm_deals)
             .order(created_at: :desc)
             .includes(:crm_pipeline_stage, :crm_loss_reason, :contact)

    filename = "crm_deals_#{Date.today.iso8601}.csv"
    csv_content = build_csv(@deals)

    send_data csv_content,
              type: 'text/csv; charset=utf-8',
              disposition: "attachment; filename=\"#{filename}\""
  end

  private

  def deal
    @deal = Current.account.crm_deals.find(params[:id])
  end

  def deal_params
    params.permit(:title, :contact_id, :conversation_id, :inbox_id, :team_id, :owner_id,
                  :assignee_id, :crm_pipeline_id, :crm_pipeline_stage_id, :legal_area,
                  :case_type, :urgency_level, :source, :source_detail, :operational_status,
                  :value_estimate_cents, :lgpd_basis,
                  :consent_status, :consent_channel, :consent_collected_at,
                  :data_retention_until, :contact_name, :contact_phone_number, :contact_email,
                  custom_fields: {}, attribution: {})
  end

  def deal_update_params
    params.permit(:title, :contact_id, :conversation_id, :owner_id, :assignee_id,
                  :legal_area, :case_type, :urgency_level, :source, :source_detail,
                  :operational_status, :disposition_reason, :disposition_note,
                  :value_estimate_cents,
                  :probability_pct, :lgpd_basis, :consent_status, :summary,
                  :next_best_action, :conflict_check_status, :documents_status,
                  :consent_channel, :consent_collected_at, :data_retention_until,
                  custom_fields: {}, attribution: {})
  end

  def serialize_deal(deal, detailed: false)
    avatar_url = contact_avatar_url(deal.contact)

    base = {
      id: deal.id,
      title: deal.title,
      status: deal.status,
      legal_area: deal.legal_area,
      case_type: deal.case_type,
      urgency_level: deal.urgency_level,
      source: deal.source,
      source_detail: deal.source_detail,
      operational_status: deal.operational_status,
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
      closed_at: deal.closed_at,
      created_at: deal.created_at,
      updated_at: deal.updated_at,
      stage: deal.crm_pipeline_stage ? { id: deal.crm_pipeline_stage.id, name: deal.crm_pipeline_stage.name, slug: deal.crm_pipeline_stage.slug } : nil,
      pending_activities_count: deal.crm_activities.pending.count,
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
      identifier: contact.identifier,
      relationship_status: contact.try(:relationship_status),
      lifecycle_stage: contact.try(:lifecycle_stage),
      crm_owner_id: contact.try(:crm_owner_id),
      crm_owner: serialize_user(contact.try(:crm_owner)),
      labels: contact.label_list.to_a,
      additional_attributes: contact.additional_attributes || {},
      custom_attributes: contact.custom_attributes || {},
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

  def serialize_messages_for(deal)
    return [] unless deal.conversation

    deal.conversation.messages
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
      content_for_llm: message.content_for_llm,
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

  def serialize_attachments_for(deal)
    return [] unless deal.conversation

    deal.conversation.messages.includes(attachments: { file_attachment: :blob }).flat_map do |message|
      message.attachments.map { |attachment| serialize_attachment(attachment).merge(message_created_at: message.created_at) }
    end
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
      owner_id = params[:owner_id].presence
      deal.update!(owner_id: owner_id, assignee_id: owner_id)
      deal.contact&.update!(crm_owner_id: owner_id, crm_owner_source: 'manual', crm_owner_assigned_at: Time.current)
      Crm::AuditLogger.log(
        account: Current.account,
        actor: Current.user,
        action: 'deal_owner_assigned',
        target: deal,
        payload: { owner_id: owner_id }
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

  def filtered_deals(scope, filters = params)
    urgency = filters[:urgency].presence || filters[:urgency_level]

    scope = scope.by_pipeline(filters[:pipeline_id]) if filters[:pipeline_id].present?
    scope = scope.by_stage(filters[:stage_id]) if filters[:stage_id].present?
    scope = scope.by_legal_area(filters[:legal_area]) if filters[:legal_area].present?
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope = scope.where(operational_status: filters[:operational_status]) if filters[:operational_status].present?
    scope = scope.where(source: filters[:source]) if filters[:source].present?
    scope = scope.where(disposition_reason: filters[:disposition_reason]) if filters[:disposition_reason].present?
    scope = scope.where(conversation_id: filters[:conversation_id]) if filters[:conversation_id].present?
    scope = scope.where(contact_id: filters[:contact_id]) if filters[:contact_id].present?
    scope = scope.where(inbox_id: filters[:inbox_id]) if filters[:inbox_id].present?
    scope = scope.where(urgency_level: urgency) if urgency.present?
    scope = filter_by_owner(scope, filters)
    scope = scope.where('score_total >= ?', filters[:score_min].to_i) if filters[:score_min].present?
    scope = scope.where('score_total <= ?', filters[:score_max].to_i) if filters[:score_max].present?
    scope = filter_by_search(scope, filters[:search]) if filters[:search].present?
    scope
  end

  def filter_by_owner(scope, filters)
    return scope if filters[:owner_id].blank?

    filters[:owner_id].to_s == '__unassigned' ? scope.where(owner_id: nil) : scope.where(owner_id: filters[:owner_id])
  end

  def bulk_deals_scope
    return filtered_deals(Current.account.crm_deals, params[:filters] || {}) if select_all_requested?

    Current.account.crm_deals.where(id: Array(params[:deal_ids]).compact_blank)
  end

  def requested_bulk_action
    request.request_parameters['bulk_action'].presence ||
      request.request_parameters['action'].presence ||
      params[:bulk_action].presence ||
      params[:action].to_s
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

  def filter_by_search(scope, search)
    query = search.to_s.downcase.strip
    digits = query.gsub(/\D/, '')
    like_query = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    like_digits = "%#{ActiveRecord::Base.sanitize_sql_like(digits)}%"

    conditions = [
      'LOWER(crm_deals.title) LIKE :query',
      'LOWER(contacts.name) LIKE :query',
      'LOWER(contacts.email) LIKE :query'
    ]

    if digits.present?
      conditions << "regexp_replace(COALESCE(contacts.phone_number, ''), '[^0-9]', '', 'g') LIKE :digits"
    end

    scope.left_joins(:contact).where(
      conditions.join(' OR '),
      query: like_query,
      digits: like_digits
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
  def build_csv(deals)
    require 'csv'

    headers = [
      'ID', 'Título', 'Status', 'Área Jurídica', 'Tipo de Caso',
      'Urgência', 'Score', 'Classificação', 'Valor Estimado (R$)',
      'Probabilidade (%)', 'Etapa', 'Base LGPD', 'Consentimento',
      'Canal Consentimento', 'Coleta Consentimento', 'Retenção Até',
      'Resumo', 'Próxima Ação', 'Contato ID', 'Conversa ID',
      'Motivo Perda', 'Criado Em', 'Atualizado Em'
    ]

    CSV.generate(headers: true, col_sep: ',', encoding: 'UTF-8') do |csv|
      csv << headers
      deals.each do |deal|
        csv << [
          deal.id,
          csv_value(deal.title),
          deal.status,
          deal.legal_area,
          deal.case_type,
          deal.urgency_level,
          deal.score_total,
          deal.score_classification,
          (deal.value_estimate_cents.to_f / 100).round(2),
          deal.probability_pct,
          deal.crm_pipeline_stage&.name,
          deal.lgpd_basis,
          deal.consent_status,
          deal.consent_channel,
          deal.consent_collected_at&.iso8601,
          deal.data_retention_until&.iso8601,
          csv_value(deal.summary),
          csv_value(deal.next_best_action),
          deal.contact_id,
          deal.conversation_id,
          deal.crm_loss_reason&.name,
          deal.created_at.iso8601,
          deal.updated_at.iso8601
        ]
      end
    end
  end

  def csv_value(text)
    return '' if text.blank?
    # Remove line breaks that would break CSV rows
    text.to_s.gsub(/[\r\n]+/, ' ').strip
  end
end
