# Valida a estrutura de um formulário montado pela conta.
#
# fields:         [{ key, label, type, required, help, placeholder, options, maps_to, show_if }]
# document_items: [{ key, label, doc_type, required, help, multiple, show_if }]
# settings:       { intro, success_message, consent_text, submit_label }
#
# `maps_to` liga um campo ao cadastro do contato (nome, telefone, e-mail). O
# formulário público precisa de nome e de telefone ou e-mail para identificar
# quem enviou. `show_if` ({ field, equals }) mostra o campo/documento só quando
# um campo de escolha ANTERIOR tem aquele valor.
class Crm::Documents::FormSchema
  FIELD_TYPES = %w[text textarea email phone cpf cnpj cpf_cnpj date number select radio checkbox checkboxes].freeze
  CHOICE_TYPES = %w[select radio checkboxes].freeze
  CONDITION_SOURCE_TYPES = %w[select radio checkbox].freeze
  MAPS_TO = %w[contact_name contact_phone contact_email].freeze
  KEY_FORMAT = /\A[a-z][a-z0-9_]{0,39}\z/
  MAX_FIELDS = 40
  MAX_ITEMS = 30
  MAX_OPTIONS = 30
  TEXT_LIMITS = { 'intro' => 2000, 'success_message' => 1000, 'consent_text' => 2000, 'submit_label' => 40 }.freeze

  def initialize(form)
    @form = form
    @errors = []
  end

  def errors
    fields = Array(@form.fields).map { |field| field.to_h.stringify_keys }
    items = Array(@form.document_items).map { |item| item.to_h.stringify_keys }
    check_fields(fields)
    check_items(items, fields)
    check_identification(fields)
    check_settings(@form.settings.to_h)
    @errors
  end

  private

  def check_fields(fields)
    @errors << "no máximo #{MAX_FIELDS} campos" if fields.size > MAX_FIELDS
    check_keys(fields, 'campo')
    fields.each_with_index { |field, index| check_field(field, fields.first(index), index) }
    duplicated = fields.filter_map { |f| f['maps_to'].presence }.tally.select { |_, count| count > 1 }.keys
    @errors << "mais de um campo ligado a #{duplicated.join(', ')}" if duplicated.any?
  end

  def check_field(field, previous, index)
    label = field['label'].presence || "campo #{index + 1}"
    @errors << "\"#{label}\": precisa de um nome" if field['label'].blank?
    @errors << "\"#{label}\": tipo de campo desconhecido" if FIELD_TYPES.exclude?(field['type'])
    @errors << "\"#{label}\": ligação com o contato desconhecida" if unknown_mapping?(field)
    check_options(field, label)
    check_condition(field['show_if'], previous, label)
  end

  def unknown_mapping?(field)
    field['maps_to'].present? && MAPS_TO.exclude?(field['maps_to'])
  end

  def check_items(items, fields)
    @errors << "no máximo #{MAX_ITEMS} documentos pedidos" if items.size > MAX_ITEMS
    check_keys(items, 'documento')
    items.each { |item| check_item(item, fields) }
  end

  def check_item(item, fields)
    label = "documento \"#{item['label'].presence || item['key']}\""
    @errors << "#{label}: precisa de um nome" if item['label'].blank?
    @errors << "#{label}: tipo \"#{item['doc_type']}\" não existe no catálogo" if unknown_type?(item['doc_type'])
    check_condition(item['show_if'], fields, label)
  end

  def unknown_type?(slug)
    return false if slug.blank?

    @known_types ||= @form.account&.crm_document_types&.pluck(:slug) || []
    @known_types.exclude?(slug)
  end

  def check_keys(entries, noun)
    keys = entries.map { |entry| entry['key'].to_s }
    invalid = keys.grep_v(KEY_FORMAT)
    @errors << "#{noun}: chave inválida (#{invalid.join(', ')}) — use letras minúsculas, números e _" if invalid.any?
    repeated = keys.tally.select { |_, count| count > 1 }.keys
    @errors << "#{noun}: chave repetida (#{repeated.join(', ')})" if repeated.any?
  end

  def check_options(field, label)
    return unless CHOICE_TYPES.include?(field['type'])

    options = Array(field['options']).map { |option| option.to_s.strip }.compact_blank
    @errors << "\"#{label}\": informe as opções" if options.empty?
    @errors << "\"#{label}\": no máximo #{MAX_OPTIONS} opções" if options.size > MAX_OPTIONS
  end

  def check_condition(condition, previous_fields, label)
    return if condition.blank?

    source = previous_fields.find { |field| field['key'] == condition.to_h.stringify_keys['field'] }
    return if source && CONDITION_SOURCE_TYPES.include?(source['type'])

    @errors << "#{label}: a condição precisa apontar para um campo de escolha que vem antes"
  end

  def check_identification(fields)
    targets = fields.filter_map { |field| field['maps_to'].presence }
    return if targets.include?('contact_name') && targets.intersect?(%w[contact_phone contact_email])

    @errors << 'o formulário precisa de um campo ligado ao nome e outro ao telefone ou e-mail do contato'
  end

  def check_settings(settings)
    TEXT_LIMITS.each do |key, limit|
      @errors << "texto \"#{key}\" passa de #{limit} caracteres" if settings[key].to_s.length > limit
    end
  end
end
