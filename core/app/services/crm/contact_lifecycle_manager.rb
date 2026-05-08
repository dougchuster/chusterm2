module Crm
  class ContactLifecycleManager
    STAGES = %w[visitor lead qualified_lead triage consultation_scheduled
                customer active_customer recurring_customer ex_customer lost].freeze

    LEGACY_STAGE_ALIASES = {
      'lead_qualified' => 'qualified_lead',
      'in_triage' => 'triage',
      'recurring' => 'recurring_customer'
    }.freeze

    STAGE_LABELS = {
      'visitor' => 'Visitante',
      'lead' => 'Lead',
      'qualified_lead' => 'Lead Qualificado',
      'triage' => 'Em Triagem',
      'consultation_scheduled' => 'Consulta Agendada',
      'customer' => 'Cliente',
      'active_customer' => 'Cliente Ativo',
      'recurring_customer' => 'Recorrente',
      'ex_customer' => 'Ex-Cliente',
      'lost' => 'Perdido'
    }.freeze

    def initialize(contact)
      @contact = contact
    end

    def self.recalculate(contact)
      new(contact).recalculate
    end

    def recalculate
      new_stage = compute_stage
      update_kpis
      return if new_stage == normalized_stage(@contact.lifecycle_stage)

      old_stage = @contact.lifecycle_stage
      now = Time.current

      attrs = { lifecycle_stage: new_stage, lifecycle_stage_changed_at: now }
      attrs[:relationship_status] = relationship_status_for(new_stage) if @contact.has_attribute?(:relationship_status)
      attrs[:contact_type] = contact_type_for(new_stage) if @contact.has_attribute?(:contact_type)
      attrs[:became_lead_at] = now if new_stage == 'lead' && @contact.became_lead_at.nil?
      attrs[:became_customer_at] = now if customer_stage?(new_stage) && @contact.became_customer_at.nil?

      @contact.update_columns(attrs)

      log_stage_change(old_stage, new_stage)
    end

    private

    def compute_stage
      deals = crm_deals

      return 'recurring_customer' if won_deals(deals).count >= 2
      return 'active_customer' if won_deals(deals).any? && deals.where(status: 'open').any?
      return 'customer' if won_deals(deals).any?
      return 'consultation_scheduled' if has_pending_meeting?
      return 'triage' if deals.where(status: 'open').any?
      return 'qualified_lead' if deals.any? { |deal| deal.score_total.to_i >= 40 }
      return 'lead' if @contact.name.present? || @contact.phone_number.present?

      last_interaction = @contact.last_crm_interaction_at
      if normalized_stage(@contact.lifecycle_stage).in?(%w[customer active_customer recurring_customer]) &&
         last_interaction.present? && last_interaction < 12.months.ago
        return 'ex_customer'
      end

      'visitor'
    end

    def update_kpis
      deals = crm_deals
      won = won_deals(deals)

      total_value = won.sum(:value_estimate_cents)
      first_won = won.minimum(:closed_at)

      updates = {
        total_deals_count: deals.count,
        won_deals_count: won.count,
        lifetime_value_cents: total_value || 0,
        last_crm_interaction_at: deals.maximum(:updated_at) || @contact.last_crm_interaction_at
      }
      updates[:first_deal_won_at] = first_won if first_won && @contact.first_deal_won_at.nil?

      @contact.update_columns(updates)
    end

    def crm_deals
      CrmDeal.where(account: @contact.account, contact: @contact)
    end

    def won_deals(scope)
      scope.where(status: 'won')
    end

    def has_pending_meeting?
      CrmActivity
        .joins(:crm_deal)
        .where(crm_deals: { contact_id: @contact.id, account_id: @contact.account_id })
        .where(kind: 'meeting', completed_at: nil)
        .where('due_at >= ?', Time.current)
        .exists?
    end

    def log_stage_change(from_stage, to_stage)
      Crm::AuditLogger.log(
        account: @contact.account,
        action: 'contact_lifecycle_changed',
        target: @contact,
        payload: {
          from: from_stage,
          to: to_stage,
          from_label: STAGE_LABELS[normalized_stage(from_stage)],
          to_label: STAGE_LABELS[to_stage]
        }
      )
    end

    def normalized_stage(stage)
      LEGACY_STAGE_ALIASES.fetch(stage, stage)
    end

    def customer_stage?(stage)
      stage.in?(%w[customer active_customer recurring_customer ex_customer])
    end

    def relationship_status_for(stage)
      customer_stage?(stage) ? 'customer' : 'lead'
    end

    def contact_type_for(stage)
      customer_stage?(stage) ? Contact.contact_types[:customer] : Contact.contact_types[:lead]
    end
  end
end
