# frozen_string_literal: true

class Evolution::SyncConnectionStatusJob < ApplicationJob
  queue_as :low

  discard_on ActiveRecord::RecordNotFound

  def perform(instance_id = nil)
    scope = instance_id.present? ? EvolutionInstance.where(id: instance_id) : EvolutionInstance.includes(:account)

    scope.find_each do |instance|
      next unless instance.account.active?
      next if instance.circuit_open?

      Evolution::InstanceService.new(instance: instance).connection_state
    end
  end
end
