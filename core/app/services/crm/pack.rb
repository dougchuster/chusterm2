# frozen_string_literal: true

# Carrega a definição declarativa de um pack (config/crm_packs/<slug>.yml).
# O pack é a fonte da taxonomia visível da conta: categorias, subcategorias,
# tipos de atividade, campos customizados, prompts do analista e template de
# pipeline. Conta sem pack legal nunca recebe terminologia jurídica.
class Crm::Pack
  class UnknownPackError < StandardError; end

  PACKS_DIR = Rails.root.join('config/crm_packs').freeze
  DEFAULT_SLUG = 'sales_default'
  # O slug vira nome de arquivo: sem esta guarda, `packs#create` com
  # `../../config/database` leria qualquer YAML do repositório.
  SLUG_FORMAT = /\A[a-z0-9_]+\z/

  # Cache de definições já parseadas, por slug. O board serializa
  # `category_label_for` três vezes por card (150 cards = 450 leituras de
  # YAML por requisição sem isto). Invalida sozinho quando o arquivo muda.
  DEFINITIONS_MUTEX = Mutex.new

  attr_reader :slug, :definition

  def initialize(slug)
    @slug = slug.to_s
    raise UnknownPackError, "CRM pack slug inválido: #{@slug.inspect}" unless SLUG_FORMAT.match?(@slug)

    @definition = self.class.definition_for(@slug)
  end

  def self.definition_for(slug)
    path = PACKS_DIR.join("#{slug}.yml")
    raise UnknownPackError, "CRM pack '#{slug}' não existe em #{PACKS_DIR}" unless path.exist?

    mtime = path.mtime
    DEFINITIONS_MUTEX.synchronize do
      cached = definitions_cache[slug]
      return cached[:definition] if cached && cached[:mtime] == mtime

      definition = parse_definition!(slug, path)
      definitions_cache[slug] = { mtime: mtime, definition: definition }
      definition
    end
  end

  def self.definitions_cache
    @definitions_cache ||= {}
  end

  def self.parse_definition!(slug, path)
    (YAML.safe_load(path.read, permitted_classes: [Symbol], aliases: false) || {}).freeze
  rescue Psych::SyntaxError => e
    raise UnknownPackError, "CRM pack '#{slug}' inválido: #{e.message}"
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

  # Pesos/thresholds/mapa de etapas do score declarados pelo pack.
  def scoring
    (definition['scoring'] || {}).with_indifferent_access
  end

  def pipeline_template
    (definition['pipeline_template'] || {}).with_indifferent_access
  end

  # 3.3: perguntas de intake por categoria — o classificador cobre estes
  # pontos e a IA dispara `request_info` para o que ficou em aberto.
  def intake_questions
    (definition['intake_questions'] || {}).with_indifferent_access
  end

  # 3.5: perfis do orchestrator = packs — identidade e prompt base da IA
  # vêm do pack instalado em vez de um serviço paralelo.
  def ai
    (definition['ai'] || {}).with_indifferent_access
  end
end
