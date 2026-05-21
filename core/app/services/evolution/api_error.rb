# frozen_string_literal: true

module Evolution
  class ApiError < Error
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end
end
