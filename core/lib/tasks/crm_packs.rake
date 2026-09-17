# frozen_string_literal: true

namespace :crm do
  namespace :packs do
    desc 'Lista os packs disponíveis (config/crm_packs/*.yml)'
    task list: :environment do
      Crm::Pack.all.each { |pack| puts "#{pack.slug} v#{pack.version} — #{pack.name}" }
    end

    desc 'Instala um pack numa conta: rails crm:packs:install[legal,1] (sem account_id => todas)'
    task :install, [:slug, :account_id] => :environment do |_t, args|
      slug = args[:slug].presence || 'legal'
      scope = args[:account_id].present? ? Account.where(id: args[:account_id]) : Account.all

      scope.find_each do |account|
        Crm::PackInstaller.new(account).install(slug)
        puts "conta #{account.id}: pack #{slug} instalado"
      end
    end

    desc 'Backfill de category/subcategory a partir de legal_area/case_type (idempotente)'
    task backfill_categories: :environment do
      # rubocop:disable Rails/SkipsModelValidations -- backfill em lote; o
      # dual-write do modelo já garante consistência nas escritas novas.
      updated = CrmDeal.where(category: nil).where.not(legal_area: nil)
                       .update_all('category = legal_area, subcategory = case_type')
      # rubocop:enable Rails/SkipsModelValidations
      puts "deals atualizados: #{updated}"
    end
  end
end
