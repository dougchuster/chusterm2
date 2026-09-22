# Dígitos verificadores de CPF e CNPJ (recebe só dígitos).
module Crm::Documents::TaxId
  CNPJ_WEIGHTS_FIRST = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze
  CNPJ_WEIGHTS_SECOND = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2].freeze

  module_function

  def cpf?(digits)
    return false unless digits.to_s.match?(/\A\d{11}\z/) && digits.chars.uniq.size > 1

    numbers = digits.chars.map(&:to_i)
    check(numbers.first(9), (2..10).to_a.reverse) == numbers[9] &&
      check(numbers.first(10), (2..11).to_a.reverse) == numbers[10]
  end

  def cnpj?(digits)
    return false unless digits.to_s.match?(/\A\d{14}\z/) && digits.chars.uniq.size > 1

    numbers = digits.chars.map(&:to_i)
    check(numbers.first(12), CNPJ_WEIGHTS_FIRST) == numbers[12] &&
      check(numbers.first(13), CNPJ_WEIGHTS_SECOND) == numbers[13]
  end

  def check(numbers, weights)
    rest = numbers.zip(weights).sum { |number, weight| number * weight } % 11
    rest < 2 ? 0 : 11 - rest
  end
end
