class Marketing::SyncAccountJob < ApplicationJob
  queue_as :low

  def perform(connection_id)
    connection = CrmExternalConnection.marketing.find_by(id: connection_id)
    return unless connection&.active?

    # Implementado na FASE 2 do plano de marketing: sincroniza campanhas e
    # metricas do provider conectado.
    Marketing::Sync::AccountService.new(connection).perform!
  end
end
