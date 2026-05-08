# == Schema Information
#
# Table name: labels
#
#  id              :bigint           not null, primary key
#  color           :string           default("#1f93ff"), not null
#  description     :text
#  show_on_sidebar :boolean
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint
#
# Indexes
#
#  index_labels_on_account_id            (account_id)
#  index_labels_on_title_and_account_id  (title,account_id) UNIQUE
#
class Label < ApplicationRecord
  include RegexHelper
  include AccountCacheRevalidator

  CRM_CATEGORIES = %w[
    area temperature relationship status document origin risk service
    location campaign custom restriction
  ].freeze
  CONTACT_CATEGORY_TYPES = %w[
    area temperature relationship status origin location campaign custom restriction
  ].freeze
  CRM_SCOPES = %w[contact conversation both].freeze
  CRM_SLUG_PREFIXES = {
    'area' => 'Area',
    'temp' => 'Temp',
    'rel' => 'Rel',
    'status' => 'Status',
    'doc' => 'Doc',
    'risk' => 'Risco',
    'origin' => 'Origem',
    'service' => 'Atendimento',
    'location' => 'Local',
    'campaign' => 'Campanha',
    'custom' => 'Categoria',
    'restriction' => 'Restricao'
  }.freeze
  CRM_DISPLAY_ACRONYMS = %w[rg cpf cnh cnis ctps bpc loas].freeze

  belongs_to :account

  validates :title,
            presence: { message: I18n.t('errors.validations.presence') },
            format: { with: UNICODE_CHARACTER_NUMBER_HYPHEN_UNDERSCORE },
            uniqueness: { scope: :account_id }
  validates :category, inclusion: { in: CRM_CATEGORIES }, allow_blank: true, if: -> { has_attribute?(:category) }
  validates :scope, inclusion: { in: CRM_SCOPES }, if: -> { has_attribute?(:scope) }
  validates :slug, uniqueness: { scope: :account_id }, allow_blank: true, if: -> { has_attribute?(:slug) }

  after_update_commit :update_associated_models
  default_scope { order(:title) }
  scope :contact_categories, lambda {
    where(category: CONTACT_CATEGORY_TYPES)
      .where(scope: [nil, '', 'contact', 'both'])
  }

  before_validation do
    self.title = title.downcase if attribute_present?('title')
    self.slug = slug.downcase.strip if has_attribute?(:slug) && slug.present?
    self.slug = title if has_attribute?(:slug) && slug.blank? && category.present? && title.present?
    self.scope = 'both' if has_attribute?(:scope) && scope.blank?
  end

  def crm_metadata
    {
      category: has_attribute?(:category) ? category : nil,
      slug: has_attribute?(:slug) ? slug : title,
      scope: has_attribute?(:scope) ? scope : 'both',
      is_system: has_attribute?(:is_system) ? is_system : false
    }
  end

  def display_title
    source = has_attribute?(:slug) && slug.present? ? slug : title
    prefix, name = source.to_s.split('.', 2)

    return humanized_label_title(source) if name.blank?

    [CRM_SLUG_PREFIXES.fetch(prefix, prefix.to_s.titleize), humanized_label_title(name)].join(' ')
  end

  def conversations
    account.conversations.tagged_with(title)
  end

  def messages
    account.messages.where(conversation_id: conversations.pluck(:id))
  end

  def reporting_events
    account.reporting_events.where(conversation_id: conversations.pluck(:id))
  end

  private

  def update_associated_models
    return unless title_previously_changed?

    Labels::UpdateJob.perform_later(title, title_previously_was, account_id)
  end

  def humanized_label_title(value)
    value.to_s.split(/[_\s-]+/).map do |part|
      CRM_DISPLAY_ACRONYMS.include?(part) ? part.upcase : part.titleize
    end.join(' ')
  end
end
