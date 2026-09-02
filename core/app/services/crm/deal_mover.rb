# Mover um negocio significa duas coisas desde a F1.3 do
# PLANO-KANBAN-CRM-2026.md:
#
# - **trocar de etapa** — audita, valida campos obrigatorios e dispara a
#   automacao da etapa de destino, como sempre fez;
# - **reordenar dentro da coluna** — so grava `position`.
#
# A distincao nao e cosmetica. Arrastar um card tres posicoes para cima nao e
# "entrar na etapa": tratar como entrada faria a automacao mandar mensagem para
# o cliente, criar atividade e trocar o dono a cada arrasto.
#
# A posicao e sempre calculada no servidor (`Crm::DealPositioner`) a partir dos
# vizinhos que o cliente reporta. O cliente nunca manda um numero.
class Crm::DealMover
  def initialize(deal:, stage_id:, actor: nil, before_id: nil, after_id: nil)
    @deal = deal
    @stage_id = stage_id
    @actor = actor
    @before_id = before_id
    @after_id = after_id
  end

  def perform
    from_stage_id = @deal.crm_pipeline_stage_id
    # Memoiza antes de qualquer escrita: `apply_move!` grava a etapa nova, e
    # depois dela a pergunta "mudou de etapa?" responderia sempre nao.
    changed = stage_changed?

    validate_required_fields! if changed
    apply_move!

    return @deal unless changed

    log_stage_change(from_stage_id)
    Crm::StageAutomation.new(deal: @deal.reload, actor: @actor).perform
    @deal
  end

  private

  # Calcular a posicao e grava-la precisam ser a mesma operacao, sob lock da
  # coluna de destino. Dois atendentes arrastando para a mesma etapa ao mesmo
  # tempo leem os mesmos vizinhos, calculam o mesmo ponto medio e gravam o mesmo
  # numero — e `position` nao tem indice unico, entao a colisao seria silenciosa.
  #
  # A automacao e o audit ficam **fora** desta transacao de proposito: a
  # automacao manda mensagem no WhatsApp e chama servico externo, e segurar o
  # lock da coluna durante isso travaria o board inteiro.
  def apply_move!
    ActiveRecord::Base.transaction do
      Crm::StageAdvisoryLock.lock!(target_stage.id)
      @deal.update!(move_attributes)
    end
  end

  # Reordenacao nao vai para o audit de proposito: o board e arrastado o dia
  # inteiro e uma linha por arrasto afogaria `crm_audit_events` sem responder a
  # nenhuma pergunta que alguem faca.
  def log_stage_change(from_stage_id)
    Crm::AuditLogger.log(
      account: @deal.account,
      actor: @actor,
      action: 'deal_stage_changed',
      target: @deal,
      payload: { from_stage_id: from_stage_id, to_stage_id: target_stage.id }
    )
  end

  # `stage_entered_at` so e tocado quando a etapa muda de verdade. Reordenar
  # dentro da coluna nao reinicia o relogio do rotting (F2.5) nem falseia o
  # tempo medio da coluna (F1.5) — um card arrastado para cima continua
  # parado ha tres dias.
  def move_attributes
    attributes = { crm_pipeline_stage_id: target_stage.id, position: next_position }
    attributes[:stage_entered_at] = Time.current if stage_changed?
    attributes
  end

  # Uma unica verdade: e a mesma pergunta que decide disparar automacao,
  # auditar e reiniciar o relogio da etapa. Memoizada porque `perform` ja
  # gravou a etapa nova antes do audit rodar.
  def stage_changed?
    return @stage_changed if defined?(@stage_changed)

    @stage_changed = @deal.crm_pipeline_stage_id != target_stage.id
  end

  def next_position
    Crm::DealPositioner.new(
      stage: target_stage,
      before_id: @before_id,
      after_id: @after_id,
      excluding_id: @deal.id
    ).call
  end

  def validate_required_fields!
    missing_fields = required_field_keys.select { |field| missing_required_field?(field) }
    return if missing_fields.blank?

    raise ArgumentError, "Campos obrigatorios ausentes para a etapa #{target_stage.name}: #{missing_fields.join(', ')}"
  end

  def required_field_keys
    fields = target_stage.required_fields
    case fields
    when Array
      fields
    when Hash
      configured = fields['fields'] || fields[:fields] || fields['required_fields'] || fields[:required_fields]
      return Array(configured).map(&:to_s) if configured.present?

      fields.select { |_key, value| ActiveModel::Type::Boolean.new.cast(value) }.keys
    else
      []
    end.map(&:to_s).compact_blank
  end

  def missing_required_field?(field)
    if @deal.respond_to?(field)
      @deal.public_send(field).blank?
    else
      @deal.custom_fields.to_h[field].blank?
    end
  end

  def target_stage
    @target_stage ||= begin
      stage = @deal.account.crm_pipeline_stages.find(@stage_id)
      unless stage.crm_pipeline_id == @deal.crm_pipeline_id
        raise ArgumentError, 'A etapa nao pertence ao pipeline do negocio'
      end

      stage
    end
  end
end
