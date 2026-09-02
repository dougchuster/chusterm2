require 'rails_helper'

RSpec.describe Captain::HandoffPolicy do
  it 'never hands off from score or relationship signals' do
    expect(described_class.evaluate(trigger: 'score')).to include(handoff: false, ignored_signal: true)
    expect(described_class.evaluate(trigger: 'customer_relationship')).to include(handoff: false, ignored_signal: true)
  end

  it 'hands off for an explicit customer request with a structured reason' do
    expect(described_class.evaluate(trigger: 'customer_request')).to include(
      handoff: true,
      reason_code: 'customer_request',
      reason: 'Cliente solicitou atendimento humano.'
    )
  end
end
