# frozen_string_literal: true

# 3.1 do PLANO_17_09.md — tools de CRM auditadas que a IA (Capitão /
# orchestrator) pode chamar. Cada operação:
#
#   * é whitelistada e validada contra a taxonomia do pack da conta;
#   * grava via os services/modelos existentes (DealMover, CrmActivity…);
#   * audita com actor_type 'ai' — a ficha mostra "IA classificou como X".
#
# Uso:
#   tools = Crm::Tools.new(deal: deal, conversation: conversation)
#   tools.set_category('consulta', reason: 'cliente pediu avaliação')
class Crm::Tools
  Result = Struct.new(:ok, :data, :error, keyword_init: true) do
    def ok?
      ok
    end
  end

  def initialize(deal:, conversation: nil, actor: :ai)
    @deal = deal
    @conversation = conversation || deal.conversation
    @account = deal.account
    @actor = actor
  end

  # Snapshot que a IA recebe antes de decidir — mesmo contrato da ficha.
  # O nome público `get_deal_context` é o contrato da tool (Fase 3).
  def deal_context
    Result.new(ok: true, data: {
                 deal_id: @deal.id,
                 title: @deal.title,
                 status: @deal.status,
                 stage: @deal.crm_pipeline_stage&.slug,
                 category: @deal.category.presence || @deal.legal_area,
                 subcategory: @deal.subcategory,
                 urgency_level: @deal.urgency_level,
                 score_total: @deal.score_total,
                 owner_id: @deal.owner_id,
                 custom_fields: @deal.custom_fields,
                 allowed_categories: allowed_category_values,
                 allowed_stages: allowed_stage_slugs,
                 allowed_fields: allowed_field_keys
               })
  end

  alias get_deal_context deal_context

  def set_category(value, subcategory: nil, reason: nil)
    return fail_result("categoria '#{value}' não existe no pack da conta") unless allowed_category_values.include?(value.to_s)

    @deal.update!(category: value.to_s, subcategory: subcategory&.to_s)
    audit('ai_set_category', category: value, subcategory: subcategory, reason: reason)
    Result.new(ok: true, data: { category: @deal.category, subcategory: @deal.subcategory })
  end

  def set_urgency(level, reason: nil)
    return fail_result("urgência '#{level}' inválida") unless %w[baixa media alta critica].include?(level.to_s)

    @deal.update!(urgency_level: level.to_s)
    audit('ai_set_urgency', urgency_level: level, reason: reason)
    Result.new(ok: true, data: { urgency_level: @deal.urgency_level })
  end

  # Só campos declarados no pack da conta — a IA nunca escreve chave livre.
  # Conta legada sem pack: pode atualizar chave já presente em custom_fields,
  # mas não inventar novas.
  def set_field(key, value, reason: nil)
    allowed = allowed_field_keys.include?(key.to_s) || (@deal.custom_fields || {}).key?(key.to_s)
    return fail_result("campo '#{key}' não está nos field_definitions do pack") unless allowed

    @deal.update!(custom_fields: (@deal.custom_fields || {}).merge(key.to_s => value))
    audit('ai_set_field', key: key, value: value, reason: reason)
    Result.new(ok: true, data: { key: key.to_s, value: value })
  end

  def move_stage(slug, reason: nil)
    stage = allowed_stages.find_by(slug: slug.to_s)
    return fail_result("etapa '#{slug}' não existe neste funil") unless stage

    Crm::DealMover.new(deal: @deal, stage_id: stage.id, actor: nil).perform
    audit('ai_moved_stage', stage: slug, reason: reason)
    Result.new(ok: true, data: { stage: slug.to_s })
  end

  def create_activity(kind:, title:, due_at: nil, description: nil)
    return fail_result("tipo de atividade '#{kind}' não existe no pack") unless allowed_activity_keys.include?(kind.to_s)

    activity = @deal.crm_activities.create!(
      account: @account,
      contact_id: @deal.contact_id,
      conversation_id: @conversation&.id,
      kind: kind.to_s,
      title: title,
      description: description,
      due_at: due_at,
      created_by_type: 'ai'
    )
    audit('ai_created_activity', activity_id: activity.id, kind: kind, title: title)
    Result.new(ok: true, data: { activity_id: activity.id })
  end

  # Agendamento é uma atividade com horário marcado — sem tabela nova.
  def schedule_appointment(at:, title: 'Agendamento', note: nil)
    activity = create_activity(kind: appointment_kind, title: title, due_at: at, description: note)
    return activity unless activity.ok?

    audit('ai_scheduled_appointment', activity_id: activity.data[:activity_id], at: at)
    activity
  end

  # Pede dado que falta — cria mensagem outgoing na conversa do deal.
  def request_info(message)
    return fail_result('deal sem conversa para pedir informação') unless @conversation

    Messages::MessageBuilder.new(nil, @conversation, { content: message, message_type: 'outgoing' }).perform
    audit('ai_requested_info', message: message.to_s.truncate(200))
    Result.new(ok: true, data: { conversation_id: @conversation.id })
  end

  def mark_qualified(reason: nil)
    stage = allowed_stages.find_by(slug: 'qualificado') || allowed_stages.find_by(slug: 'qualificacao')
    if stage
      Crm::DealMover.new(deal: @deal, stage_id: stage.id, actor: nil).perform
    else
      @deal.update!(custom_fields: (@deal.custom_fields || {}).merge('qualified' => true))
    end
    audit('ai_marked_qualified', stage: stage&.slug, reason: reason)
    Result.new(ok: true, data: { qualified: true, stage: stage&.slug })
  end

  private

  def packs
    @packs ||= Crm::PackOptions.installed_packs(@account)
  end

  # Flag desligada (produção atual) => categorias são as áreas legadas;
  # ligada => só os valores dos packs instalados.
  def allowed_category_values
    @allowed_category_values ||= if @account.feature_enabled?('crm_universal')
                                   packs.flat_map(&:categories).map { |c| c[:value].to_s }.uniq
                                 else
                                   Crm::DomainOptions::LEGAL_AREAS.map { |o| o[:value].to_s }
                                 end
  end

  # Ganho/perdido é decisão humana: a IA move entre etapas de trabalho, mas
  # nunca para uma etapa terminal (2.6) — isso passaria por `mark_won!`/
  # `mark_lost!` sem motivo de perda nem revisão.
  def allowed_stages
    @deal.crm_pipeline.crm_pipeline_stages.active.where(terminal_outcome: nil)
  end

  def allowed_stage_slugs
    allowed_stages.pluck(:slug)
  end

  def allowed_field_keys
    @allowed_field_keys ||= @account.crm_field_definitions.active.for_deals.pluck(:key).map(&:to_s)
  end

  def allowed_activity_keys
    @allowed_activity_keys ||= (@account.crm_activity_types.active.pluck(:key) + CrmActivity::KINDS).map(&:to_s).uniq
  end

  def appointment_kind
    %w[reuniao confirmacao_agendamento tarefa].find { |k| allowed_activity_keys.include?(k) } || CrmActivity::KINDS.first
  end

  def audit(action, payload = {})
    Crm::AuditLogger.log(account: @account, actor: @actor, action: action, target: @deal, payload: payload)
  end

  def fail_result(message)
    audit('ai_tool_denied', error: message)
    Result.new(ok: false, error: message)
  end
end
