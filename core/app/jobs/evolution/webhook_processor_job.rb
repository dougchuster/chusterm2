# frozen_string_literal: true

class Evolution::WebhookProcessorJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(event_id)
    event = EvolutionWebhookEvent.find(event_id)
    Evolution::WebhookProcessorService.new(event: event).perform
  end
end
