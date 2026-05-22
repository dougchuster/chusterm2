# frozen_string_literal: true

module Evolution
  class SyncHistoryJob < ApplicationJob
    queue_as :low

    def perform(instance_id, limit: Evolution::HistorySyncService::DEFAULT_LIMIT, contact_limit: Evolution::HistorySyncService::DEFAULT_CONTACT_LIMIT)
      instance = EvolutionInstance.find_by(id: instance_id)
      return if instance.blank?

      result = Evolution::HistorySyncService.new(
        instance: instance,
        limit: limit,
        contact_limit: contact_limit
      ).perform

      Rails.logger.info({ component: 'evolution', action: 'history_sync_finished', result: result }.to_json)
    end
  end
end
