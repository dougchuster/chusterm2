# Transforma um lead da Meta (field_data) em Contact + MarketingLead + CrmDeal.
# Idempotente: um leadgen_id so gera um MarketingLead por conta.
class Marketing::LeadToCrmService
  def initialize(account:, connection:, leadgen_id:, fields:, context: {})
    @account = account
    @connection = connection
    @leadgen_id = leadgen_id
    @fields = fields.except('_meta')
    @meta = (fields['_meta'] || {}).merge(context || {})
  end

  def perform
    lead = find_or_create_lead
    return lead if lead.persisted? && lead.crm_deal_id.present?

    contact = find_or_create_contact(lead)
    deal = create_deal(contact)
    attrs = { contact: contact, crm_deal: deal }
    if deal.present?
      attrs[:status] = 'converted'
      attrs[:converted_at] = Time.current
    end
    lead.update!(attrs)
    lead
  end

  private

  def find_or_create_lead
    @account.marketing_leads.find_or_create_by!(leadgen_id: @leadgen_id) do |lead|
      lead.crm_external_connection = @connection
      lead.field_data = @fields
      lead.form_id = @meta['form_id']
      lead.campaign_id = @meta['campaign_id']
      lead.adset_id = @meta['adset_id']
      lead.ad_id = @meta['ad_id']
      lead.platform = @meta['platform']
      lead.metadata = { 'page_id' => @meta['page_id'], 'created_time' => @meta['created_time'] }.compact
    end
  rescue ActiveRecord::RecordNotUnique
    @account.marketing_leads.find_by!(leadgen_id: @leadgen_id)
  end

  def find_or_create_contact(lead)
    email = normalized_email
    phone = normalized_phone
    contact = find_contact(email, phone)
    return contact if contact

    @account.contacts.create!(
      name: lead.display_name,
      email: email,
      phone_number: phone,
      custom_attributes: { 'meta_leadgen_id' => @leadgen_id, 'meta_form_id' => lead.form_id }.compact
    )
  end

  def find_contact(email, phone)
    scope = @account.contacts
    return scope.from_email(email) if email.present?
    return scope.find_by(phone_number: phone) if phone.present?

    nil
  end

  def create_deal(contact)
    pipeline = target_pipeline
    return if pipeline.nil?

    stage = pipeline.crm_pipeline_stages.ordered.first
    @account.crm_deals.create!(
      crm_pipeline: pipeline,
      crm_pipeline_stage: stage,
      contact: contact,
      title: deal_title,
      operational_status: 'active'
    )
  rescue ActiveRecord::RecordInvalid
    # Contato ja tem lead aberto neste kanban — vincula o existente.
    @account.crm_deals.open_deals.find_by(crm_pipeline: pipeline, contact: contact)
  end

  def target_pipeline
    configured = @connection&.metadata&.dig('leadgen_pipeline_id')
    return @account.crm_pipelines.find_by(id: configured) if configured.present?

    @account.crm_pipelines.default_first.first
  end

  def deal_title
    campaign = @account.marketing_campaigns.find_by(external_id: @meta['campaign_id']) if @meta['campaign_id'].present?
    "Meta Lead — #{campaign&.name || @meta['form_id'] || @leadgen_id}"
  end

  def normalized_email
    value = @fields['email'].presence || @fields['e-mail'].presence
    value&.strip&.downcase
  end

  def normalized_phone
    raw = @fields['phone_number'].presence || @fields['phone'].presence || @fields['telefone'].presence
    return if raw.blank?

    normalized = raw.to_s.gsub(/[^\d+]/, '')
    normalized.presence
  end
end
