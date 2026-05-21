# frozen_string_literal: true

# Polls Evolution API for each Baileys-backed inbox so degradations appear in provider_config
# even when webhooks were missed (firewall, wrong URL, intermittent failures).
class Channels::EvolutionConnectionHealthJob < ApplicationJob
  queue_as :low

  def perform
    Evolution::SyncConnectionStatusJob.perform_now

    Channel::Whatsapp.where(provider: 'evolution').find_each do |channel|
      next if channel.evolution_instance.present?
      next unless channel.account.active?

      service = Whatsapp::Providers::EvolutionService.new(whatsapp_channel: channel)
      state = service.connection_status.to_s
      next if state.blank? || state == 'unknown'

      downcased = state.downcase
      if %w[open connected].include?(downcased)
        channel.evolution_update_health!(state: state, error: nil)
        next
      end

      bad = %w[close closed disconnected logout]
      if bad.include?(downcased)
        detail = "Evolution API retornou estado '#{state}'. " \
                 'Verifique os logs do container evolution-api e refaça o QR se o canal ficar instável.'
        channel.evolution_record_session_warning!(
          code: 'connection_state_degraded',
          detail: detail
        )
        channel.evolution_update_health!(state: state, error: detail)
        Rails.logger.warn "[EVOLUTION][poll] #{channel.phone_number} state=#{state}"
      else
        channel.evolution_update_health!(state: state, error: nil)
      end
    end
  end
end
