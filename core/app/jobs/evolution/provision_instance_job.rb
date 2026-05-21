# frozen_string_literal: true

class Evolution::ProvisionInstanceJob < ApplicationJob
  queue_as :low

  retry_on Evolution::TimeoutError, wait: :exponentially_longer, attempts: 5
  retry_on Evolution::ApiError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(instance_id)
    instance = EvolutionInstance.find(instance_id)
    Evolution::InstanceService.new(instance: instance).provision!
  end
end
