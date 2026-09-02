# frozen_string_literal: true

require 'json'

# Rotates every server-side reference to the Evolution global API key without
# ever printing the credential. The Evolution container itself must be restarted
# with the same EVOLUTION_API_KEY between the persist and verify phases.
phase = ENV.fetch('EVOLUTION_ROTATION_PHASE', 'persist')
new_key = ENV.fetch('EVOLUTION_API_KEY').to_s.strip

raise 'EVOLUTION_API_KEY must contain at least 32 characters' if new_key.length < 32
raise 'Refusing the known development key' if new_key == 'evo_chusterm_secret_key'
raise "Unsupported EVOLUTION_ROTATION_PHASE=#{phase}" unless %w[persist verify].include?(phase)

configurations = EvolutionApiConfiguration.order(:id)
channels = Channel::Whatsapp.where(provider: 'evolution').order(:id)

if phase == 'persist'
  ApplicationRecord.transaction do
    configurations.find_each { |configuration| configuration.update!(global_api_key: new_key) }
    channels.find_each do |channel|
      channel.update!(provider_config: channel.provider_config.to_h.merge('api_key' => new_key))
    end
  end
end

configuration_mismatches = configurations.reject { |configuration| configuration.global_api_key == new_key }
channel_mismatches = channels.reject { |channel| channel.provider_config.to_h['api_key'] == new_key }

raise 'Evolution configuration credential mismatch' if configuration_mismatches.any?
raise 'Evolution channel credential mismatch' if channel_mismatches.any?

instance_results = []
if phase == 'verify'
  EvolutionInstance.managed.order(:id).find_each do |instance|
    service = Evolution::InstanceService.new(instance: instance)
    service.configure_webhook!
    state = service.connection_state
    raise "Evolution instance #{instance.id} is not connected" unless %w[open connected].include?(state.to_s.downcase)

    instance_results << { id: instance.id, connected: true, webhook_configured: true }
  end
end

puts JSON.generate(
  phase: phase,
  configurations_updated: configurations.count,
  channels_updated: channels.count,
  instances: instance_results,
  credential_exposed: false
)
