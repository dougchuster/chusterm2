# frozen_string_literal: true

class BlockActiveStorageMultirangeRequests
  ACTIVE_STORAGE_PROXY_PATH = %r{\A/rails/active_storage/(?:blobs|representations)/proxy/}

  def initialize(app)
    @app = app
  end

  def call(env)
    return reject_multirange if active_storage_proxy_request?(env) && multirange_request?(env)

    @app.call(env)
  end

  private

  def active_storage_proxy_request?(env)
    env['PATH_INFO'].to_s.match?(ACTIVE_STORAGE_PROXY_PATH)
  end

  def multirange_request?(env)
    range_header = env['HTTP_RANGE'].to_s
    range_header.start_with?('bytes=') && range_header.include?(',')
  end

  def reject_multirange
    [
      416,
      {
        'Content-Type' => 'text/plain; charset=utf-8',
        'Accept-Ranges' => 'none'
      },
      ['Multi-range requests are not supported for Active Storage proxy URLs.']
    ]
  end
end
