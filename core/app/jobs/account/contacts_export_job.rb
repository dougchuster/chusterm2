class Account::ContactsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, column_names, params)
    @account = Account.find(account_id)
    @params = params
    @account_user = @account.users.find(user_id)

    headers = valid_headers(column_names)
    generate_csv(headers)
    send_mail
  end

  private

  def generate_csv(headers)
    csv_data = CSV.generate do |csv|
      csv << headers
      contacts.each do |contact|
        csv << headers.map { |header| export_value_for(contact, header) }
      end
    end

    attach_export_file(csv_data)
  end

  def contacts
    if @params.present? && @params[:payload].present? && @params[:payload].any?
      result = ::Contacts::FilterService.new(@account, @account_user, @params).perform
      result[:contacts]
    elsif @params[:label].present?
      @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2')).tagged_with(@params[:label], any: true)
    else
      @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2'))
    end
  end

  def valid_headers(column_names)
    (column_names.presence || default_columns) & exportable_columns
  end

  def exportable_columns
    Contact.column_names + pseudo_columns
  end

  def pseudo_columns
    %w[labels source_list legal_area company city]
  end

  def export_value_for(contact, header)
    case header
    when 'labels'
      contact.label_list.to_a.join(';')
    when 'source_list', 'legal_area', 'company', 'city'
      contact.additional_attributes&.[](header) || contact.additional_attributes&.[](header.to_sym)
    else
      contact.public_send(header)
    end
  end

  def attach_export_file(csv_data)
    return if csv_data.blank?

    @account.contacts_export.attach(
      io: StringIO.new(csv_data),
      filename: "#{@account.name}_#{@account.id}_contacts.csv",
      content_type: 'text/csv'
    )
  end

  def send_mail
    file_url = account_contact_export_url
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.contact_export_complete(file_url, @account_user.email)&.deliver_later
  end

  def account_contact_export_url
    Rails.application.routes.url_helpers.rails_blob_url(@account.contacts_export)
  end

  def default_columns
    %w[id name email phone_number relationship_status lifecycle_stage crm_owner_id source_list legal_area labels]
  end
end
