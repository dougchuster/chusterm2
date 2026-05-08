module Crm
  class ContactOwnerRouter
    HOT_LEAD_ACTIVITY_TITLE = 'Atribuir responsavel ao lead quente'.freeze

    def initialize(deal:, conversation:, triage: {}, actor: nil)
      @deal = deal
      @conversation = conversation
      @triage = triage.with_indifferent_access
      @contact = deal.contact || conversation&.contact
      @account = deal.account
      @actor = actor
    end

    def perform
      return if @contact.blank?

      assign_owner_from_conversation
      assign_owner_from_legal_area
      sync_deal_owner
      sync_hot_lead_alert
    end

    private

    def assign_owner_from_conversation
      return if @contact.crm_owner_id.present?
      return if @conversation&.assignee.blank?

      @contact.assign_crm_owner!(@conversation.assignee, source: 'assignee', actor: @actor)
    end

    def assign_owner_from_legal_area
      return if @contact.crm_owner_id.present?

      owner = area_owner
      return if owner.blank?

      @contact.assign_crm_owner!(owner, source: 'routing_rule', actor: @actor)
      Crm::AuditLogger.log(
        account: @account,
        actor: @actor,
        action: 'contact_crm_owner_routed_by_area',
        target: @deal,
        payload: { contact_id: @contact.id, legal_area: legal_area, owner_id: owner.id }
      )
    end

    def sync_deal_owner
      owner_id = @contact.crm_owner_id
      return if owner_id.blank?
      return if @deal.owner_id == owner_id

      @deal.update!(owner_id: owner_id)
    end

    def sync_hot_lead_alert
      return clear_hot_lead_alert if @contact.crm_owner_id.present?
      return clear_hot_lead_alert unless hot_lead?

      create_hot_lead_alert
    end

    def hot_lead?
      @deal.score_total.to_i >= 60 ||
        @triage[:urgency_level].to_s.in?(%w[alta critica]) ||
        @triage[:intent].to_s.in?(%w[contratacao orcamento])
    end

    def create_hot_lead_alert
      return if pending_hot_lead_alert.exists?

      @deal.crm_activities.create!(
        account: @account,
        contact_id: @contact.id,
        conversation_id: @conversation&.id || @deal.conversation_id,
        kind: 'revisao_juridica',
        title: HOT_LEAD_ACTIVITY_TITLE,
        description: 'Lead com prioridade alta ainda sem responsavel principal no CRM.',
        priority: hot_lead_priority,
        due_at: hot_lead_due_at,
        created_by_type: 'system'
      )

      Crm::AuditLogger.log(
        account: @account,
        actor: @actor,
        action: 'hot_lead_without_owner_alerted',
        target: @deal,
        payload: { contact_id: @contact.id, score_total: @deal.score_total, urgency_level: @triage[:urgency_level] }
      )
    end

    def clear_hot_lead_alert
      pending_hot_lead_alert.find_each do |activity|
        activity.complete!(
          outcome: 'Alerta encerrado: contato recebeu responsavel ou deixou de ser lead quente sem owner.',
          actor: @actor
        )
      end
    end

    def pending_hot_lead_alert
      @deal.crm_activities.pending.where(kind: 'revisao_juridica', title: HOT_LEAD_ACTIVITY_TITLE, created_by_type: 'system')
    end

    def area_owner
      owner_id = area_owner_id
      return if owner_id.blank?

      @account.users.find_by(id: owner_id)
    end

    def area_owner_id
      area = legal_area
      return if area.blank?

      routing_area_owner_ids[area].presence ||
        routing_area_owner_ids[area.tr('-', '_')].presence ||
        routing_area_owner_ids[area.tr('_', '-')].presence
    end

    def routing_area_owner_ids
      @routing_area_owner_ids ||= begin
        config = captain_inbox&.routing_config || {}
        raw_mapping = config['area_owner_ids'] || config[:area_owner_ids] ||
                      config['legal_area_owner_ids'] || config[:legal_area_owner_ids] ||
                      config['area_owners'] || config[:area_owners] || {}
        raw_mapping.to_h.transform_keys { |key| key.to_s.strip.downcase }
      end
    end

    def captain_inbox
      return if @conversation&.inbox.blank?

      @captain_inbox ||= CaptainInbox.find_by(inbox: @conversation.inbox)
    end

    def legal_area
      @legal_area ||= (@deal.legal_area.presence || @triage[:legal_area].presence).to_s.strip.downcase.presence
    end

    def hot_lead_priority
      @triage[:urgency_level].to_s == 'critica' || @deal.score_total.to_i >= 80 ? 'critica' : 'alta'
    end

    def hot_lead_due_at
      hot_lead_priority == 'critica' ? 2.hours.from_now : 6.hours.from_now
    end
  end
end
