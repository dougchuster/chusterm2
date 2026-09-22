# Valida e normaliza as respostas de um formulário público, campo a campo,
# conforme o tipo definido pela conta. Campo escondido por condição (show_if)
# não é exigido nem gravado. Nunca confia no que o navegador mandou.
class Crm::Documents::FormAnswers
  TEXT_MAX = 500
  TEXTAREA_MAX = 5000
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
  BOOLEAN = ActiveModel::Type::Boolean.new

  attr_reader :values, :errors

  # `skip_mapped`: no link personalizado o cliente já é conhecido, então os
  # campos ligados ao contato (nome, telefone, e-mail) nem aparecem.
  def self.fields_for(form, skip_mapped: false)
    fields = Array(form.fields).map { |field| field.to_h.stringify_keys }
    skip_mapped ? fields.reject { |field| field['maps_to'].present? } : fields
  end

  def initialize(form, raw, skip_mapped: false)
    @fields = self.class.fields_for(form, skip_mapped: skip_mapped)
    @raw = raw.to_h.stringify_keys
    @values = {}
    @errors = {}
  end

  def valid?
    @fields.each { |field| evaluate(field) if visible?(field['show_if']) }
    @errors.empty?
  end

  # Mesmo critério de visibilidade vale para os documentos pedidos.
  def visible?(condition)
    return true if condition.blank?

    condition = condition.to_h.stringify_keys
    answer = @values.key?(condition['field']) ? @values[condition['field']] : @raw[condition['field']]
    Array(answer).map(&:to_s).include?(condition['equals'].to_s)
  end

  def mapped(target)
    field = @fields.find { |f| f['maps_to'] == target }
    field && @values[field['key']]
  end

  private

  def evaluate(field)
    key = field['key']
    value = normalize(field, @raw[key])
    return @errors[key] = 'Campo obrigatório.' if field['required'] && blank_answer?(value)
    return if blank_answer?(value)

    error = invalid_message(field, value)
    error ? @errors[key] = error : @values[key] = value
  end

  def blank_answer?(value)
    value.nil? || value == '' || value == [] || value == false
  end

  def normalize(field, value)
    case field['type']
    when 'checkbox' then BOOLEAN.cast(value) == true
    when 'checkboxes' then Array(value).map { |v| v.to_s.strip }.compact_blank
    when 'phone', 'cpf', 'cnpj', 'cpf_cnpj' then value.to_s.gsub(/\D/, '')
    else value.to_s.strip
    end
  end

  def invalid_message(field, value)
    VALIDATORS[field['type']]&.call(value, field)
  end

  VALIDATORS = {
    'text' => ->(v, _) { "Use até #{TEXT_MAX} caracteres." if v.length > TEXT_MAX },
    'textarea' => ->(v, _) { "Use até #{TEXTAREA_MAX} caracteres." if v.length > TEXTAREA_MAX },
    'email' => ->(v, _) { 'E-mail inválido.' unless EMAIL_FORMAT.match?(v) && v.length <= 254 },
    'phone' => ->(v, _) { 'Telefone inválido. Informe com DDD.' unless v.length.between?(10, 13) },
    'cpf' => ->(v, _) { 'CPF inválido.' unless Crm::Documents::TaxId.cpf?(v) },
    'cnpj' => ->(v, _) { 'CNPJ inválido.' unless Crm::Documents::TaxId.cnpj?(v) },
    'cpf_cnpj' => ->(v, _) { 'CPF ou CNPJ inválido.' unless Crm::Documents::TaxId.cpf?(v) || Crm::Documents::TaxId.cnpj?(v) },
    'date' => ->(v, _) { 'Data inválida.' unless Crm::Documents::FormAnswers.valid_date?(v) },
    'number' => ->(v, _) { 'Número inválido.' unless v.match?(/\A-?\d+([.,]\d+)?\z/) },
    'select' => ->(v, f) { 'Escolha uma das opções.' unless Array(f['options']).map(&:to_s).include?(v) },
    'radio' => ->(v, f) { 'Escolha uma das opções.' unless Array(f['options']).map(&:to_s).include?(v) },
    'checkboxes' => ->(v, f) { 'Opção inválida.' unless (v - Array(f['options']).map(&:to_s)).empty? }
  }.freeze

  class << self
    def valid_date?(value)
      Date.iso8601(value).present?
    rescue Date::Error
      false
    end
  end
end
