# Atribuir o dono de um deal combina três efeitos — `owner_id`, `assignee_id`
# e o `crm_owner_id` do contato — e cada ponto de chamada precisa de uma
# combinação diferente:
#
#   ação manual em lote (DealsController#bulk_action) → owner + assignee + contato
#   regra de automação (Crm::StageAutomation)          → owner + assignee condicional
#   sincronização do roteador (Crm::ContactOwnerRouter) → só owner (o contato é a fonte)
#
# A lógica vivia reimplementada nos três lugares e divergiu (bug A-03).
# Aqui a combinação é explícita: `sync_assignee` controla o responsável,
# `sync_contact` controla se o dono do contato acompanha o deal.
class Crm::DealOwnerAssigner
  ASSIGNEE_SYNC_MODES = %i[always if_unmanaged never].freeze

  Result = Struct.new(:performed, :preserved_assignee_id, keyword_init: true)

  # rubocop:disable Metrics/ParameterLists
  def initialize(deal:, owner:, actor: nil, sync_assignee: :if_unmanaged, sync_contact: false, contact_source: 'manual')
    raise ArgumentError, "sync_assignee desconhecido: #{sync_assignee.inspect}" unless ASSIGNEE_SYNC_MODES.include?(sync_assignee)

    @deal = deal
    @owner = owner
    @actor = actor
    @sync_assignee = sync_assignee
    @sync_contact = sync_contact
    @contact_source = contact_source
  end

  def perform
    previous_owner_id = @deal.owner_id
    preserved_assignee_id = nil

    attributes = { owner_id: @owner&.id }
    case @sync_assignee
    when :always
      attributes[:assignee_id] = @owner&.id
    when :if_unmanaged
      if hand_picked_assignee?(previous_owner_id)
        preserved_assignee_id = @deal.assignee_id
      else
        attributes[:assignee_id] = @owner&.id
      end
    end

    @deal.update!(attributes)
    sync_contact_owner!

    Result.new(performed: true, preserved_assignee_id: preserved_assignee_id)
  end

  private

  # Um responsável diferente do dono anterior foi escolhido a dedo — nunca
  # tiramos o caso dessa pessoa. Responsável vazio ou apenas seguindo o dono
  # anterior acompanha o dono novo.
  def hand_picked_assignee?(previous_owner_id)
    @deal.assignee_id.present? && @deal.assignee_id != previous_owner_id
  end

  def sync_contact_owner!
    return unless @sync_contact
    return if @deal.contact.nil?

    @deal.contact.assign_crm_owner!(@owner, source: @contact_source, actor: @actor)
  end
  # rubocop:enable Metrics/ParameterLists
end
