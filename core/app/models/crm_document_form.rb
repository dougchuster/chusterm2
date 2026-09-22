# Formulário de envio montado pela conta (PROJETO-COFRE-DOCUMENTOS.md §8.7):
# campos que o cliente preenche, documentos pedidos e textos. Link público
# fixo em /f/<public_token>. Estrutura validada por Crm::Documents::FormSchema.
class CrmDocumentForm < ApplicationRecord
  TOKEN_LENGTH = 20

  belongs_to :account
  belongs_to :created_by_user, class_name: 'User', optional: true
  has_many :crm_document_form_links, dependent: nil
  has_many :crm_document_submissions, dependent: nil

  before_validation :assign_public_token, on: :create

  validates :name, presence: true, length: { maximum: 120 }
  validates :public_token, presence: true, uniqueness: true
  validate :schema_valid

  scope :kept, -> { where(archived_at: nil) }
  scope :published, -> { kept.where(active: true) }

  def setting(key)
    settings.to_h[key.to_s]
  end

  private

  def assign_public_token
    self.public_token ||= SecureRandom.alphanumeric(TOKEN_LENGTH)
  end

  def schema_valid
    Crm::Documents::FormSchema.new(self).errors.each { |error| errors.add(:base, error) }
  end
end
