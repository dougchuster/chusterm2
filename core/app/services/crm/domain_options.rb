# frozen_string_literal: true

# UX-05: listas de domínio do CRM — fonte única (antes duplicadas/hardcoded no
# front em 6 arquivos). Servidas por GET /crm/options; labels em pt-BR sem
# emojis (UX-08 — urgência é indicada por cor/badge no front, não por emoji).
module Crm
  module DomainOptions
    LEGAL_AREAS = [
      { value: 'comercial', label: 'Comercial / Vendas' },
      { value: 'servicos', label: 'Prestação de Serviços' },
      { value: 'consultoria', label: 'Consultoria' },
      { value: 'tecnologia', label: 'Tecnologia / SaaS' },
      { value: 'saude', label: 'Saúde / Clínicas' },
      { value: 'imobiliario', label: 'Imobiliário' },
      { value: 'financeiro', label: 'Financeiro / Contábil' },
      { value: 'educacao', label: 'Educação / Treinamento' },
      { value: 'varejo', label: 'Varejo / E-commerce' },
      { value: 'juridico', label: 'Jurídico' },
      { value: 'previdenciario', label: 'Previdenciário' },
      { value: 'civel', label: 'Cível' },
      { value: 'trabalhista', label: 'Trabalhista' },
      { value: 'outro', label: 'Outro' }
    ].freeze

    LEAD_SOURCES = [
      { value: 'whatsapp', label: 'WhatsApp' },
      { value: 'instagram', label: 'Instagram' },
      { value: 'facebook', label: 'Facebook' },
      { value: 'google_ads', label: 'Google Ads' },
      { value: 'meta_ads', label: 'Meta Ads' },
      { value: 'site', label: 'Site / Landing Page' },
      { value: 'indicacao', label: 'Indicação' },
      { value: 'prospeccao_ativa', label: 'Prospecção Ativa' },
      { value: 'evento', label: 'Evento / Feira' },
      { value: 'lista_importada', label: 'Lista importada' },
      { value: 'cliente_base', label: 'Cliente Base' },
      { value: 'jusbrasil', label: 'JusBrasil' },
      { value: 'outros', label: 'Outros' }
    ].freeze

    URGENCY_LEVELS = [
      { value: 'critica', label: 'Crítica' },
      { value: 'alta', label: 'Alta' },
      { value: 'media', label: 'Média' },
      { value: 'baixa', label: 'Baixa' }
    ].freeze

    DISPOSITION_REASONS = [
      { value: 'invalid', label: 'Inválido' },
      { value: 'spam', label: 'Spam' },
      { value: 'duplicated', label: 'Duplicado' },
      { value: 'no_lead', label: 'Não é lead' }
    ].freeze

    # Valores introduzidos pelo plano descartado são aceitos na borda, mas
    # persistidos com as chaves históricas já usadas pela triagem e pelos dados.
    LEGAL_AREA_ALIASES = {
      'civil' => 'civel',
      'penal' => 'criminal',
      'outros' => 'outro',
      'vendas' => 'comercial',
      'software' => 'tecnologia'
    }.freeze

    def self.canonical_legal_area(value)
      raw = value.to_s.presence
      return if raw.blank?

      LEGAL_AREA_ALIASES.fetch(raw, raw)
    end

    def self.equivalent_legal_areas(value)
      canonical = canonical_legal_area(value)
      return [] if canonical.blank?

      aliases = LEGAL_AREA_ALIASES.filter_map { |legacy, target| legacy if target == canonical }
      ([canonical] + aliases).uniq
    end

    def self.payload
      {
        legal_areas: LEGAL_AREAS,
        lead_sources: LEAD_SOURCES,
        urgency_levels: URGENCY_LEVELS,
        disposition_reasons: DISPOSITION_REASONS
      }
    end
  end
end
