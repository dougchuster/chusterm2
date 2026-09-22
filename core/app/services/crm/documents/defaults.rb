# Copia o catálogo padrão (config/crm_documents/defaults.yml) para a conta na
# primeira vez que o cofre é usado. Idempotente e seguro sob concorrência:
# só cria o que falta e trata a corrida pelo índice único como sucesso.
module Crm::Documents::Defaults
  PATH = Rails.root.join('config/crm_documents/defaults.yml')
  GENERIC_AREA = 'geral'.freeze

  module_function

  def config
    @config ||= YAML.safe_load_file(PATH).freeze
  end

  def ensure!(account)
    ensure_types(account)
    ensure_client_template(account)
    ensure_case_templates(account)
    account
  end

  # Área do processo → chave do modelo de subpastas. Aceita aliases do CRM
  # (civil → civel) e áreas que compartilham estrutura (consumidor → civel).
  def case_area_for(value)
    area = Crm::DomainOptions.canonical_legal_area(value)
    return GENERIC_AREA if area.blank?

    area = config.fetch('case_area_aliases', {}).fetch(area, area)
    config.fetch('case_templates').key?(area) ? area : GENERIC_AREA
  end

  def ensure_types(account)
    existing = account.crm_document_types.pluck(:slug)
    config.fetch('document_types').each_with_index do |type, index|
      next if existing.include?(type['slug'])

      create_quietly do
        account.crm_document_types.create!(
          slug: type['slug'], label: type['label'], target_slot: type['target_slot'],
          validity_days: type['validity_days'], patterns: Array(type['patterns']), position: index
        )
      end
    end
  end

  def ensure_client_template(account)
    return if account.crm_document_folder_templates.client_scope.exists?

    template = config.fetch('client_template')
    create_quietly do
      account.crm_document_folder_templates.create!(
        scope: 'client', legal_area: GENERIC_AREA, name: template['name'], tree: template['tree'], default: true
      )
    end
  end

  def ensure_case_templates(account)
    existing = account.crm_document_folder_templates.case_scope.pluck(:legal_area)
    config.fetch('case_templates').each do |area, template|
      next if existing.include?(area)

      create_quietly do
        account.crm_document_folder_templates.create!(
          scope: 'case', legal_area: area, name: template['name'], tree: template['tree'], default: area == GENERIC_AREA
        )
      end
    end
  end

  # Savepoint próprio: a violação de índice único não pode abortar a transação
  # de quem chamou. Corrida perdida = outro processo já criou = sucesso.
  def create_quietly(&)
    ActiveRecord::Base.transaction(requires_new: true, &)
  rescue ActiveRecord::RecordNotUnique
    nil
  rescue ActiveRecord::RecordInvalid => e
    raise unless e.record.errors.details.values.flatten.any? { |detail| detail[:error] == :taken }
  end
end
