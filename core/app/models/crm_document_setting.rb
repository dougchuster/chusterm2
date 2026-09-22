# Configurações do cofre por conta: modelo de documentos (geral, jurídico,
# saúde, imobiliário, educação), padrões de nome editáveis e captura.
class CrmDocumentSetting < ApplicationRecord
  NAMING_KEYS = Crm::Documents::Naming::Template::SPECS.keys.freeze

  belongs_to :account

  validates :preset, inclusion: { in: ->(_) { Crm::Documents::Defaults.preset_slugs } }
  validate :naming_templates_valid

  # Padrão efetivo: o da conta ou, se vazio, o do modelo de documentos.
  def naming_template(kind)
    naming.to_h[kind.to_s].presence || Crm::Documents::Defaults.preset_config(preset).dig('naming', kind.to_s)
  end

  def effective_naming
    NAMING_KEYS.index_with { |kind| naming_template(kind) }
  end

  private

  def naming_templates_valid
    naming.to_h.each do |kind, template|
      next if template.blank?
      next errors.add(:naming, "padrão desconhecido: #{kind}") unless NAMING_KEYS.include?(kind.to_s)

      Crm::Documents::Naming::Template.errors_for(kind, template).each { |error| errors.add(:naming, "#{kind}: #{error}") }
    end
  end
end
