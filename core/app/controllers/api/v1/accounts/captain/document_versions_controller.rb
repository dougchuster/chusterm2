class Api::V1::Accounts::Captain::DocumentVersionsController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Captain::Assistant) }
  before_action :set_version, only: [:show]

  def index
    versions = Current.account.captain_document_versions.includes(:document, :assistant).ordered
    versions = versions.where(document_id: params[:document_id]) if params[:document_id].present?
    versions = versions.where(assistant_id: params[:assistant_id]) if params[:assistant_id].present?

    render json: versions.limit(100).map { |version| version_payload(version) }
  end

  def show
    render json: version_payload(@version, include_content: true)
  end

  private

  def set_version
    @version = Current.account.captain_document_versions.find(params[:id])
  end

  def version_payload(version, include_content: false)
    payload = {
      id: version.id,
      document_id: version.document_id,
      assistant_id: version.assistant_id,
      version_number: version.version_number,
      name: version.name,
      external_link: version.external_link,
      content_digest: version.content_digest,
      metadata: version.metadata,
      published_at: version.published_at,
      created_at: version.created_at
    }
    payload[:content] = version.content if include_content
    payload
  end
end
