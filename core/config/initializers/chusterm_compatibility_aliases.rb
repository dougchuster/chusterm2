# frozen_string_literal: true

module Enterprise; end unless defined?(Enterprise)

require Rails.root.join('lib/chatwoot_app').to_s
require Rails.root.join('lib/chatwoot_hub').to_s
require Rails.root.join('lib/chatwoot_captcha').to_s
require Rails.root.join('lib/chatwoot_markdown_renderer').to_s
