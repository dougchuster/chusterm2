module Crm
  class ContactBackfillService
    def initialize(account: nil, limit: nil)
      @account = account
      @limit = limit
      @stats = Hash.new(0)
    end

    def perform
      contacts_scope.find_each do |contact|
        backfill_contact(contact)
      rescue StandardError => e
        @stats[:failed] += 1
        Rails.logger.warn("[CRM] contact backfill failed for contact #{contact.id}: #{e.message}")
      end

      @stats
    end

    private

    def contacts_scope
      scope = @account ? @account.contacts : Contact.all
      scope = scope.order(:id).limit(@limit) if @limit.present?
      scope
    end

    def backfill_contact(contact)
      ActiveRecord::Base.transaction do
        normalize_crm_fields(contact)
        Crm::ContactLifecycleManager.recalculate(contact)
        assign_owner_from_latest_conversation(contact)
        sync_open_deal_owners(contact)
      end
      @stats[:processed] += 1
    end

    def normalize_crm_fields(contact)
      now = Time.current
      updates = {}

      if contact.has_attribute?(:relationship_status) && contact.relationship_status.blank?
        updates[:relationship_status] = contact.customer? ? 'customer' : 'lead'
      end

      if contact.has_attribute?(:lifecycle_stage) && contact.lifecycle_stage.blank?
        updates[:lifecycle_stage] = updates[:relationship_status] == 'customer' || contact.customer? ? 'customer' : inferred_lead_stage(contact)
      end

      updates[:lifecycle_stage_changed_at] = now if contact.has_attribute?(:lifecycle_stage_changed_at) && contact.lifecycle_stage_changed_at.blank?
      updates[:became_lead_at] = now if contact.has_attribute?(:became_lead_at) && contact.became_lead_at.blank? && updates.fetch(:relationship_status, contact.crm_relationship_status) == 'lead'
      updates[:became_customer_at] = now if contact.has_attribute?(:became_customer_at) && contact.became_customer_at.blank? && updates.fetch(:relationship_status, contact.crm_relationship_status) == 'customer'

      return if updates.blank?

      contact.update_columns(updates)
      @stats[:normalized] += 1
      contact.reload
    end

    def inferred_lead_stage(contact)
      contact.name.present? || contact.phone_number.present? || contact.email.present? ? 'lead' : 'visitor'
    end

    def assign_owner_from_latest_conversation(contact)
      return if !contact.has_attribute?(:crm_owner_id) || contact.crm_owner_id.present?

      assignee = contact.conversations.where.not(assignee_id: nil).order(updated_at: :desc).first&.assignee
      return if assignee.blank?

      contact.assign_crm_owner!(assignee, source: 'assignee')
      @stats[:owner_assigned] += 1
    end

    def sync_open_deal_owners(contact)
      return if !contact.has_attribute?(:crm_owner_id) || contact.crm_owner_id.blank?

      updated = CrmDeal.open_deals.where(account: contact.account, contact: contact, owner_id: nil).update_all(
        owner_id: contact.crm_owner_id,
        updated_at: Time.current
      )
      @stats[:deals_owner_synced] += updated
    end
  end
end
