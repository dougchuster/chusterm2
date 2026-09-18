# frozen_string_literal: true

# 2.8 do PLANO_17_09.md — fixture QA por pack. Uso:
#
#   bundle exec rails "crm:qa:seed_pack[clinic]"
#   bundle exec rails "crm:qa:seed_pack[legal]"
#
# Cria uma conta "QA Pack <slug>" com admin qa+<slug>@chusterm.invalid
# (senha Password1!), instala o pack, provisiona o funil do pipeline_template
# e semeia um negócio por categoria — suficiente para o E2E visual de
# "conta de clínica não vê nada jurídico".
namespace :crm do
  namespace :qa do
    desc 'Semeia uma conta QA com o pack informado: crm:qa:seed_pack[clinic]'
    task :seed_pack, [:slug] => :environment do |_task, args|
      slug = args[:slug].presence || 'sales_default'
      pack = Crm::Pack.find!(slug)

      account = Account.find_or_create_by!(name: "QA Pack #{slug}") do |row|
        row.locale = 'pt_BR'
      end
      account.enable_features!('crm_universal')

      user = User.find_or_initialize_by(email: "qa+#{slug}@chusterm.invalid")
      user.assign_attributes(name: "QA #{slug}", password: 'Password1!', password_confirmation: 'Password1!')
      user.save!
      AccountUser.find_or_create_by!(account: account, user: user) { |row| row.role = :administrator }

      Crm::PackInstaller.new(account).install(slug)
      pipeline = seed_pipeline(account, pack)
      seed_deals(account, pipeline, pack, user)

      puts "QA pack '#{slug}' pronto — conta ##{account.id}, login qa+#{slug}@chusterm.invalid / Password1!"
    end

    def seed_pipeline(account, pack)
      template = pack.pipeline_template
      pipeline = account.crm_pipelines.find_or_create_by!(slug: "qa-#{pack.slug}") do |row|
        row.name = "Funil #{pack.name}"
        row.kind = template[:kind].presence || 'sales'
      end
      Array(template[:stages]).each do |attrs|
        stage = pipeline.crm_pipeline_stages.find_or_initialize_by(slug: attrs[:slug].to_s)
        stage.assign_attributes(stage_attributes(account, attrs))
        stage.save!
      end
      pipeline
    end

    def stage_attributes(account, attrs)
      attrs.slice(:name, :position, :probability_pct, :expected_duration_hours, :color)
           .merge(account: account, terminal_outcome: attrs[:terminal_outcome]&.to_s)
    end

    def seed_deals(account, pipeline, pack, owner)
      first_stage = pipeline.crm_pipeline_stages.active.where(terminal_outcome: nil).order(:position).first
      pack.categories.first(4).each do |category|
        contact = Contact.find_or_create_by!(account: account, name: "QA #{category[:label]}") do |row|
          row.phone_number = "+5511999#{rand(100_000..999_999)}"
        end
        deal = account.crm_deals.find_or_initialize_by(contact: contact, crm_pipeline: pipeline)
        next unless deal.new_record?

        deal.assign_attributes(
          title: "#{contact.name} — #{category[:label]}",
          crm_pipeline_stage: first_stage,
          category: category[:value],
          owner_id: owner.id
        )
        deal.save!
      end
    end
  end
end
