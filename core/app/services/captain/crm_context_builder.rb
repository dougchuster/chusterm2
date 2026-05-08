class Captain::CrmContextBuilder
  RECENT_LIMIT = 10

  def initialize(conversation)
    @conversation = conversation
    @contact = conversation&.contact
  end

  def perform
    return {} if @conversation.blank?

    {
      contact: contact_context,
      conversation: conversation_context,
      deal: deal_context,
      labels: labels_context,
      playbooks: playbooks_context,
      documents: documents_context,
      media: media_context,
      recent_notes: recent_notes_context
    }.compact
  end

  private

  def contact_context
    return if @contact.blank?

    {
      id: @contact.id,
      name: @contact.name,
      email: @contact.email,
      phone_number: @contact.phone_number,
      relationship_status: @contact.respond_to?(:crm_relationship_status) ? @contact.crm_relationship_status : @contact.contact_type,
      lifecycle_stage: @contact.respond_to?(:crm_lifecycle_stage) ? @contact.crm_lifecycle_stage : nil,
      crm_owner: user_context(@contact.try(:crm_owner)),
      source_list: @contact.additional_attributes&.dig('source_list'),
      legal_area: @contact.additional_attributes&.dig('legal_area'),
      segments: contact_segments_context,
      labels: label_list(@contact)
    }.compact
  end

  def conversation_context
    {
      id: @conversation.id,
      display_id: @conversation.display_id,
      status: @conversation.status,
      priority: @conversation.priority,
      assignee: user_context(@conversation.assignee),
      labels: @conversation.cached_label_list_array
    }.compact
  end

  def labels_context
    label_titles = (label_list(@contact) + @conversation.cached_label_list_array).uniq
    return [] if label_titles.blank?

    @conversation.account.labels.where(title: label_titles).map do |label|
      label.respond_to?(:crm_metadata) ? label.crm_metadata.merge(title: label.title, color: label.color) : { title: label.title, color: label.color }
    end
  end

  def deal_context
    deal = linked_deal
    return if deal.blank?

    {
      id: deal.id,
      title: deal.title,
      status: deal.status,
      legal_area: deal.legal_area,
      case_type: deal.case_type,
      urgency_level: deal.urgency_level,
      score_total: deal.score_total,
      score_classification: deal.score_classification,
      documents_status: deal.documents_status,
      summary: deal.summary,
      next_best_action: deal.next_best_action,
      owner: user_context(deal_owner(deal))
    }.compact
  end

  def documents_context
    document_attachments.map do |attachment|
      {
        id: attachment.id,
        file_type: attachment.file_type,
        document_guess: attachment.meta&.dig('document_guess'),
        status: attachment.meta&.dig('media_understanding_status'),
        ocr_text: attachment.meta&.dig('ocr_text')
      }.compact
    end
  end

  def playbooks_context
    return [] unless @conversation.account.respond_to?(:captain_playbooks)

    @conversation.account.captain_playbooks
                 .active
                 .for_legal_area(context_legal_area)
                 .ordered
                 .limit(5)
                 .map(&:context_payload)
  end

  def context_legal_area
    linked_deal&.legal_area.presence ||
      @contact&.additional_attributes&.dig('legal_area').presence ||
      label_list(@contact).find { |label| label.to_s.start_with?('area_') }&.delete_prefix('area_')
  end

  def media_context
    {
      audio_transcriptions: attachment_meta_values(:audio, 'transcribed_text'),
      image_descriptions: attachment_meta_values(:image, 'image_description'),
      ocr_texts: attachment_meta_values(:image, 'ocr_text')
    }
  end

  def recent_notes_context
    return [] if @contact.blank?

    @contact.notes.order(created_at: :desc).limit(RECENT_LIMIT).map do |note|
      {
        id: note.id,
        content: note.content,
        created_at: note.created_at
      }
    end
  end

  def contact_segments_context
    return [] if @contact.blank?

    @conversation.account.custom_filters.contact.filter_map do |segment|
      next unless contact_matches_segment?(segment)

      { id: segment.id, name: segment.name }
    end
  end

  def contact_matches_segment?(segment)
    return false if segment.query.blank?

    Contacts::FilterService.new(@conversation.account, @conversation.assignee || @conversation.account.users.first,
                                segment.query.with_indifferent_access).perform[:contacts].where(id: @contact.id).exists?
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    Rails.logger.warn("[Captain CRM Context] Ignoring invalid contact segment #{segment.id}: #{e.message}")
    false
  end

  def attachment_meta_values(file_type, key)
    attachments.where(file_type: file_type).filter_map { |attachment| attachment.meta&.dig(key).presence }
  end

  def document_attachments
    attachments.where(file_type: %i[image file])
  end

  def attachments
    @attachments ||= @conversation.attachments.order(created_at: :desc).limit(RECENT_LIMIT)
  end

  def linked_deal
    @linked_deal ||= @conversation.captain_conversation_state&.crm_deal ||
                     @conversation.account.crm_deals.open_deals.find_by(conversation: @conversation)
  end

  def deal_owner(deal)
    return if deal&.owner_id.blank?

    @conversation.account.users.find_by(id: deal.owner_id)
  end

  def label_list(record)
    return [] if record.blank? || !record.respond_to?(:label_list)

    record.label_list.to_a
  end

  def user_context(user)
    return if user.blank?

    {
      id: user.id,
      name: user.name,
      email: user.email
    }
  end
end
