require 'rails_helper'

RSpec.describe Crm::ScheduleSuggestionService do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account) }
  let(:contact) { create(:contact, :with_email, account: account, name: 'Maria Silva') }
  let(:start_time) { Time.zone.local(2026, 5, 6, 9, 0) }

  describe '#perform' do
    it 'returns business-hour suggestions and skips occupied windows' do
      CrmActivity.create!(
        account: account,
        owner: owner,
        assignee: owner,
        contact: contact,
        kind: 'reuniao',
        title: 'Consulta ocupada',
        priority: 'normal',
        due_at: start_time + 1.hour
      )

      result = described_class.new(
        account: account,
        owner: owner,
        params: {
          from: start_time.iso8601,
          to: (start_time + 1.day).iso8601,
          contact_id: contact.id,
          kind: 'reuniao',
          priority: 'alta',
          duration_minutes: 60
        }
      ).perform

      starts = result[:suggestions].pluck(:starts_at)

      expect(result[:draft]).to include(
        title: 'Consulta juridica - Maria Silva',
        kind: 'reuniao',
        priority: 'alta',
        contact_id: contact.id,
        assignee_id: owner.id
      )
      expect(result[:suggestions]).not_to be_empty
      expect(result[:suggestions].size).to be <= described_class::MAX_SUGGESTIONS
      expect(starts).not_to include(start_time + 1.hour)
      expect(result[:suggestions]).to all(
        satisfy do |slot|
          slot[:starts_at].hour >= described_class::WORK_START_HOUR &&
            slot[:ends_at].hour <= described_class::WORK_END_HOUR &&
            !slot[:starts_at].saturday? &&
            !slot[:starts_at].sunday?
        end
      )
    end
  end
end
