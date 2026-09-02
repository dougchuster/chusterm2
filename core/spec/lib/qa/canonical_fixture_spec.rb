require 'rails_helper'
require Rails.root.join('lib/qa/canonical_fixture')

RSpec.describe Qa::CanonicalFixture do
  subject(:seed_fixture) do
    described_class.new(
      password: 'Fixture-password-2026!',
      namespace: namespace,
      deal_count: 7
    ).call
  end

  let(:namespace) { "spec-#{SecureRandom.hex(4)}" }

  it 'cria contas isoladas, personas e os cenarios minimos de CRM' do
    manifest = seed_fixture
    account_a = Account.find(manifest.dig(:account_ids, :a))
    account_b = Account.find(manifest.dig(:account_ids, :b))

    expect(account_a).not_to eq(account_b)
    expect(manifest[:deal_counts]).to eq(account_a: 7, account_b: 2)
    expect(manifest[:credentials].keys).to include(
      :admin, :operator, :seller, :manager, :knowledge_manager, :admin_b, :no_account, :super_admin
    )
    expect(account_a.crm_deals.pluck(:status)).to include('open', 'won', 'lost', 'archived')
    expect(account_a.contacts.find_by!(identifier: "qa-#{namespace}-contact-0001")).not_to eq(
      account_b.contacts.find_by!(identifier: "qa-#{namespace}-contact-0001")
    )
    expect(account_a.inboxes.first.captain_inbox).to be_present
    expect(account_b.inboxes.first.captain_inbox).to be_nil
  end

  it 'e idempotente para o mesmo namespace' do
    first_manifest = seed_fixture
    second_manifest = seed_fixture

    expect(second_manifest).to eq(first_manifest)
    expect(Account.where(domain: "qa-#{namespace}-a.invalid").count).to eq(1)
    expect(CrmDeal.where(account_id: first_manifest.dig(:account_ids, :a), source: 'qa_fixture').count).to eq(7)
  end

  # F0.3 do PLANO-KANBAN-CRM-2026.md mede o board com 2.000 negocios e a meta de
  # escala do plano e 5.000 num unico pipeline. O teto precisa cobrir os dois.
  #
  # Os dois exemplos abaixo cobrem so a validacao de limite no construtor — nao
  # executam `#call`. Semear 5.000 registros de verdade e caro (upsert por
  # registro numa transacao unica) e nao cabe na suite padrao.
  it 'aceita o volume maximo de baseline do Kanban (limite do construtor)' do
    expect do
      described_class.new(password: 'Fixture-password-2026!', namespace: namespace, deal_count: 5_000)
    end.not_to raise_error
  end

  it 'rejeita volume acima do teto de baseline (limite do construtor)' do
    expect do
      described_class.new(password: 'Fixture-password-2026!', namespace: namespace, deal_count: 5_001)
    end.to raise_error(ArgumentError, /entre 7 e 5000/)
  end

  it 'rejeita senhas fracas' do
    expect do
      described_class.new(password: 'curta', namespace: namespace, deal_count: 7)
    end.to raise_error(ArgumentError, /12 caracteres/)
  end

  it 'rejeita um runtime production sem o alvo local-compose' do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new('production'))

    expect do
      described_class.new(password: 'Fixture-password-2026!', namespace: namespace, deal_count: 7)
    end.to raise_error(described_class::UnsafeEnvironmentError, /alvo local-compose/)
  end
end
