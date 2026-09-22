# Encontra ou cria o contato de um envio pelo formulário público
# (PROJETO-COFRE-DOCUMENTOS.md §8.7.2): WhatsApp/telefone primeiro, depois
# e-mail; sem nenhum, cria o contato. Contato existente NUNCA é alterado por
# quem preencheu o formulário — o envio entra "não verificado".
class Crm::Documents::ContactResolver
  Result = Struct.new(:contact, :match_status, keyword_init: true)
  BRAZIL_CODE = '55'.freeze

  def initialize(account:, name:, phone: nil, email: nil)
    @account = account
    @name = name.to_s.strip
    @phone = self.class.e164(phone)
    @email = email.to_s.strip.downcase.presence
  end

  # 10–11 dígitos (DDD + número) viram +55…; 12–13 começando com 55 também.
  def self.e164(digits)
    digits = digits.to_s.gsub(/\D/, '')
    return if digits.blank?
    return "+#{BRAZIL_CODE}#{digits}" if digits.length.between?(10, 11)
    return "+#{digits}" if digits.start_with?(BRAZIL_CODE) && digits.length.between?(12, 13)

    nil
  end

  def call
    by_phone = @phone && @account.contacts.find_by(phone_number: @phone)
    return Result.new(contact: by_phone, match_status: 'matched_phone') if by_phone

    by_email = @email && @account.contacts.where('lower(email) = ?', @email).first
    return Result.new(contact: by_email, match_status: 'matched_email') if by_email

    Result.new(contact: create_contact, match_status: 'new_contact')
  end

  private

  def create_contact
    @account.contacts.create!(
      name: @name.presence || 'Contato do formulário', phone_number: @phone, email: @email,
      additional_attributes: { 'source' => 'document_form' }
    )
  end
end
