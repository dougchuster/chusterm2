# frozen_string_literal: true

require Rails.root.join('app/middleware/block_active_storage_multirange_requests')

Rails.application.config.middleware.insert_before 0, BlockActiveStorageMultirangeRequests
