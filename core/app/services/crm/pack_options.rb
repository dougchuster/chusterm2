# frozen_string_literal: true

# Fase 2 (A0): resolve a taxonomia da conta a partir dos packs instalados.
#
# - `crm_universal` ligado  => categorias/subcategorias/tipos/campos vêm dos
#   packs (conta nova => sales_default; jurídica => legal).
# - Flag desligada          => payload legado de Crm::DomainOptions, produção
#   continua idêntica.
#
# `legal_areas` permanece como chave no payload: o frontend consome o mesmo
# contrato, agora alimentado pelo pack — conta sem pack legal nunca recebe
# terminologia jurídica.
module Crm::PackOptions
  module_function

  def for_account(account)
    return Crm::DomainOptions.payload unless account&.feature_enabled?('crm_universal')

    universal_payload(account)
  end

  # Label da categoria consultando os packs antes do mapa estático legado.
  def category_label_for(account, value)
    canonical = Crm::DomainOptions.canonical_legal_area(value)
    return if canonical.blank?

    if account&.feature_enabled?('crm_universal')
      option = installed_packs(account)
               .flat_map(&:categories)
               .find { |o| o[:value] == canonical }
      return option[:label] if option
    end

    Crm::DomainOptions.legal_area_label(canonical)
  end

  # Label da subcategoria dentro das categorias do pack (nil quando o pack
  # não define a subcategoria — o front mantém o valor cru como fallback).
  def subcategory_label_for(account, category, value)
    return if value.blank? || !account&.feature_enabled?('crm_universal')

    installed_packs(account).each do |pack|
      option = pack.subcategories_for(Crm::DomainOptions.canonical_legal_area(category))
                   .find { |o| o[:value] == value }
      return option[:label] if option
    end
    nil
  end

  def installed_packs(account)
    slugs = account.crm_account_packs.installed.pluck(:slug)
    slugs = [Crm::Pack::DEFAULT_SLUG] if slugs.empty?

    slugs.filter_map do |slug|
      Crm::Pack.find!(slug)
    rescue Crm::Pack::UnknownPackError
      nil
    end
  end

  def universal_payload(account)
    packs = installed_packs(account)
    categories = packs.flat_map(&:categories).uniq { |o| o[:value] }

    {
      legal_areas: categories.presence || Crm::DomainOptions::LEGAL_AREAS,
      categories: categories,
      subcategories: merged_subcategories(packs),
      activity_types: activity_type_options(account),
      field_definitions: field_definition_options(account),
      analyst_prompts: packs.flat_map(&:analyst_prompts).uniq,
      packs: packs.map(&:slug),
      lead_sources: Crm::DomainOptions::LEAD_SOURCES,
      urgency_levels: Crm::DomainOptions::URGENCY_LEVELS,
      disposition_reasons: Crm::DomainOptions::DISPOSITION_REASONS
    }
  end

  def merged_subcategories(packs)
    packs.each_with_object({}.with_indifferent_access) do |pack, merged|
      pack.subcategories.each { |key, list| merged[key] = list }
    end
  end

  def activity_type_options(account)
    account.crm_activity_types.active.map do |type|
      { value: type.key, label: type.label, icon: type.icon }
    end
  end

  def field_definition_options(account)
    account.crm_field_definitions.active.for_deals.map do |field|
      { key: field.key, label: field.label, field_type: field.field_type,
        options: field.options, required: field.required }
    end
  end
end
