# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlockActiveStorageMultirangeRequests do
  let(:app) { ->(_env) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }
  let(:middleware) { described_class.new(app) }

  it 'blocks multi-range requests against Active Storage proxy URLs' do
    status, headers, body = middleware.call(
      'PATH_INFO' => '/rails/active_storage/blobs/proxy/signed-id/file.png',
      'HTTP_RANGE' => 'bytes=0-10,20-30'
    )

    expect(status).to eq(416)
    expect(headers['Accept-Ranges']).to eq('none')
    expect(body.join).to include('Multi-range')
  end

  it 'allows single range requests against Active Storage proxy URLs' do
    status, = middleware.call(
      'PATH_INFO' => '/rails/active_storage/blobs/proxy/signed-id/file.png',
      'HTTP_RANGE' => 'bytes=0-10'
    )

    expect(status).to eq(200)
  end

  it 'allows multi-range requests outside Active Storage proxy URLs' do
    status, = middleware.call(
      'PATH_INFO' => '/rails/active_storage/blobs/redirect/signed-id/file.png',
      'HTTP_RANGE' => 'bytes=0-10,20-30'
    )

    expect(status).to eq(200)
  end
end
