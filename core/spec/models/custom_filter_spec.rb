require 'rails_helper'

RSpec.describe CustomFilter do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  # Check-up 2026-09-18: a coluna é NOT NULL mas '' era aceito.
  it 'requires a name' do
    filter = described_class.new(account: account, user: user, name: '', filter_type: :conversation, query: { payload: [] })

    expect(filter).not_to be_valid
    expect(filter.errors[:name]).to be_present
  end

  it 'is valid with a name' do
    filter = described_class.new(account: account, user: user, name: 'Meus abertos', filter_type: :conversation, query: { payload: [] })

    expect(filter).to be_valid
  end
end
