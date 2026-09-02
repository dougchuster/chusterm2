# frozen_string_literal: true

# The Evolution Manager is intentionally unavailable through the public Rails
# application. Administrators must use an SSH tunnel to the loopback-only
# Evolution port; the global API key must never be rendered into a browser page.
class EvoManagerController < ActionController::Base
  def login
    head :not_found
  end

  def authenticate
    head :not_found
  end
end
