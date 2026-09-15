# rubocop:disable Layout/LineLength

# == Schema Information
#
# Table name: contacts
#
#  id                    :integer          not null, primary key
#  additional_attributes :jsonb
#  blocked               :boolean          default(FALSE), not null
#  contact_type          :integer          default("visitor")
#  country_code          :string           default("")
#  custom_attributes     :jsonb
#  email                 :string
#  identifier            :string
#  last_activity_at      :datetime
#  last_name             :string           default("")
#  location              :string           default("")
#  middle_name           :string           default("")
#  name                  :string           default("")
#  phone_number          :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#  company_id            :bigint
#
# Indexes
#
#  index_contacts_on_account_id                          (account_id)
#  index_contacts_on_account_id_and_contact_type         (account_id,contact_type)
#  index_contacts_on_account_id_and_last_activity_at     (account_id,last_activity_at DESC NULLS LAST)
#  index_contacts_on_blocked                             (blocked)
#  index_contacts_on_company_id                          (company_id)
#  index_contacts_on_lower_email_account_id              (lower((email)::text), account_id)
#  index_contacts_on_name_email_phone_number_identifier  (name,email,phone_number,identifier) USING gin
#  index_contacts_on_nonempty_fields                     (account_id,email,phone_number,identifier) WHERE (((email)::text <> ''::text) OR ((phone_number)::text <> ''::text) OR ((identifier)::text <> ''::text))
#  index_contacts_on_phone_number_and_account_id         (phone_number,account_id)
#  index_resolved_contact_account_id                     (account_id) WHERE (((email)::text <> ''::text) OR ((phone_number)::text <> ''::text) OR ((identifier)::text <> ''::text))
#  uniq_email_per_account_contact                        (email,account_id) UNIQUE
#  uniq_identifier_per_account_contact                   (identifier,account_id) UNIQUE
#

# rubocop:enable Layout/LineLength

class Contact < ApplicationRecord
  include Avatarable
  include AvailabilityStatusable
  include Labelable
  include LlmFormattable

  validates :account_id, presence: true
  validates :email, allow_blank: true, uniqueness: { scope: [:account_id], case_sensitive: false },
                    format: { with: Devise.email_regexp, message: I18n.t('errors.contacts.email.invalid') }
  validates :identifier, allow_blank: true, uniqueness: { scope: [:account_id] }
  validates :phone_number,
            allow_blank: true, uniqueness: { scope: [:account_id] },
            format: { with: /\A\+[1-9]\d{1,14}\z/, message: I18n.t('errors.contacts.phone_number.invalid') }

  belongs_to :account
  has_many :conversations, dependent: :destroy_async
  has_many :contact_inboxes, dependent: :destroy_async
  has_many :csat_survey_responses, dependent: :destroy_async
  has_many :inboxes, through: :contact_inboxes
  has_many :messages, as: :sender, dependent: :destroy_async
  has_many :notes, dependent: :destroy_async
  has_many :crm_deals, dependent: :nullify
  belongs_to :crm_owner, class_name: 'User', optional: true
  before_validation :prepare_contact_attributes, :normalize_crm_attributes
  after_create_commit :dispatch_create_event, :ip_lookup
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event
  before_save :sync_contact_attributes

  enum contact_type: { visitor: 0, lead: 1, customer: 2 }

  CRM_RELATIONSHIP_STATUSES = %w[lead customer].freeze
  CRM_LIFECYCLE_STAGES = %w[
    visitor lead qualified_lead triage consultation_scheduled customer
    active_customer recurring_customer ex_customer lost lead_qualified in_triage recurring
  ].freeze
  CAMPAIGN_OPT_OUT_VALUES = [true, 'true', '1', 1, 'yes', 'sim'].freeze

  validates :relationship_status, inclusion: { in: CRM_RELATIONSHIP_STATUSES }, if: -> { has_attribute?(:relationship_status) }
  validates :lifecycle_stage, inclusion: { in: CRM_LIFECYCLE_STAGES }, if: -> { has_attribute?(:lifecycle_stage) }
  validates :crm_owner_source, inclusion: { in: %w[manual assignee routing_rule captain import] }, allow_blank: true,
                               if: -> { has_attribute?(:crm_owner_source) }

  scope :order_on_last_activity_at, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"contacts\".\"last_activity_at\" #{direction}
          NULLS LAST")
      )
    )
  }
  scope :order_on_created_at, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"contacts\".\"created_at\" #{direction}
          NULLS LAST")
      )
    )
  }
  scope :order_on_company_name, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "\"contacts\".\"additional_attributes\"->>'company_name' #{direction}
          NULLS LAST"
        )
      )
    )
  }
  scope :order_on_city, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "\"contacts\".\"additional_attributes\"->>'city' #{direction}
          NULLS LAST"
        )
      )
    )
  }
  scope :order_on_country_name, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "\"contacts\".\"additional_attributes\"->>'country' #{direction}
          NULLS LAST"
        )
      )
    )
  }

  scope :order_on_name, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "CASE
           WHEN \"contacts\".\"name\" ~~* '^+\d*' THEN 'z'
           WHEN \"contacts\".\"name\"  ~~*  '^\b*' THEN 'z'
           ELSE LOWER(\"contacts\".\"name\")
           END #{direction}"
        )
      )
    )
  }

  # Find contacts that:
  # 1. Have no identification (email, phone_number, and identifier are NULL or empty string)
  # 2. Have no conversations
  # 3. Are older than the specified time period
  scope :stale_without_conversations, lambda { |time_period|
    where('contacts.email IS NULL OR contacts.email = ?', '')
      .where('contacts.phone_number IS NULL OR contacts.phone_number = ?', '')
      .where('contacts.identifier IS NULL OR contacts.identifier = ?', '')
      .where('contacts.created_at < ?', time_period)
      .where.missing(:conversations)
  }

  def get_source_id(inbox_id)
    contact_inboxes.find_by!(inbox_id: inbox_id).source_id
  end

  def campaign_opted_out?
    CAMPAIGN_OPT_OUT_VALUES.include?(additional_attributes&.[]('campaign_opt_out')) ||
      CAMPAIGN_OPT_OUT_VALUES.include?(additional_attributes&.[](:campaign_opt_out))
  end

  def campaign_opt_out!(source: nil, campaign: nil)
    attrs = (additional_attributes || {}).merge(
      'campaign_opt_out' => true,
      'campaign_opt_out_at' => Time.current.iso8601
    )
    attrs['campaign_opt_out_source'] = source if source.present?
    attrs['campaign_opt_out_campaign_id'] = campaign.id if campaign.present?
    update!(additional_attributes: attrs)
  end

  def push_event_data
    {
      additional_attributes: additional_attributes,
      custom_attributes: custom_attributes,
      email: email,
      id: id,
      identifier: identifier,
      name: name,
      phone_number: phone_number,
      thumbnail: avatar_url,
      blocked: blocked,
      relationship_status: crm_relationship_status,
      lifecycle_stage: crm_lifecycle_stage,
      crm_owner: crm_owner_push_event_data,
      type: 'contact'
    }
  end

  def webhook_data
    {
      account: account.webhook_data,
      additional_attributes: additional_attributes,
      avatar: avatar_url,
      custom_attributes: custom_attributes,
      email: email,
      id: id,
      identifier: identifier,
      name: name,
      phone_number: phone_number,
      thumbnail: avatar_url,
      blocked: blocked,
      relationship_status: crm_relationship_status,
      lifecycle_stage: crm_lifecycle_stage,
      crm_owner: crm_owner_push_event_data
    }
  end

  def crm_relationship_status
    return relationship_status if has_attribute?(:relationship_status) && relationship_status.present?

    customer? ? 'customer' : 'lead'
  end

  def crm_lifecycle_stage
    return lifecycle_stage if has_attribute?(:lifecycle_stage) && lifecycle_stage.present?

    crm_relationship_status == 'customer' ? 'customer' : 'lead'
  end

  def assign_crm_owner!(owner, source: 'manual', actor: nil)
    previous_owner_id = crm_owner_id if has_attribute?(:crm_owner_id)
    update!(
      crm_owner: owner,
      crm_owner_assigned_at: Time.current,
      crm_owner_source: source
    )
    Crm::AuditLogger.log(
      account: account,
      action: 'contact_crm_owner_changed',
      target: self,
      actor: actor,
      payload: { from: previous_owner_id, to: owner&.id, source: source }
    )
  end

  def self.resolved_contacts(use_crm_v2: false)
    identified_contacts = where("contacts.email <> '' OR contacts.phone_number <> '' OR contacts.identifier <> ''")
    return identified_contacts unless use_crm_v2

    where(contact_type: %i[lead customer]).or(identified_contacts)
  end

  def discard_invalid_attrs
    phone_number_format
    email_format
  end

  def self.from_email(email)
    find_by(email: email&.downcase)
  end

  private

  def ip_lookup
    return unless account.feature_enabled?('ip_lookup')

    ContactIpLookupJob.perform_later(self)
  end

  def phone_number_format
    return if phone_number.blank?

    self.phone_number = phone_number_was unless phone_number.match?(/\+[1-9]\d{1,14}\z/)
  end

  def email_format
    return if email.blank?

    self.email = email_was unless email.match(Devise.email_regexp)
  end

  def prepare_contact_attributes
    prepare_email_attribute
    prepare_jsonb_attributes
  end

  def normalize_crm_attributes
    return unless has_attribute?(:relationship_status)

    self.relationship_status = customer? ? 'customer' : 'lead' if relationship_status.blank?
    self.lifecycle_stage = normalized_crm_lifecycle_stage if has_attribute?(:lifecycle_stage) && lifecycle_stage.present?
  end

  def normalized_crm_lifecycle_stage
    {
      'lead_qualified' => 'qualified_lead',
      'in_triage' => 'triage',
      'recurring' => 'recurring_customer'
    }.fetch(lifecycle_stage, lifecycle_stage)
  end

  def prepare_email_attribute
    # So that the db unique constraint won't throw error when email is ''
    self.email = email.present? ? email.downcase : nil
  end

  def prepare_jsonb_attributes
    self.additional_attributes = {} if additional_attributes.blank?
    self.custom_attributes = {} if custom_attributes.blank?
  end

  def sync_contact_attributes
    ::Contacts::SyncAttributes.new(self).perform
  end

  def crm_owner_push_event_data
    return if !has_attribute?(:crm_owner_id) || crm_owner.blank?

    crm_owner.push_event_data
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(CONTACT_CREATED, Time.zone.now, contact: self)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(CONTACT_UPDATED, Time.zone.now, contact: self, changed_attributes: previous_changes)
  end

  def dispatch_destroy_event
    # Pass serialized data instead of ActiveRecord object to avoid DeserializationError
    # when the async EventDispatcherJob runs after the contact has been deleted
    Rails.configuration.dispatcher.dispatch(
      CONTACT_DELETED,
      Time.zone.now,
      contact_data: push_event_data.merge(account_id: account_id)
    )
  end
end
Contact.include_mod_with('Concerns::Contact')
