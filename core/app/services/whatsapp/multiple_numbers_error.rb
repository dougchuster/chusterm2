# frozen_string_literal: true

module Whatsapp
  class MultipleNumbersError < StandardError
    attr_reader :phone_numbers
    attr_accessor :session_key

    def initialize(phone_numbers, session_key: nil)
      @phone_numbers = phone_numbers
      @session_key = session_key
      super('A WABA possui múltiplos números. Selecione o número desejado.')
    end
  end
end
