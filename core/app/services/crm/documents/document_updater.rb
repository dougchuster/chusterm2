# Aplica uma edição da equipe a um documento e devolve o que mudou (para a
# auditoria). Duas regras de produto moram aqui:
#
# - Classificar um documento que está na Triagem leva ele para a pasta do tipo.
#   Documento já organizado continua onde está: mudar o tipo não o arrasta.
# - Renomear à mão trava o nome (name_locked); nome em branco destrava e volta
#   à nomenclatura automática.
class Crm::Documents::DocumentUpdater
  IGNORED_CHANGES = %w[updated_at].freeze
  FILE_NAME_MAX = 160

  def initialize(document:, attributes:)
    @document = document
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
    attributes = @attributes.dup
    apply_manual_name(attributes) if attributes.key?(:file_name)
    route_from_triage(attributes)
    @document.update!(attributes)
    @document.saved_changes.except(*IGNORED_CHANGES).transform_values { |(from, to)| { from: from, to: to } }
  end

  private

  def apply_manual_name(attributes)
    name = attributes[:file_name].to_s.strip
    if name.blank?
      attributes[:name_locked] = false
      attributes.delete(:file_name)
      return
    end

    attributes[:file_name] = with_extension(Crm::Documents::Naming::Sanitizer.call(name, max: FILE_NAME_MAX))
    attributes[:name_locked] = true
  end

  def with_extension(name)
    extension = File.extname(@document.file_name.to_s)
    return name if extension.blank? || name.downcase.end_with?(extension.downcase)

    "#{name}#{extension}"
  end

  def route_from_triage(attributes)
    return if attributes[:doc_type].blank? || attributes.key?(:crm_document_folder_id)
    return unless @document.crm_document_folder.nil? || @document.crm_document_folder.slot == Crm::Documents::Router::TRIAGE_SLOT

    router = Crm::Documents::Router.new(@document.contact, deal: deal_for(attributes))
    attributes[:crm_document_folder_id] = router.folder_for(attributes[:doc_type]).id
  end

  def deal_for(attributes)
    return @document.crm_deal unless attributes.key?(:crm_deal_id)

    attributes[:crm_deal_id] && CrmDeal.find_by(id: attributes[:crm_deal_id], account_id: @document.account_id)
  end
end
