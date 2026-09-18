# 5.3 do PLANO_17_09.md — executa uma ação de automação agendada com delay.
#
# O StageAutomation grava o run como 'scheduled' e enfileira este job; aqui
# o run é atualizado para o resultado final. A regra é revalidada na hora
# da execução: deal que saiu da etapa ou regra desativada no intervalo não
# dispara (skip registrado no próprio run).
class Crm::AutomationActionJob < ApplicationJob
  queue_as :default

  def perform(rule_id, deal_id, actor = nil, run_id = nil)
    rule = CrmAutomationRule.find_by(id: rule_id)
    run = CrmAutomationRun.find_by(id: run_id)
    deal = rule&.account&.crm_deals&.find_by(id: deal_id)
    reason = skip_reason_for(rule, deal)
    return skip(run, reason) if reason

    Crm::StageAutomation.new(deal: deal, actor: actor).perform_scheduled(rule, run: run)
  end

  private

  # A regra é revalidada na hora da execução: deal que saiu da etapa ou
  # regra desativada/apagada no intervalo não dispara.
  def skip_reason_for(rule, deal)
    return 'rule_deleted' if rule.nil? || deal.nil?
    return 'rule_inactive' unless rule.is_active?
    return 'stage_changed' unless deal.crm_pipeline_stage_id == rule.crm_pipeline_stage_id
  end

  def skip(run, reason)
    return unless run

    run.update!(status: 'skipped', skip_reason: reason, finished_at: Time.current)
  end
end
