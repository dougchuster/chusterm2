# Link personalizado de um formulário para um cliente já conhecido ("o que
# falta", §8.7 modo B). O cliente não se identifica de novo e o envio entra
# verificado. Só o SHA-256 do token é gravado; o token cru sai uma única vez.
class CrmDocumentFormLink < ApplicationRecord
  DEFAULT_TTL = 7.days

  belongs_to :account
  belongs_to :crm_document_form
  belongs_to :contact
  belongs_to :crm_deal, optional: true
  belongs_to :created_by_user, class_name: 'User', optional: true

  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # Cria o link e devolve [link, token_cru].
  def self.issue!(form:, contact:, deal: nil, user: nil, ttl: DEFAULT_TTL)
    token = SecureRandom.urlsafe_base64(32)
    link = create!(account: form.account, crm_document_form: form, contact: contact, crm_deal: deal,
                   created_by_user: user, token_digest: digest(token), expires_at: Time.current + ttl)
    [link, token]
  end

  def self.find_usable(token)
    link = find_by(token_digest: digest(token))
    link if link&.usable?
  end

  def usable?
    revoked_at.nil? && expires_at.future? && crm_document_form&.active? && crm_document_form.archived_at.nil?
  end
end
