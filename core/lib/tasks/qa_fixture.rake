# frozen_string_literal: true

namespace :qa do
  desc 'Cria/atualiza a fixture canonica isolada da Fase 0'
  task seed: :environment do
    require Rails.root.join('lib/qa/canonical_fixture')

    manifest = Qa::CanonicalFixture.new(
      password: ENV.fetch('QA_FIXTURE_PASSWORD'),
      namespace: ENV.fetch('QA_FIXTURE_NAMESPACE', 'f0'),
      deal_count: ENV.fetch('QA_FIXTURE_DEAL_COUNT', Qa::CanonicalFixture::DEFAULT_DEAL_COUNT),
      now: ENV.fetch('QA_FIXTURE_NOW', nil)
    ).call

    puts JSON.pretty_generate(manifest)
  end
end
