# frozen_string_literal: true

module Crm
  class SavedContactCustomerClassifier
    CUSTOMER_STAGES = %w[customer active_customer recurring_customer ex_customer].freeze

    def self.customer_contact?(contact)
      return false if contact.blank?
      return true if contact.respond_to?(:customer?) && contact.customer?
      return true if contact.respond_to?(:crm_relationship_status) && contact.crm_relationship_status == 'customer'

      stage = contact.respond_to?(:crm_lifecycle_stage) ? contact.crm_lifecycle_stage : contact.try(:lifecycle_stage)
      CUSTOMER_STAGES.include?(stage.to_s)
    end

    def self.promote!(contact, source:, metadata: {})
      new(contact, source: source, metadata: metadata).promote!
    end

    def initialize(contact, source:, metadata: {})
      @contact = contact
      @source = source
      @metadata = metadata || {}
    end

    def promote!
      return false if @contact.blank?

      updates = {
        additional_attributes: @contact.additional_attributes.to_h.merge(customer_metadata)
      }
      updates[:contact_type] = 'customer' if @contact.respond_to?(:customer?) && !@contact.customer?
      updates[:relationship_status] = 'customer' if @contact.has_attribute?(:relationship_status) && @contact.relationship_status != 'customer'
      updates[:lifecycle_stage] = 'customer' if should_update_lifecycle_stage?
      updates[:lifecycle_stage_changed_at] = Time.current if updates[:lifecycle_stage] && @contact.has_attribute?(:lifecycle_stage_changed_at)
      updates[:became_customer_at] = Time.current if @contact.has_attribute?(:became_customer_at) && @contact.became_customer_at.blank?

      @contact.update!(updates)
      true
    end

    private

    def should_update_lifecycle_stage?
      return false unless @contact.has_attribute?(:lifecycle_stage)

      !CUSTOMER_STAGES.include?(@contact.lifecycle_stage.to_s)
    end

    def customer_metadata
      {
        'saved_contact_customer' => true,
        'saved_contact_customer_source' => @source,
        'saved_contact_customer_at' => Time.current.iso8601
      }.merge(@metadata.transform_keys(&:to_s).compact)
    end
  end
end
