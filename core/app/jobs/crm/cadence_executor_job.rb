class Crm::CadenceExecutorJob < ApplicationJob
  queue_as :default

  # Executado pelo sidekiq-cron (ver config/sidekiq_cron.yml)
  # Padrao: a cada hora
  def perform
    CrmCadenceEnrollment.due.find_each do |enrollment|
      execute_step(enrollment)
    rescue StandardError => e
      ChusteRMExceptionTracker.new(e, account: enrollment.account).capture_exception
      Rails.logger.error "CadenceExecutor error on enrollment ##{enrollment.id}: #{e.message}"
    end
  end

  private

  def execute_step(enrollment)
    step = enrollment.current_step
    return enrollment.cancel! unless step
    return handle_condition_miss(enrollment, step) unless conditions_match?(enrollment, step)

    case step.action_type
    when 'create_activity'
      execute_create_activity(enrollment, step)
    when 'send_message'
      execute_send_message(enrollment, step)
    when 'wait'
      # Wait is implicit via wait_hours — just advance
    end

    enrollment.advance!

    Crm::AuditLogger.log(
      account: enrollment.account,
      actor: nil,
      action: 'cadence_step_executed',
      target: enrollment.crm_deal,
      payload: {
        cadence_id: enrollment.crm_cadence_id,
        step_id: step.id,
        step_name: step.name,
        action_type: step.action_type,
        conditions: step.action_config&.[]('conditions')
      }
    )
  end

  def conditions_match?(enrollment, step)
    Crm::CadenceConditionEvaluator.new(
      deal: enrollment.crm_deal,
      contact: enrollment.crm_deal.contact,
      conditions: step.action_config&.[]('conditions')
    ).matches?
  end

  def handle_condition_miss(enrollment, step)
    behavior = step.action_config&.[]('condition_miss') || 'skip_step'
    case behavior
    when 'pause_enrollment'
      enrollment.pause!
    when 'cancel_enrollment'
      enrollment.cancel!
    else
      enrollment.advance!
    end

    Crm::AuditLogger.log(
      account: enrollment.account,
      actor: nil,
      action: 'cadence_step_skipped_by_condition',
      target: enrollment.crm_deal,
      payload: {
        cadence_id: enrollment.crm_cadence_id,
        step_id: step.id,
        step_name: step.name,
        condition_miss: behavior,
        conditions: step.action_config&.[]('conditions')
      }
    )
  end

  def execute_create_activity(enrollment, step)
    deal = enrollment.crm_deal
    config = step.action_config || {}

    deal.crm_activities.create!(
      account: enrollment.account,
      contact_id: deal.contact_id,
      kind: config['kind'] || 'follow_up',
      title: config['title'] || step.name,
      description: config['description'] || step.template_body,
      priority: config['priority'] || 'normal',
      due_at: 2.hours.from_now
    )
  end

  def execute_send_message(enrollment, step)
    deal = enrollment.crm_deal
    contact = deal.contact
    return unless contact&.phone_number.present?

    config = step.action_config || {}
    body = interpolate_template(step.template_body || '', deal, contact)

    # Dispatch via WhatsApp (Evolution API)
    Crm::CadenceMessageSenderJob.perform_later(
      enrollment_id: enrollment.id,
      step_id: step.id,
      body: body
    )
  end

  def interpolate_template(template, deal, contact)
    template
      .gsub('{{nome}}', contact.name || 'Cliente')
      .gsub('{{deal_title}}', deal.title || '')
      .gsub('{{stage}}', deal.crm_pipeline_stage&.name || '')
      .gsub('{{area}}', deal.legal_area || '')
  end
end
