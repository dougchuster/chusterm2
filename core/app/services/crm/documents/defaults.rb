# Modelos de documentos por área (config/crm_documents/presets/<slug>.yml):
# geral (universal), jurídico, saúde, imobiliário, educação. Na primeira vez
# que o cofre é usado, a conta recebe as configurações (modelo + padrões de
# nome) e uma cópia do catálogo e das pastas do modelo; depois edita tudo pela
# tela. Idempotente e seguro sob concorrência.
module Crm::Documents::Defaults
  DEFAULT_PRESET = Crm::Documents::Presets::DEFAULT
  GENERIC_AREA = 'geral'.freeze
  # Pack vertical do CRM → modelo de documentos correspondente.
  PACK_PRESETS = { 'legal' => 'legal', 'clinic' => 'clinic', 'real_estate' => 'real_estate',
                   'education' => 'education' }.freeze
  # Contas que usaram o cofre antes dos modelos por área só conheciam o
  # catálogo jurídico: a presença deste tipo identifica esse caso.
  LEGACY_LEGAL_MARKER = 'cnis'.freeze

  module_function

  def preset_slugs = Crm::Documents::Presets.slugs
  def presets = Crm::Documents::Presets.list
  def preset_config(slug) = Crm::Documents::Presets.fetch(slug)

  # Configuração do modelo em uso pela conta.
  def config(account = nil)
    preset_config(settings_for(account)&.preset || DEFAULT_PRESET)
  end

  def settings_for(account)
    return if account.nil?

    account.crm_document_setting || ensure_settings(account)
  end

  def ensure!(account, preset: nil)
    ensure_settings(account, preset: preset)
    catalog = config(account)
    ensure_types(account, catalog)
    ensure_client_template(account, catalog)
    ensure_case_templates(account, catalog)
    account
  end

  # Troca o modelo da conta: acrescenta os tipos e substitui os modelos de
  # pasta. Pastas e documentos que já existem não mudam.
  def apply_preset!(account, slug)
    settings = ensure_settings(account)
    settings.update!(preset: slug)
    catalog = preset_config(slug)
    ensure_types(account, catalog)
    replace_templates(account, catalog)
    account
  end

  def ensure_settings(account, preset: nil)
    existing = account.crm_document_setting || CrmDocumentSetting.find_by(account_id: account.id)
    return existing if existing

    create_quietly { account.create_crm_document_setting!(preset: preset || initial_preset(account)) }
    account.reload_crm_document_setting
  end

  def initial_preset(account)
    return 'legal' if account.crm_document_types.exists?(slug: LEGACY_LEGAL_MARKER)

    pack = account.crm_account_packs.order(:installed_at).pluck(:slug).find { |slug| PACK_PRESETS.key?(slug) }
    PACK_PRESETS.fetch(pack, DEFAULT_PRESET)
  end

  # Área do negócio → modelo de subpastas. Modelo sem a área usa `geral`.
  def case_area_for(value, account = nil)
    catalog = config(account)
    area = Crm::DomainOptions.canonical_legal_area(value)
    return GENERIC_AREA if area.blank?

    area = catalog.fetch('case_area_aliases', {}).to_h.fetch(area, area)
    catalog.fetch('case_templates').key?(area) ? area : GENERIC_AREA
  end

  def ensure_types(account, catalog)
    existing = account.crm_document_types.pluck(:slug)
    catalog.fetch('document_types').each_with_index do |type, index|
      next if existing.include?(type['slug'])

      create_quietly do
        account.crm_document_types.create!(
          slug: type['slug'], label: type['label'], target_slot: type['target_slot'],
          validity_days: type['validity_days'], patterns: Array(type['patterns']), position: index
        )
      end
    end
  end

  def ensure_client_template(account, catalog)
    return if account.crm_document_folder_templates.client_scope.exists?

    template = catalog.fetch('client_template')
    create_quietly do
      account.crm_document_folder_templates.create!(
        scope: 'client', legal_area: GENERIC_AREA, name: template['name'], tree: template['tree'], default: true
      )
    end
  end

  def ensure_case_templates(account, catalog)
    existing = account.crm_document_folder_templates.case_scope.pluck(:legal_area)
    catalog.fetch('case_templates').each do |area, template|
      next if existing.include?(area)

      create_quietly do
        account.crm_document_folder_templates.create!(
          scope: 'case', legal_area: area, name: template['name'], tree: template['tree'], default: area == GENERIC_AREA
        )
      end
    end
  end

  def replace_templates(account, catalog)
    CrmDocumentFolderTemplate.transaction do
      account.crm_document_folder_templates.delete_all
      ensure_client_template(account, catalog)
      ensure_case_templates(account, catalog)
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
