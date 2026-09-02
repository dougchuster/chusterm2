# UX-04: Central de IA — visão consolidada do estado da IA da conta:
# contagens por modo, conversas pausadas (com motivo estruturado, quem/quando)
# e saúde de mídia/transcrição. A retomada usa o endpoint existente de
# conversation_states (auditada via resume_source/resumed_by).
class Api::V1::Accounts::Captain::AiCenterController < Api::V1::Accounts::BaseController
  PAUSED_STATES_LIMIT = 100

  def index
    render json: {
      summary: summary_counts,
      metrics: ai_metrics,
      media: media_summary,
      paused_conversations: paused_conversations
    }
  end

  private

  # Fase 4: deflection (% resolvidas sem humano — benchmark BR 62-78%) e
  # tempo médio até o handoff, calculados sobre o estado por conversa
  def ai_metrics
    resolved_states = states_scope.joins(:conversation)
                                  .where(conversations: { status: Conversation.statuses[:resolved] })
    resolved_total = resolved_states.count
    resolved_by_ai = resolved_states.where(ai_mode: 'auto').count

    avg_seconds_to_handoff = states_scope.where.not(handoff_at: nil)
                                         .joins(:conversation)
                                         .average(
                                           Arel.sql('EXTRACT(EPOCH FROM captain_conversation_states.handoff_at - conversations.created_at)')
                                         )

    {
      resolved_total: resolved_total,
      resolved_by_ai: resolved_by_ai,
      deflection_rate: resolved_total.positive? ? (resolved_by_ai * 100.0 / resolved_total).round(1) : nil,
      avg_seconds_to_handoff: avg_seconds_to_handoff&.to_f&.round
    }
  end

  def states_scope
    Current.account.captain_conversation_states
  end

  def summary_counts
    counts = states_scope.group(:ai_mode).count
    {
      total: counts.values.sum,
      auto: counts.fetch('auto', 0),
      supervised: counts.fetch('supervised', 0),
      paused: counts.fetch('paused', 0),
      human_only: counts.fetch('human_only', 0),
      by_reason_code: states_scope.where(ai_mode: CaptainConversationState::HUMAN_MODES)
                                  .where.not(handoff_reason_code: nil)
                                  .group(:handoff_reason_code).count
    }
  end

  def media_summary
    Crm::HealthCheckService.new(account: Current.account).perform[:media]
  end

  def paused_conversations
    states = states_scope.where(ai_mode: CaptainConversationState::HUMAN_MODES)
                         .includes(:handoff_by, conversation: :contact)
                         .order(handoff_at: :desc, updated_at: :desc)
                         .limit(PAUSED_STATES_LIMIT)

    states.map do |state|
      {
        id: state.id,
        conversation_id: state.conversation_id,
        conversation_display_id: state.conversation&.display_id,
        contact_name: state.conversation&.contact&.name,
        ai_mode: state.ai_mode,
        handoff_reason: state.handoff_reason,
        handoff_reason_code: state.handoff_reason_code,
        handoff_at: state.handoff_at,
        handoff_by_name: state.handoff_by&.name,
        updated_at: state.updated_at
      }
    end
  end
end
