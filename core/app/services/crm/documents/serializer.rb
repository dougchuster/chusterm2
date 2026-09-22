# JSON do cofre para o dashboard. O caminho sai do PathBuilder, o mesmo que
# alimenta espelho, Drive e .zip — a tela mostra exatamente o nome que existe.
class Crm::Documents::Serializer
  PATH_SEPARATOR = '/'.freeze

  def initialize(account:)
    @account = account
    @path_builder = Crm::Documents::Naming::PathBuilder.new
  end

  def document(document)
    file_name = @path_builder.unique_file_name(document)
    identity(document).merge(classification(document), provenance(document)).merge(
      file_name: file_name, name_locked: document.name_locked,
      path: @path_builder.path_for(document, file_name: file_name).join(PATH_SEPARATOR),
      download_path: "/api/v1/accounts/#{@account.id}/crm/documents/#{document.id}/download"
    )
  end

  def folder(folder, documents_count: 0)
    {
      id: folder.id, parent_id: folder.parent_id, deal_id: folder.crm_deal_id, name: folder.name,
      slot: folder.slot, kind: folder.kind, position: folder.position, documents_count: documents_count
    }
  end

  def document_type(type)
    { slug: type.slug, label: type.label, target_slot: type.target_slot, validity_days: type.validity_days }
  end

  private

  def identity(document)
    { id: document.id, contact_id: document.contact_id, folder_id: document.crm_document_folder_id,
      deal_id: document.crm_deal_id, content_type: document.content_type, byte_size: document.byte_size,
      original_filename: document.original_filename, archived_at: document.archived_at,
      created_at: document.created_at, versions_count: document.versions_count,
      previous_version_id: document.meta&.dig('previous_version_id') }
  end

  def classification(document)
    { doc_type: document.doc_type, doc_type_label: type_label(document.doc_type), description: document.description,
      document_date: document.document_date, status: document.status, review_note: document.review_note,
      tags: document.tags, expires_on: document.expires_on, in_triage: document.in_triage? }
  end

  def provenance(document)
    meta = document.meta || {}
    { source: document.source, uploaded_by: uploader(document), source_message_id: document.source_message_id,
      conversation_path: conversation_path(document), caption: meta['caption'],
      suggested_doc_type: meta['suggested_doc_type'], suggested_doc_type_label: type_label(meta['suggested_doc_type']),
      likely_irrelevant: meta['likely_irrelevant'] == true }
  end

  # "Ver na conversa": o vínculo com o WhatsApp nunca se perde (§8.4).
  def conversation_path(document)
    conversation = document.source_message&.conversation
    return if conversation.nil?

    "/app/accounts/#{@account.id}/conversations/#{conversation.display_id}"
  end

  # Uma consulta para a lista inteira, em vez de uma por documento.
  def type_label(slug)
    return if slug.blank?

    @type_labels ||= @account.crm_document_types.pluck(:slug, :label).to_h
    @type_labels[slug]
  end

  def uploader(document)
    return { type: 'contact' } if document.uploaded_by_contact?
    return if document.uploaded_by_user.nil?

    { type: 'user', id: document.uploaded_by_user_id, name: document.uploaded_by_user.name }
  end
end
