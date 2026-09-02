require 'rails_helper'

RSpec.describe Redis::Alfred do
  describe '.delete_if_value' do
    let(:key) { "alfred-delete-if-value-#{SecureRandom.uuid}" }

    after { described_class.delete(key) }

    it 'deletes the key when the caller owns the value' do
      described_class.set(key, 'owner-a')

      expect(described_class.delete_if_value(key, 'owner-a')).to eq(1)
      expect(described_class.get(key)).to be_nil
    end

    it 'preserves a lock owned by another caller' do
      described_class.set(key, 'owner-b')

      expect(described_class.delete_if_value(key, 'owner-a')).to eq(0)
      expect(described_class.get(key)).to eq('owner-b')
    end
  end
end
