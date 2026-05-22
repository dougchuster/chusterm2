class Crm::DealCreator
  def initialize(account:, params:, actor: nil)
    @account = account
    @params = params
    @actor = actor
  end

  def perform
    ActiveRecord::Base.transaction do
      attributes = deal_attributes
      contact = resolve_contact
      attributes[:contact_id] ||= contact.id if contact
      @last_deal_attributes = attributes

      existing_deal = find_existing_open_deal(attributes)
      return reuse_existing_deal(existing_deal, attributes) if existing_deal

      deal = @account.crm_deals.create!(attributes)
      Crm::AuditLogger.log(account: @account, actor: @actor, action: 'deal_created', target: deal)
      Crm::ApplyChecklistTemplate.new(deal: deal, actor: @actor).perform if deal.case_type.present?
      deal
    end
  rescue ActiveRecord::RecordNotUnique
    attributes = @last_deal_attributes || deal_attributes
    existing_deal = find_existing_open_deal(attributes)
    return reuse_existing_deal(existing_deal, attributes) if existing_deal

    raise
  end

  private

  def deal_attributes
    @params.slice(:title, :contact_id, :conversation_id, :inbox_id,
                  :team_id, :owner_id, :assignee_id,
                  :crm_pipeline_id, :crm_pipeline_stage_id,
                  :legal_area, :case_type, :urgency_level,
                  :source, :source_detail, :operational_status,
                  :value_estimate_cents, :lgpd_basis,
                  :consent_status, :consent_channel,
                  :consent_collected_at, :data_retention_until,
                  :custom_fields, :attribution)
  end

  def resolve_contact
    return nil if @params[:contact_id].present?

    name = @params[:contact_name].to_s.strip
    phone_number = normalize_phone_number(@params[:contact_phone_number])
    email = @params[:contact_email].to_s.strip.downcase
    return nil if name.blank? && phone_number.blank? && email.blank?

    contact = find_existing_contact(email, phone_number) || @account.contacts.build
    contact.assign_attributes(
      name: name.presence || contact.name.presence || phone_number.presence || email,
      phone_number: phone_number.presence || contact.phone_number,
      email: email.presence || contact.email
    )
    contact.contact_type = :lead if contact.new_record? || contact.visitor?
    contact.save!
    contact
  end

  def find_existing_contact(email, phone_number)
    return @account.contacts.from_email(email) if email.present?
    return @account.contacts.find_by(phone_number: phone_number) if phone_number.present?

    nil
  end

  def find_existing_open_deal(attributes)
    contact_id = attributes[:contact_id]
    pipeline_id = attributes[:crm_pipeline_id]
    return if contact_id.blank? || pipeline_id.blank?

    @account.crm_deals.open_deals
            .where(contact_id: contact_id, crm_pipeline_id: pipeline_id)
            .order(updated_at: :desc, id: :desc)
            .first
  end

  def reuse_existing_deal(deal, attributes)
    updates = {}
    %i[conversation_id inbox_id team_id owner_id assignee_id].each do |key|
      updates[key] = attributes[key] if attributes[key].present? && deal.public_send(key) != attributes[key]
    end
    deal.update!(updates) if updates.present?
    Crm::AuditLogger.log(
      account: @account,
      actor: @actor,
      action: 'deal_reused_for_contact_pipeline',
      target: deal,
      payload: {
        contact_id: deal.contact_id,
        crm_pipeline_id: deal.crm_pipeline_id,
        conversation_id: attributes[:conversation_id],
        inbox_id: attributes[:inbox_id]
      }
    )
    deal
  end

  def normalize_phone_number(value)
    raw = value.to_s.strip
    digits = raw.gsub(/\D/, '')
    return '' if digits.blank?
    return "+#{digits}" if raw.start_with?('+')
    return "+#{digits}" if digits.start_with?('55')

    "+55#{digits}"
  end
end
