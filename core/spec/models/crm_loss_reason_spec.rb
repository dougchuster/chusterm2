require 'rails_helper'

# Check-up 2026-09-18: a tela de motivos de perda envia só `name`; o slug tem
# de nascer no model, como em CrmPipeline.
RSpec.describe CrmLossReason do
  let(:account) { create(:account) }

  it 'gera o slug a partir do nome' do
    reason = account.crm_loss_reasons.create!(name: 'Preço alto')

    expect(reason.slug).to eq('preco-alto')
  end

  it 'desambigua slugs repetidos na mesma conta' do
    account.crm_loss_reasons.create!(name: 'Preço')
    second = account.crm_loss_reasons.create!(name: 'Preço')

    expect(second.slug).to eq('preco-2')
  end

  it 'mantém um slug informado explicitamente' do
    reason = account.crm_loss_reasons.create!(name: 'Preço', slug: 'custom')

    expect(reason.slug).to eq('custom')
  end

  it 'continua exigindo nome' do
    expect(account.crm_loss_reasons.build(name: '')).not_to be_valid
  end
end
