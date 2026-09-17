# frozen_string_literal: true

# Carrega a definição declarativa de um pack (config/crm_packs/<slug>.yml).
# O pack é a fonte da taxonomia visível da conta: categorias, subcategorias,
# tipos de atividade, campos customizados, prompts do analista e template de
# pipeline. Conta sem pack legal nunca recebe terminologia jurídica.
class Crm::Pack
  class UnknownPackError < StandardError; end

  PACKS_DIR = Rails.root.join('config/crm_packs').freeze
  DEFAULT_SLUG = 'sales_default'

  attr_reader :slug, :definition

  def initialize(slug)
    @slug = slug.to_s
    @definition = load_definition!
  end

  def self.all
    PACKS_DIR.glob('*.yml').map { |path| new(File.basename(path, '.yml')) }
  end

  def self.slugs
    PACKS_DIR.glob('*.yml').map { |path| File.basename(path, '.yml') }
  end

  def self.default
    new(DEFAULT_SLUG)
  end

  def self.find!(slug)
    new(slug)
  end

  def version
    definition['version'].to_s
  end

  def name
    definition['name'].to_s
  end

  def categories
    Array(definition['categories']).map(&:with_indifferent_access)
  end

  def subcategories
    (definition['subcategories'] || {}).with_indifferent_access
  end

  def subcategories_for(category)
    Array(subcategories[category]).map(&:with_indifferent_access)
  end

  def activity_types
    Array(definition['activity_types']).map(&:with_indifferent_access)
  end

  def activity_type_keys
    activity_types.map { |type| type[:key].to_s }
  end

  def field_definitions
    Array(definition['field_definitions']).map(&:with_indifferent_access)
  end

  def analyst_prompts
    Array(definition['analyst_prompts'])
  end

  def pipeline_template
    (definition['pipeline_template'] || {}).with_indifferent_access
  end

  private

  def load_definition!
    path = PACKS_DIR.join("#{slug}.yml")
    raise UnknownPackError, "CRM pack '#{slug}' não existe em #{PACKS_DIR}" unless path.exist?

    YAML.safe_load(path.read, permitted_classes: [Symbol], aliases: false) || {}
  rescue Psych::SyntaxError => e
    raise UnknownPackError, "CRM pack '#{slug}' inválido: #{e.message}"
  end
end
