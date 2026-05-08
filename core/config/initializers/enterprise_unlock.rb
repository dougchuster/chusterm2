# ChusteRM - Unlock Enterprise Features
# This initializer forces loading all enterprise modules

# Load ChusteRMApp/ChatwootApp compatibility module first
require Rails.root.join('lib/chatwoot_app').to_s

# Override enterprise feature switches
ChusteRMApp.module_eval do
  def self.enterprise?
    true
  end

  def self.otel_enabled?
    true
  end

  def self.self_hosted_enterprise?
    true
  end

  def self.ChusteRM_cloud?
    false
  end

  def self.chatwoot_cloud?
    false
  end

  def self.chusterm_cloud?
    false
  end

  def self.extensions
    %w[enterprise]
  end
end

# Add enterprise paths to autoload
Rails.application.config.autoload_paths += %W[
  #{Rails.root}/enterprise/app/models
  #{Rails.root}/enterprise/app/services
  #{Rails.root}/enterprise/app/jobs
  #{Rails.root}/enterprise/app/controllers
  #{Rails.root}/enterprise/app/policies
  #{Rails.root}/enterprise/app/builders
  #{Rails.root}/enterprise/app/finders
  #{Rails.root}/enterprise/app/presenters
  #{Rails.root}/enterprise/app/mailers
  #{Rails.root}/enterprise/app/helpers
  #{Rails.root}/enterprise/app/dispatchers
  #{Rails.root}/enterprise/app/drops
  #{Rails.root}/enterprise/app/fields
  #{Rails.root}/enterprise/app/listeners
  #{Rails.root}/enterprise/lib
]

# Garante que as views enterprise estejam no path independente de DISABLE_ENTERPRISE
unless Rails.application.config.paths['app/views'].to_a.include?('enterprise/app/views')
  Rails.application.config.paths['app/views'].unshift('enterprise/app/views')
end

puts 'ChusteRM: Enterprise features unlocked'
