class DataImport::ContactManager
  RESERVED_COLUMNS = %i[
    id name identifier email phone_number ip_address company city labels categories source_list
    relationship_status lifecycle_stage crm_owner_email legal_area
  ].freeze

  LABEL_SPLIT_REGEX = /[,;|]/.freeze

  def initialize(account, import_options = {})
    @account = account
    @import_options = import_options.with_indifferent_access
  end

  def build_contact(params)
    contact = find_or_initialize_contact(params)
    update_contact_attributes(params, contact)
    contact
  end

  def find_or_initialize_contact(params)
    contact_params = params.slice(:email, :identifier, :phone_number)
    contact_params[:phone_number] = format_phone_number(contact_params[:phone_number]) if contact_params[:phone_number].present?
    if create_new_duplicate?
      contact_params = deduplicated_contact_params(contact_params, params)
      return @account.contacts.new(contact_params)
    end

    contact = find_existing_contact(params)
    contact ||= @account.contacts.new(contact_params)
    contact
  end

  def find_existing_contact(params)
    contact = find_contact_by_identifier(params)
    contact ||= find_contact_by_email(params)
    contact ||= find_contact_by_phone_number(params)

    update_contact_with_merged_attributes(params, contact) if contact.present? && contact.valid?
    contact
  end

  def find_contact_by_identifier(params)
    return unless params[:identifier]

    @account.contacts.find_by(identifier: params[:identifier])
  end

  def find_contact_by_email(params)
    return unless params[:email]

    @account.contacts.from_email(params[:email])
  end

  def find_contact_by_phone_number(params)
    return unless params[:phone_number]

    @account.contacts.find_by(phone_number: format_phone_number(params[:phone_number]))
  end

  def format_phone_number(phone_number)
    normalized = phone_number.to_s.strip
    return normalized if normalized.start_with?('+') && normalized.match?(/\A\+\d+\z/)

    digits = normalized.gsub(/\D/, '')
    digits.present? ? "+#{digits}" : normalized
  end

  def update_contact_with_merged_attributes(params, contact)
    contact.identifier = params[:identifier] if params[:identifier].present?
    contact.email = params[:email] if params[:email].present?
    contact.phone_number = format_phone_number(params[:phone_number]) if params[:phone_number].present?
    update_contact_attributes(params, contact)
    contact.save
  end

  private

  def update_contact_attributes(params, contact)
    contact.name = params[:name] if params[:name].present?
    contact.additional_attributes ||= {}
    contact.additional_attributes[:company] = params[:company] if params[:company].present?
    contact.additional_attributes[:city] = params[:city] if params[:city].present?
    contact.additional_attributes[:source_list] = source_list(params) if source_list(params).present?
    contact.additional_attributes[:legal_area] = legal_area(params) if legal_area(params).present?
    contact.additional_attributes.merge!(@duplicate_originals) if @duplicate_originals.present?
    @duplicate_originals = nil

    assign_crm_attributes(contact, params)
    assign_import_labels(contact, params)

    contact.assign_attributes(custom_attributes: contact.custom_attributes.merge(custom_attributes_from(params)))
  end

  def custom_attributes_from(params)
    params.except(*RESERVED_COLUMNS)
  end

  def create_new_duplicate?
    @import_options[:duplicate_strategy] == 'create_new'
  end

  def deduplicated_contact_params(contact_params, original_params)
    deduplicated = contact_params.dup
    deduplicated[:identifier] = nil if deduplicated[:identifier].present? && @account.contacts.exists?(identifier: deduplicated[:identifier])
    deduplicated[:email] = nil if deduplicated[:email].present? && @account.contacts.from_email(deduplicated[:email]).present?
    deduplicated[:phone_number] = nil if deduplicated[:phone_number].present? && @account.contacts.exists?(phone_number: deduplicated[:phone_number])

    @duplicate_originals = {
      original_identifier: original_params[:identifier],
      original_email: original_params[:email],
      original_phone_number: original_params[:phone_number],
      duplicate_strategy: 'create_new'
    }.compact_blank

    deduplicated
  end

  def assign_crm_attributes(contact, params)
    relationship_status = normalize_relationship_status(params[:relationship_status].presence || @import_options[:relationship_status].presence)
    lifecycle_stage = normalize_lifecycle_stage(params[:lifecycle_stage].presence || @import_options[:lifecycle_stage].presence)

    contact.relationship_status = relationship_status if relationship_status.present? && contact.has_attribute?(:relationship_status)
    contact.lifecycle_stage = lifecycle_stage if lifecycle_stage.present? && contact.has_attribute?(:lifecycle_stage)

    owner = crm_owner(params)
    return if owner.blank? || !contact.has_attribute?(:crm_owner_id)

    contact.crm_owner = owner
    contact.crm_owner_assigned_at = Time.current if contact.has_attribute?(:crm_owner_assigned_at)
    contact.crm_owner_source = 'import' if contact.has_attribute?(:crm_owner_source)
  end

  def assign_import_labels(contact, params)
    labels = label_titles(params)
    return if labels.blank?

    ensure_label_records(labels)
    contact.label_list = (contact.label_list.to_a + labels).uniq
  end

  def label_titles(params)
    labels = split_labels(params[:labels]) + split_labels(params[:categories])
    labels += split_labels(@import_options[:labels]) + split_labels(@import_options[:categories])
    labels << list_label_title(params) if list_label_title(params).present?
    labels << legal_area_label_title(params) if legal_area_label_title(params).present?
    labels.map { |label| sanitize_label_title(label) }.compact_blank.uniq
  end

  def split_labels(value)
    case value
    when Array
      value.flat_map { |item| split_labels(item) }
    else
      value.to_s.split(LABEL_SPLIT_REGEX).map(&:strip)
    end
  end

  def source_list(params)
    params[:source_list].presence || @import_options[:source_list].presence
  end

  def legal_area(params)
    params[:legal_area].presence || @import_options[:legal_area].presence
  end

  def list_label_title(params)
    list = source_list(params)
    return if list.blank?

    "lista_#{list}"
  end

  def legal_area_label_title(params)
    area = legal_area(params)
    return if area.blank?

    "area_#{area}"
  end

  def sanitize_label_title(value)
    value.to_s
         .parameterize(separator: '_')
         .presence
  end

  def ensure_label_records(labels)
    labels.each do |title|
      label = @account.labels.find_or_initialize_by(title: title)
      label.color ||= '#1f93ff'
      apply_crm_label_metadata(label, title)
      label.save! if label.changed?
    end
  end

  def apply_crm_label_metadata(label, title)
    return unless label.respond_to?(:category)

    if title.start_with?('lista_')
      label.category ||= 'origin'
      label.slug ||= "origin.#{title}"
      label.scope ||= 'contact'
      label.show_on_sidebar = false if label.has_attribute?(:show_on_sidebar)
    elsif title.start_with?('area_')
      label.category ||= 'area'
      label.slug ||= title.sub('area_', 'area.')
      label.scope ||= 'both'
    elsif label.category.blank?
      label.category = 'custom'
      label.slug ||= "custom.#{title}"
      label.scope ||= 'contact'
    end
  end

  def crm_owner(params)
    email = params[:crm_owner_email].presence || @import_options[:crm_owner_email].presence
    return if email.blank?

    @account.users.find_by('LOWER(email) = ?', email.to_s.downcase)
  end

  def normalize_relationship_status(value)
    normalized = value.to_s.parameterize(separator: '_')
    {
      'cliente' => 'customer',
      'customer' => 'customer',
      'lead' => 'lead'
    }.fetch(normalized, nil)
  end

  def normalize_lifecycle_stage(value)
    normalized = value.to_s.parameterize(separator: '_')
    stage = {
      'visitante' => 'visitor',
      'lead' => 'lead',
      'lead_qualificado' => 'qualified_lead',
      'qualified_lead' => 'qualified_lead',
      'triagem' => 'triage',
      'em_triagem' => 'triage',
      'consulta_agendada' => 'consultation_scheduled',
      'cliente' => 'customer',
      'customer' => 'customer',
      'cliente_ativo' => 'active_customer',
      'active_customer' => 'active_customer',
      'cliente_recorrente' => 'recurring_customer',
      'recurring_customer' => 'recurring_customer',
      'ex_cliente' => 'ex_customer',
      'ex_customer' => 'ex_customer',
      'perdido' => 'lost',
      'lost' => 'lost'
    }.fetch(normalized, normalized.presence)

    Contact::CRM_LIFECYCLE_STAGES.include?(stage) ? stage : nil
  end
end
