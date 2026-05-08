class Contacts::SyncAttributes
  attr_reader :contact

  def initialize(contact)
    @contact = contact
  end

  def perform
    update_contact_location_and_country_code
    set_contact_type
    set_crm_relationship_status
    set_crm_lifecycle_defaults
  end

  private

  def update_contact_location_and_country_code
    # Ensure that location and country_code are updated from additional_attributes.
    # TODO: Remove this once all contacts are updated and both the location and country_code fields are standardized throughout the app.
    @contact.location = @contact.additional_attributes['city']
    @contact.country_code = @contact.additional_attributes['country']
  end

  def set_contact_type
    #  If the contact is already a lead or customer then do not change the contact type
    return unless @contact.contact_type == 'visitor'
    # If the contact has an email or phone number or social details( facebook_user_id, instagram_user_id, etc) then it is a lead
    # If contact is from external channel like facebook, instagram, whatsapp, etc then it is a lead
    return unless @contact.email.present? || @contact.phone_number.present? || social_details_present?

    @contact.contact_type = 'lead'
  end

  def set_crm_relationship_status
    return unless @contact.has_attribute?(:relationship_status)

    @contact.relationship_status = @contact.customer? ? 'customer' : 'lead'
  end

  def set_crm_lifecycle_defaults
    return unless @contact.has_attribute?(:lifecycle_stage)

    now = Time.current
    if @contact.relationship_status == 'customer'
      @contact.lifecycle_stage = 'customer' if @contact.lifecycle_stage.blank? || @contact.lifecycle_stage.in?(%w[visitor lead qualified_lead triage])
      @contact.became_customer_at ||= now if @contact.has_attribute?(:became_customer_at)
    elsif @contact.lead? && (@contact.lifecycle_stage.blank? || @contact.lifecycle_stage == 'visitor')
      @contact.lifecycle_stage = 'lead'
      @contact.became_lead_at ||= now if @contact.has_attribute?(:became_lead_at)
    end

    @contact.lifecycle_stage_changed_at ||= now if @contact.has_attribute?(:lifecycle_stage_changed_at)
  end

  def social_details_present?
    @contact.additional_attributes.keys.any? do |key|
      key.start_with?('social_') && @contact.additional_attributes[key].present?
    end
  end
end
