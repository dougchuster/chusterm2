require 'rails_helper'

RSpec.describe Campaigns::AudienceResolver do
  let(:account) { create(:account) }
  let(:label) { create(:label, account: account, title: 'lista-maio') }
  let(:audience) { [{ type: 'Label', id: label.id }] }

  before do
    matching_contact.update_labels([label.title])
    missing_email_contact.update_labels([label.title])
    opted_out_contact.update_labels([label.title])
    blocked_contact.update_labels([label.title])
    outside_contact.update_labels(['fora-da-lista'])
    opted_out_contact.campaign_opt_out!(source: 'spec')
  end

  let!(:matching_contact) { create(:contact, :with_email, :with_phone_number, account: account) }
  let!(:missing_email_contact) { create(:contact, :with_phone_number, account: account, email: nil) }
  let!(:opted_out_contact) { create(:contact, :with_email, :with_phone_number, account: account) }
  let!(:blocked_contact) { create(:contact, :with_email, :with_phone_number, account: account, blocked: true) }
  let!(:outside_contact) { create(:contact, :with_email, :with_phone_number, account: account) }

  describe '#summary' do
    it 'excludes opted-out and blocked contacts from the eligible audience' do
      summary = described_class.new(account, audience).summary

      expect(summary).to include(
        total: 2,
        with_email: 1,
        without_email: 1,
        opted_out: 1,
        blocked: 1,
        labels: [label.title]
      )
    end
  end

  describe '#preview' do
    it 'returns only eligible contacts with CRM campaign flags' do
      preview = described_class.new(account, audience).preview
      contact_ids = preview[:contacts].pluck(:id)

      expect(contact_ids).to contain_exactly(matching_contact.id, missing_email_contact.id)
      expect(preview[:contacts]).to all(include(:campaign_opt_out, :blocked, :labels))
    end
  end
end
