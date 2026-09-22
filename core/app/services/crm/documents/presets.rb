# Leitura dos modelos de documentos por área (config/crm_documents/presets).
# Cada arquivo traz nome, descrição, padrões de nome, catálogo de tipos,
# apelidos de checklist e estrutura de pastas. Cache por processo.
module Crm::Documents::Presets
  DIR = Rails.root.join('config/crm_documents/presets')
  DEFAULT = 'geral'.freeze
  MUTEX = Mutex.new

  module_function

  def slugs
    Dir[DIR.join('*.yml')].map { |path| File.basename(path, '.yml') }.sort
  end

  def list
    slugs.map do |slug|
      config = fetch(slug)
      { slug: slug, name: config['name'], description: config['description'] }
    end
  end

  def fetch(slug)
    slug = DEFAULT unless slugs.include?(slug.to_s)
    MUTEX.synchronize do
      @cache ||= {}
      @cache[slug.to_s] ||= YAML.safe_load_file(DIR.join("#{slug}.yml")).freeze
    end
  end
end
