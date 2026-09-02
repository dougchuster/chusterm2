# frozen_string_literal: true

class Crm::ContactRelationshipClassifier
  CUSTOMER_STAGES = %w[customer active_customer recurring_customer ex_customer].freeze

  def initialize(contact)
    @contact = contact
  end

  def perform
    return unknown_result if @contact.blank?

    evidence = customer_evidence
    return customer_result(evidence) if evidence.any?

    lead_result
  end

  private

  def customer_evidence
    evidence = []
    evidence << evidence_item('won_deal', 'Negócio marcado como ganho no CRM.', 1.0) if won_deal?
    evidence << evidence_item('relationship_status', 'Relacionamento confirmado como cliente.', 0.98) if relationship_customer?
    evidence << evidence_item('lifecycle_stage', "Etapa de ciclo: #{lifecycle_stage}.", 0.95) if customer_lifecycle?
    evidence << evidence_item('contact_type', 'Tipo do contato confirmado como cliente.', 0.9) if contact_type_customer?
    evidence
  end

  def customer_result(evidence)
    {
      status: 'customer',
      label: 'Cliente',
      confidence: evidence.pluck(:weight).max,
      evidence: evidence,
      automatic_handoff: false
    }
  end

  def lead_result
    evidence = []
    evidence << evidence_item('open_deal', 'Existe oportunidade aberta no CRM.', 0.85) if open_deal?
    evidence << evidence_item('relationship_status', 'Relacionamento atual registrado como lead.', 0.8) if relationship_lead?
    evidence << evidence_item('lifecycle_stage', "Etapa de ciclo: #{lifecycle_stage}.", 0.75) if lifecycle_stage.present?

    {
      status: 'lead',
      label: 'Lead',
      confidence: evidence.pluck(:weight).max || 0.55,
      evidence: evidence.presence || [evidence_item('default', 'Ainda não há evidência suficiente de vínculo como cliente.', 0.55)],
      automatic_handoff: false
    }
  end

  def unknown_result
    {
      status: 'unknown',
      label: 'Não identificado',
      confidence: 0.0,
      evidence: [],
      automatic_handoff: false
    }
  end

  def won_deal?
    deals.exists?(status: 'won')
  end

  def open_deal?
    deals.exists?(status: 'open')
  end

  def deals
    @deals ||= CrmDeal.where(account_id: @contact.account_id, contact_id: @contact.id)
  end

  def relationship_customer?
    @contact.respond_to?(:crm_relationship_status) && @contact.crm_relationship_status == 'customer'
  end

  def relationship_lead?
    @contact.respond_to?(:crm_relationship_status) && @contact.crm_relationship_status == 'lead'
  end

  def contact_type_customer?
    @contact.respond_to?(:customer?) && @contact.customer?
  end

  def customer_lifecycle?
    CUSTOMER_STAGES.include?(lifecycle_stage)
  end

  def lifecycle_stage
    @lifecycle_stage ||= @contact.respond_to?(:crm_lifecycle_stage) ? @contact.crm_lifecycle_stage.to_s : ''
  end

  def evidence_item(code, description, weight)
    { code: code, description: description, weight: weight }
  end
end
