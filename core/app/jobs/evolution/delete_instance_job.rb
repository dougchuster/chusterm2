# frozen_string_literal: true

class Evolution::DeleteInstanceJob < ApplicationJob
  queue_as :low

  retry_on Evolution::TimeoutError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(instance_id)
    instance = EvolutionInstance.find(instance_id)
    Evolution::InstanceService.new(instance: instance).delete_remote!
  end
end
