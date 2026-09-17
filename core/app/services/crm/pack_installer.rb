# frozen_string_literal: true

# Instala (ou atualiza) um pack numa conta. Idempotente — pode rodar de novo
# sem duplicar definições. Nunca remove dados: reinstalar só sincroniza
# labels/opções dos itens criados pelo próprio pack.
class Crm::PackInstaller
  def initialize(account)
    @account = account
  end

  def install(slug)
    pack = Crm::Pack.find!(slug)

    ActiveRecord::Base.transaction do
      sync_activity_types(pack)
      sync_field_definitions(pack)
      account.crm_account_packs.find_or_create_by!(slug: pack.slug) do |row|
        row.version = pack.version
        row.installed_at = Time.current
      end.update!(version: pack.version)
    end

    pack
  end

  def install_default
    install(Crm::Pack::DEFAULT_SLUG)
  end

  private

  attr_reader :account

  def sync_activity_types(pack)
    pack.activity_types.each do |attrs|
      record = account.crm_activity_types.find_or_initialize_by(key: attrs[:key].to_s)
      record.assign_attributes(
        pack_slug: pack.slug,
        label: attrs[:label].to_s,
        icon: attrs[:icon],
        position: attrs[:position] || 0,
        active: true
      )
      record.save!
    end
  end

  def sync_field_definitions(pack)
    pack.field_definitions.each do |attrs|
      record = account.crm_field_definitions.find_or_initialize_by(key: attrs[:key].to_s)
      record.assign_attributes(
        pack_slug: pack.slug,
        label: attrs[:label].to_s,
        field_type: attrs[:field_type].presence || 'text',
        options: Array(attrs[:options]),
        applies_to: attrs[:applies_to].presence || 'deal',
        required: attrs[:required] || false,
        position: attrs[:position] || 0,
        active: true
      )
      record.save!
    end
  end
end
