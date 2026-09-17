class Marketing::SyncAccountJob < ApplicationJob
  queue_as :default

  def perform(connection_id)
    connection = CrmExternalConnection.marketing.find_by(id: connection_id)
    return if connection.nil?

    Marketing::Sync::AccountService.new(connection: connection).perform!
  end
end
