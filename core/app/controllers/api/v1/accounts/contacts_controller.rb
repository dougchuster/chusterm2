class Api::V1::Accounts::ContactsController < Api::V1::Accounts::BaseController
  include Sift
  sort_on :email, type: :string
  sort_on :name, internal_name: :order_on_name, type: :scope, scope_params: [:direction]
  sort_on :phone_number, type: :string
  sort_on :last_activity_at, internal_name: :order_on_last_activity_at, type: :scope, scope_params: [:direction]
  sort_on :created_at, internal_name: :order_on_created_at, type: :scope, scope_params: [:direction]
  sort_on :company, internal_name: :order_on_company_name, type: :scope, scope_params: [:direction]
  sort_on :city, internal_name: :order_on_city, type: :scope, scope_params: [:direction]
  sort_on :country, internal_name: :order_on_country_name, type: :scope, scope_params: [:direction]

  RESULTS_PER_PAGE = 15
  FILTER_PAYLOAD_PARAMS = [
    :attribute_key, :filter_operator, :query_operator, :attribute_model, :custom_attribute_type, :values,
    { values: [] }
  ].freeze

  before_action :check_authorization
  before_action :set_current_page, only: [:index, :active, :search, :filter]
  before_action :fetch_contact, only: [:show, :update, :destroy, :avatar, :contactable_inboxes, :destroy_custom_attributes]
  before_action :set_include_contact_inboxes, only: [:index, :active, :search, :filter, :show, :update]

  def index
    @contacts = fetch_contacts(resolved_contacts)
    @contacts_count = @contacts.total_count
  end

  def search
    render json: { error: 'Specify search string with parameter q' }, status: :unprocessable_entity if params[:q].blank? && return

    contacts = Current.account.contacts.where(
      'name ILIKE :search OR email ILIKE :search OR phone_number ILIKE :search OR contacts.identifier LIKE :search',
      search: "%#{params[:q].strip}%"
    )
    contacts = apply_crm_filters(contacts)
    @contacts = fetch_contacts_with_has_more(contacts)
  end

  def import
    render json: { error: I18n.t('errors.contacts.import.failed') }, status: :unprocessable_entity and return if params[:import_file].blank?

    ActiveRecord::Base.transaction do
      import = Current.account.data_imports.create!(data_type: 'contacts', metadata: contact_import_metadata)
      import.import_file.attach(params[:import_file])
      create_import_segment(import)
    end

    head :ok
  end

  def imports
    imports = Current.account.data_imports.where(data_type: 'contacts').includes(import_file_attachment: :blob, failed_records_attachment: :blob)
                             .order(created_at: :desc).limit(20)
    render json: imports.map { |data_import| data_import_payload(data_import) }
  end

  def export
    column_names = params['column_names']
    filter_query = contact_filter_params
    filter_params = { payload: filter_query[:payload], label: filter_query[:label] }
    Account::ContactsExportJob.perform_later(Current.account.id, Current.user.id, column_names, filter_params)
    head :ok, message: I18n.t('errors.contacts.export.success')
  end

  def export_csv
    headers = export_csv_headers(params[:column_names])
    send_data(
      contacts_csv(export_csv_contacts, headers),
      filename: "contatos-#{Time.zone.today}.csv",
      type: 'text/csv; charset=utf-8',
      disposition: 'attachment'
    )
  end

  def export_google_sheet
    headers = export_csv_headers(params[:column_names])
    result = Crm::GoogleSheetsExporter.new(
      account: Current.account,
      user: Current.user,
      title: "Contatos ChusteRM #{Time.zone.today}",
      rows: contact_export_rows(export_csv_contacts, headers)
    ).perform

    render json: result
  rescue Crm::GoogleSheetsExporter::AuthorizationRequired
    render json: {
      error: 'google_workspace_authorization_required',
      authorization_required: true
    }, status: :unprocessable_entity
  rescue Crm::GoogleSheetsExporter::ExportFailed => e
    render json: { error: e.message }, status: :bad_gateway
  end

  # returns online contacts
  def active
    contacts = Current.account.contacts.where(id: ::OnlineStatusTracker
                  .get_available_contact_ids(Current.account.id))
    contacts = apply_crm_filters(contacts)
    @contacts = fetch_contacts(contacts)
    @contacts_count = @contacts.total_count
  end

  def show; end

  def filter
    result = ::Contacts::FilterService.new(Current.account, Current.user, contact_filter_params).perform
    contacts = apply_crm_filters(result[:contacts])
    @contacts_count = result[:count]
    @contacts = fetch_contacts(contacts)
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def contactable_inboxes
    @all_contactable_inboxes = Contacts::ContactableInboxesService.new(contact: @contact).get
    @contactable_inboxes = @all_contactable_inboxes.select { |contactable_inbox| policy(contactable_inbox[:inbox]).show? }
  end

  # TODO : refactor this method into dedicated contacts/custom_attributes controller class and routes
  def destroy_custom_attributes
    @contact.custom_attributes = @contact.custom_attributes.excluding(params[:custom_attributes])
    @contact.save!
  end

  def create
    ActiveRecord::Base.transaction do
      @contact = Current.account.contacts.new(permitted_params.except(:avatar_url))
      @contact.save!
      @contact_inbox = build_contact_inbox
      process_avatar_from_url
    end
  end

  def update
    previous_crm_state = crm_state_for_audit(@contact)
    @contact.assign_attributes(contact_update_params)
    @contact.save!
    log_crm_contact_update(previous_crm_state)
    process_avatar_from_url
  end

  def destroy
    if ::OnlineStatusTracker.get_presence(
      @contact.account.id, 'Contact', @contact.id
    )
      return render_error({ message: I18n.t('contacts.online.delete', contact_name: @contact.name.capitalize) },
                          :unprocessable_entity)
    end

    @contact.destroy!
    head :ok
  end

  def avatar
    @contact.avatar.purge if @contact.avatar.attached?
    @contact
  end

  private

  # TODO: Move this to a finder class
  def resolved_contacts
    return @resolved_contacts if @resolved_contacts

    @resolved_contacts = Current.account.contacts.resolved_contacts(use_crm_v2: Current.account.feature_enabled?('crm_v2'))

    apply_crm_filters(@resolved_contacts)
  end

  def apply_crm_filters(scope)
    scope = scope.tagged_with(params[:labels], any: true) if params[:labels].present?
    if params[:relationship_status].present? && Contact.column_names.include?('relationship_status')
      scope = scope.where(relationship_status: params[:relationship_status])
    end
    if params[:lifecycle_stage].present? && Contact.column_names.include?('lifecycle_stage')
      scope = scope.where(lifecycle_stage: params[:lifecycle_stage])
    end
    if params[:crm_owner_id].present? && Contact.column_names.include?('crm_owner_id')
      scope = scope.where(crm_owner_id: params[:crm_owner_id])
    end
    if params[:without_crm_owner].to_s == 'true' && Contact.column_names.include?('crm_owner_id')
      scope = scope.where(crm_owner_id: nil)
    end
    if params[:source_list].present?
      scope = scope.where(
        'LOWER(contacts.additional_attributes ->> ?) = ?',
        'source_list',
        params[:source_list].to_s.downcase
      )
    end
    if params[:legal_area].present?
      scope = scope.where(
        'LOWER(contacts.additional_attributes ->> ?) LIKE ?',
        'legal_area',
        "%#{params[:legal_area].to_s.downcase}%"
      )
    end
    scope
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def fetch_contacts(contacts)
    # Build includes hash to avoid separate query when contact_inboxes are needed
    includes_hash = { avatar_attachment: [:blob] }
    includes_hash[:contact_inboxes] = { inbox: :channel } if @include_contact_inboxes

    filtrate(contacts)
      .includes(includes_hash)
      .page(@current_page)
      .per(RESULTS_PER_PAGE)
  end

  def fetch_contacts_with_has_more(contacts)
    includes_hash = { avatar_attachment: [:blob] }
    includes_hash[:contact_inboxes] = { inbox: :channel } if @include_contact_inboxes

    # Calculate offset manually to fetch one extra record for has_more check
    offset = (@current_page.to_i - 1) * RESULTS_PER_PAGE
    results = filtrate(contacts)
              .includes(includes_hash)
              .offset(offset)
              .limit(RESULTS_PER_PAGE + 1)
              .to_a

    @has_more = results.size > RESULTS_PER_PAGE
    results = results.first(RESULTS_PER_PAGE) if @has_more
    @contacts_count = results.size
    results
  end

  def build_contact_inbox
    return if params[:inbox_id].blank?

    inbox = Current.account.inboxes.find(params[:inbox_id])
    ContactInboxBuilder.new(
      contact: @contact,
      inbox: inbox,
      source_id: params[:source_id]
    ).perform
  end

  def permitted_params
    params.permit(
      :name, :identifier, :email, :phone_number, :avatar, :blocked, :avatar_url,
      :relationship_status, :lifecycle_stage, :crm_owner_id, :crm_owner_source,
      additional_attributes: {}, custom_attributes: {}
    )
  end

  def contact_import_metadata
    params.permit(
      :source_list, :relationship_status, :lifecycle_stage, :crm_owner_email, :legal_area,
      :duplicate_strategy,
      column_mapping: {},
      labels: [],
      categories: []
    ).to_h.compact_blank
  end

  def data_import_payload(data_import)
    {
      id: data_import.id,
      status: data_import.status,
      data_type: data_import.data_type,
      total_records: data_import.total_records,
      processed_records: data_import.processed_records,
      rejected_records: rejected_records_count(data_import),
      processing_errors: data_import.processing_errors,
      metadata: data_import.try(:metadata) || {},
      filename: data_import.import_file.attached? ? data_import.import_file.filename.to_s : nil,
      failed_records_url: data_import.failed_records.attached? ? url_for(data_import.failed_records) : nil,
      created_at: data_import.created_at,
      updated_at: data_import.updated_at
    }
  end

  def rejected_records_count(data_import)
    return nil if data_import.total_records.blank? || data_import.processed_records.blank?

    data_import.total_records - data_import.processed_records
  end

  def create_import_segment(data_import)
    source_list = data_import.metadata['source_list'].presence
    return if source_list.blank?

    Current.account.custom_filters.contact.find_or_create_by!(
      user: Current.user,
      name: "Lista #{source_list}"
    ) do |segment|
      segment.query = {
        payload: [
          {
            attribute_key: 'source_list',
            filter_operator: 'equal_to',
            values: [source_list],
            query_operator: nil,
            attribute_model: 'additional_attributes'
          }
        ]
      }
    end
  end

  def export_csv_contacts
    filter_query = contact_filter_params
    contacts = if filter_query[:payload].present? && filter_query[:payload].any?
                 ::Contacts::FilterService.new(Current.account, Current.user, filter_query).perform[:contacts]
               else
                 Current.account.contacts.resolved_contacts(use_crm_v2: Current.account.feature_enabled?('crm_v2'))
               end

    contacts = contacts.tagged_with(filter_query[:label], any: true) if filter_query[:label].present?
    apply_crm_filters(contacts).includes(:crm_owner)
  end

  def contacts_csv(contacts, headers)
    CSV.generate do |csv|
      csv << headers.map { |header| export_csv_label(header) }
      contacts.find_each do |contact|
        csv << headers.map { |header| export_csv_value(contact, header) }
      end
    end
  end

  def contact_export_rows(contacts, headers)
    [
      headers.map { |header| export_csv_label(header) },
      *contacts.limit(10_000).map do |contact|
        headers.map { |header| export_csv_value(contact, header) }
      end
    ]
  end

  def export_csv_headers(column_names)
    selected_columns = Array(column_names).presence || default_export_csv_columns
    selected_columns & export_csv_columns
  end

  def export_csv_columns
    Contact.column_names + %w[labels source_list legal_area company city crm_owner_name]
  end

  def default_export_csv_columns
    %w[
      id name email phone_number relationship_status lifecycle_stage crm_owner_id crm_owner_name
      source_list legal_area labels company city created_at last_activity_at
    ]
  end

  def export_csv_label(header)
    {
      'relationship_status' => 'relacionamento',
      'lifecycle_stage' => 'etapa',
      'crm_owner_id' => 'responsavel_id',
      'crm_owner_name' => 'responsavel',
      'source_list' => 'lista_origem',
      'legal_area' => 'area_juridica',
      'phone_number' => 'telefone',
      'last_activity_at' => 'ultima_atividade',
      'created_at' => 'criado_em',
      'labels' => 'etiquetas'
    }[header] || header
  end

  def export_csv_value(contact, header)
    case header
    when 'labels'
      contact.label_list.to_a.join(';')
    when 'source_list', 'legal_area', 'company', 'city'
      contact.additional_attributes&.[](header) || contact.additional_attributes&.[](header.to_sym)
    when 'crm_owner_name'
      contact.crm_owner&.available_name || contact.crm_owner&.name
    else
      contact.public_send(header)
    end
  end

  def contact_custom_attributes
    return @contact.custom_attributes.merge(permitted_params[:custom_attributes]) if permitted_params[:custom_attributes]

    @contact.custom_attributes
  end

  def contact_additional_attributes
    return @contact.additional_attributes.merge(permitted_params[:additional_attributes]) if permitted_params[:additional_attributes]

    @contact.additional_attributes
  end

  def contact_update_params
    attrs = permitted_params.except(:custom_attributes, :avatar_url).to_h.symbolize_keys
    if attrs.key?(:crm_owner_id) && @contact.respond_to?(:crm_owner_assigned_at)
      attrs[:crm_owner_assigned_at] = Time.current
      attrs[:crm_owner_source] = 'manual' if attrs[:crm_owner_source].blank?
    end
    normalize_crm_contact_params(attrs)

    attrs
      .merge({ custom_attributes: contact_custom_attributes })
      .merge({ additional_attributes: contact_additional_attributes })
  end

  def normalize_crm_contact_params(attrs)
    return unless @contact.has_attribute?(:relationship_status)

    lead_lifecycle_stages = %w[visitor lead qualified_lead triage]
    customer_lifecycle_stages = %w[customer active_customer recurring_customer ex_customer]
    lifecycle_stage = attrs[:lifecycle_stage].presence
    status = attrs[:relationship_status].presence
    status ||= 'customer' if lifecycle_stage.in?(customer_lifecycle_stages)
    status ||= 'lead' if lifecycle_stage.present?
    return if status.blank?

    attrs[:relationship_status] = status
    if @contact.has_attribute?(:contact_type)
      attrs[:contact_type] = status == 'customer' ? 'customer' : 'lead'
    end
    if status == 'customer' && (lifecycle_stage.blank? || lifecycle_stage.in?(lead_lifecycle_stages))
      attrs[:lifecycle_stage] = 'customer'
    end
    if status == 'lead' && (lifecycle_stage.blank? || lifecycle_stage.in?(customer_lifecycle_stages))
      attrs[:lifecycle_stage] = 'lead'
    end
    attrs[:became_customer_at] = Time.current if status == 'customer' && @contact.became_customer_at.blank?
    attrs[:became_lead_at] = Time.current if status == 'lead' && @contact.became_lead_at.blank?
    if attrs[:lifecycle_stage].present? && attrs[:lifecycle_stage] != @contact.lifecycle_stage
      attrs[:lifecycle_stage_changed_at] = Time.current
    end
  end

  def set_include_contact_inboxes
    @include_contact_inboxes = if params[:include_contact_inboxes].present?
                                 params[:include_contact_inboxes] == 'true'
                               else
                                 true
                               end
  end

  def fetch_contact
    contact_scope = Current.account.contacts
    contact_scope = contact_scope.includes(contact_inboxes: [:inbox]) if @include_contact_inboxes
    @contact = contact_scope.find(params[:id])
  end

  def process_avatar_from_url
    ::Avatar::AvatarFromUrlJob.perform_later(@contact, params[:avatar_url]) if params[:avatar_url].present?
  end

  def contact_filter_params
    params.permit(
      :page, :label, :relationship_status, :lifecycle_stage, :crm_owner_id,
      :without_crm_owner, :source_list, :legal_area,
      labels: [],
      payload: FILTER_PAYLOAD_PARAMS
    )
  end

  def crm_state_for_audit(contact)
    {
      relationship_status: contact.try(:relationship_status),
      lifecycle_stage: contact.try(:lifecycle_stage),
      crm_owner_id: contact.try(:crm_owner_id)
    }
  end

  def log_crm_contact_update(previous_state)
    current_state = crm_state_for_audit(@contact)
    changes = current_state.filter_map do |key, value|
      next if previous_state[key] == value

      [key, { from: previous_state[key], to: value }]
    end.to_h
    return if changes.blank?

    Crm::AuditLogger.log(
      account: Current.account,
      action: 'contact_crm_fields_changed',
      target: @contact,
      actor: Current.user,
      payload: changes
    )
  end

  def render_error(error, error_status)
    render json: error, status: error_status
  end
end
