require 'digest'

class Captain::DocumentVersion < ApplicationRecord
  self.table_name = 'captain_document_versions'

  belongs_to :account
  belongs_to :assistant, class_name: 'Captain::Assistant'
  belongs_to :document, class_name: 'Captain::Document'

  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :content_digest, presence: true, uniqueness: { scope: :document_id }
  validates :metadata, jsonb_attributes_length: true

  scope :ordered, -> { order(version_number: :desc) }

  def self.create_snapshot!(document)
    digest = Digest::SHA256.hexdigest(document.content.to_s)
    return if document.versions.exists?(content_digest: digest)

    document.versions.create!(
      account: document.account,
      assistant: document.assistant,
      version_number: document.versions.maximum(:version_number).to_i + 1,
      name: document.name,
      external_link: document.external_link,
      content: document.content,
      content_digest: digest,
      metadata: document.metadata || {},
      published_at: Time.current
    )
  end
end
