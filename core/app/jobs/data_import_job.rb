# TODO: logic is written tailored to contact import since its the only import available
# let's break this logic and clean this up in future

class DataImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  def perform(data_import)
    @data_import = data_import
    @contact_manager = DataImport::ContactManager.new(@data_import.account, @data_import.metadata || {})
    begin
      process_import_file
      send_import_notification_to_admin
    rescue CSV::MalformedCSVError => e
      handle_csv_error(e)
    end
  end

  private

  def process_import_file
    @data_import.update!(status: :processing)
    reset_import_summary
    contact_entries, rejected_contacts = parse_csv_and_build_contacts

    saved_count = import_contacts(contact_entries, rejected_contacts)
    update_data_import_status(saved_count, rejected_contacts.length)
    save_failed_records_csv(rejected_contacts)
  end

  def parse_csv_and_build_contacts
    contact_entries = []
    rejected_contacts = []

    with_import_file do |file|
      csv_reader(file).each do |row|
        row_hash = mapped_row_hash(row.to_h)
        duplicate = duplicate_contact?(row_hash)

        if ignore_duplicate? && duplicate
          @import_summary[:duplicate_records] += 1
          rejected_row = row.to_h
          rejected_row['errors'] = 'Contato duplicado ignorado pela politica da importacao'
          rejected_contacts << rejected_row
          next
        end

        current_contact = @contact_manager.build_contact(row_hash)
        if current_contact.valid?
          contact_entries << {
            contact: current_contact,
            duplicate: duplicate,
            existing: current_contact.persisted?
          }
        else
          append_rejected_contact(row, current_contact, rejected_contacts)
        end
      end
    end

    [contact_entries, rejected_contacts]
  end

  def mapped_row_hash(raw_row_hash)
    mapping = @data_import.metadata&.dig('column_mapping') || {}
    return raw_row_hash.with_indifferent_access if mapping.blank?

    raw_row_hash.each_with_object({}) do |(header, value), mapped_hash|
      target_key = mapped_column_key(mapping, header)
      next if target_key.blank? || target_key == '__ignore__'

      target_key = custom_attribute_key(header) if target_key == '__custom__'
      next if target_key.blank?

      assign_mapped_value(mapped_hash, target_key, value)
    end.with_indifferent_access
  end

  def mapped_column_key(mapping, header)
    target = mapping[header.to_s] || mapping[header.to_sym]
    target.presence || header.to_s
  end

  def custom_attribute_key(header)
    header.to_s.parameterize(separator: '_').presence || header.to_s.strip
  end

  def assign_mapped_value(mapped_hash, target_key, value)
    return if mapped_hash[target_key].present? && value.blank?

    mapped_hash[target_key] = if mapped_hash[target_key].present?
                                [mapped_hash[target_key], value].compact_blank.join(' ')
                              else
                                value
                              end
  end

  def append_rejected_contact(row, contact, rejected_contacts)
    rejected_row = row.to_h
    rejected_row['errors'] = contact.errors.full_messages.join(', ')
    rejected_contacts << rejected_row
  end

  def import_contacts(contact_entries, rejected_contacts)
    # Save one by one so label_list, CRM defaults and merged existing contacts run callbacks correctly.
    saved_count = 0
    contact_entries.each do |entry|
      contact = entry[:contact]
      contact.save!
      saved_count += 1
      record_import_summary(entry)
    rescue ActiveRecord::RecordInvalid => e
      rejected_contacts << rejected_row_from_contact(contact, e.record)
    end

    saved_count
  end

  def rejected_row_from_contact(contact, invalid_record)
    row = contact.attributes.slice('name', 'email', 'phone_number', 'identifier')
    row['errors'] = invalid_record.errors.full_messages.join(', ')
    row
  end

  def update_data_import_status(processed_records, rejected_records)
    total_records = processed_records + rejected_records
    metadata = (@data_import.metadata || {}).deep_dup
    metadata['import_summary'] = import_summary_payload(total_records, rejected_records)

    @data_import.update!(
      status: :completed,
      processed_records: processed_records,
      total_records: total_records,
      processing_errors: rejected_records.positive? ? "#{rejected_records} registros rejeitados" : nil,
      metadata: metadata
    )
  end

  def save_failed_records_csv(rejected_contacts)
    csv_data = generate_csv_data(rejected_contacts)
    return if csv_data.blank?

    @data_import.failed_records.attach(io: StringIO.new(csv_data), filename: "#{Time.zone.today.strftime('%Y%m%d')}_contacts.csv",
                                       content_type: 'text/csv')
  end

  def generate_csv_data(rejected_contacts)
    headers = csv_headers
    headers << 'errors'
    return if rejected_contacts.blank?

    CSV.generate do |csv|
      csv << headers
      rejected_contacts.each do |record|
        csv << headers.map { |header| record[header] }
      end
    end
  end

  def handle_csv_error(error)
    @data_import.update!(status: :failed, processing_errors: error.message)
    send_import_failed_notification_to_admin
  end

  def ignore_duplicate?
    @data_import.metadata&.dig('duplicate_strategy') == 'ignore'
  end

  def reset_import_summary
    @import_summary = {
      created_records: 0,
      updated_records: 0,
      duplicate_records: 0,
      rejected_records: 0,
      processed_records: 0
    }
  end

  def record_import_summary(entry)
    @import_summary[:duplicate_records] += 1 if entry[:duplicate]

    if entry[:existing]
      @import_summary[:updated_records] += 1
    else
      @import_summary[:created_records] += 1
    end
  end

  def import_summary_payload(processed_records, rejected_records)
    @import_summary[:processed_records] = processed_records
    @import_summary[:rejected_records] = rejected_records
    @import_summary.stringify_keys
  end

  def duplicate_contact?(params)
    identifier = params[:identifier].presence
    email = params[:email].presence
    phone_number = normalized_phone_number(params[:phone_number])

    contacts = @data_import.account.contacts
    return true if identifier.present? && contacts.exists?(identifier: identifier)
    return true if email.present? && contacts.from_email(email).present?
    return true if phone_number.present? && contacts.exists?(phone_number: phone_number)

    false
  end

  def normalized_phone_number(phone_number)
    normalized = phone_number.to_s.strip
    return normalized if normalized.start_with?('+') && normalized.match?(/\A\+\d+\z/)

    digits = normalized.gsub(/\D/, '')
    digits.present? ? "+#{digits}" : nil
  end

  def send_import_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).contact_import_complete(@data_import).deliver_later
  end

  def send_import_failed_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).contact_import_failed.deliver_later
  end

  def csv_headers
    header_row = nil
    with_import_file do |file|
      header_row = csv_reader(file).first
    end
    header_row&.headers || []
  end

  def csv_reader(file)
    file.rewind
    raw_data = file.read
    utf8_data = raw_data.force_encoding('UTF-8')
    clean_data = utf8_data.valid_encoding? ? utf8_data : utf8_data.encode('UTF-16le', invalid: :replace, replace: '').encode('UTF-8')

    CSV.new(StringIO.new(clean_data), headers: true)
  end

  def with_import_file
    temp_dir = Rails.root.join('tmp/imports')
    FileUtils.mkdir_p(temp_dir)

    @data_import.import_file.open(tmpdir: temp_dir) do |file|
      file.binmode
      yield file
    end
  end
end
