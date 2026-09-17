# Enfileira o sync de todas as conexoes de marketing ativas.
# Agendado a cada 6h via config/schedule.yml.
class Marketing::SyncAllJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    CrmExternalConnection.marketing.where(status: 'active').find_each do |connection|
      Marketing::SyncAccountJob.perform_later(connection.id)
    end
  end
end
