# frozen_string_literal: true

# This migration is a no-op because the `provider` column on channel_whatsapp
# is a plain string and already accepts any value validated by the model.
# We add a comment documenting that 'evolution' is now a valid provider.
class AddEvolutionProviderToChannelWhatsapp < ActiveRecord::Migration[7.0]
  def up
    # The provider column is a string field, no schema change needed.
    # Model validation updated: PROVIDERS = %w[default whatsapp_cloud evolution]
    #
    # Ensure provider_config JSONB can hold evolution-specific keys:
    #   api_url, api_key, instance_name, latest_qr, webhook_verify_token
    #
    # This is a documentation-only migration for tracking purposes.
  end

  def down
    # Nothing to revert
  end
end
