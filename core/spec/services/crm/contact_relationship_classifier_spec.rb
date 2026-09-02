require 'rails_helper'

RSpec.describe Crm::ContactRelationshipClassifier do
  let(:account) { create(:account) }

  it 'classifies a default contact as a lead without triggering handoff' do
    contact = create(:contact, account: account, contact_type: :lead, relationship_status: 'lead')

    result = described_class.new(contact).perform

    expect(result).to include(status: 'lead', automatic_handoff: false)
    expect(result[:confidence]).to be_between(0.5, 1.0)
    expect(result[:evidence]).to be_present
  end

  it 'uses confirmed customer evidence without triggering handoff' do
    contact = create(:contact, account: account, contact_type: :customer, relationship_status: 'customer')

    result = described_class.new(contact).perform

    expect(result).to include(status: 'customer', automatic_handoff: false)
    expect(result[:confidence]).to be >= 0.9
    expect(result[:evidence].pluck(:code)).to include('relationship_status')
  end
end
