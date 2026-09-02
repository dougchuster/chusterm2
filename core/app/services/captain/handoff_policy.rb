# frozen_string_literal: true

class Captain::HandoffPolicy
  HANDOFF_TRIGGERS = {
    'customer_request' => 'Cliente solicitou atendimento humano.',
    'human_message' => 'Atendimento humano detectado; IA pausada automaticamente.',
    'manual_takeover' => 'Atendimento assumido manualmente.',
    'assistant_request' => 'A IA identificou necessidade de revisão humana.',
    'safety_risk' => 'Risco ou urgência exige revisão humana.',
    'provider_failure' => 'A IA ficou indisponível e o atendimento foi direcionado para revisão humana.'
  }.freeze

  NON_HANDOFF_TRIGGERS = %w[score customer_relationship lifecycle_stage].freeze

  def self.evaluate(trigger:, reason: nil)
    trigger = trigger.to_s
    handoff = HANDOFF_TRIGGERS.key?(trigger)

    {
      handoff: handoff,
      reason_code: handoff ? trigger : nil,
      reason: reason.presence || HANDOFF_TRIGGERS[trigger],
      ignored_signal: NON_HANDOFF_TRIGGERS.include?(trigger)
    }
  end
end
