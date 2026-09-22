# Fila "Novos envios" (PROJETO-COFRE-DOCUMENTOS.md §8.7.2): o que chegou pelos
# formulários, com as respostas, a identificação do contato e os arquivos.
# Ações: marcar verificado, concluir ou spam (spam arquiva os arquivos).
class Api::V1::Accounts::Crm::DocumentSubmissionsController < Api::V1::Accounts::Crm::DocumentsBaseController
  PER_PAGE = 30

  before_action :load_submission, only: [:show, :update]

  def index
    authorize CrmDocument, :index?
    scope = visible_submissions.where(review_status: status_filter).recent
    page = [params[:page].to_i, 1].max
    records = scope.includes(:crm_document_form, :contact).offset((page - 1) * PER_PAGE).limit(PER_PAGE)
    render json: { payload: records.map { |s| serialize(s) }, meta: { count: scope.count, page: page } }
  end

  def show
    authorize CrmDocument, :index?
    render json: serialize(@submission).merge(documents: @submission.documents.active.map { |d| serializer.document(d) })
  end

  def update
    authorize CrmDocument, :review?
    Crm::Documents::SubmissionReviewer.new(@submission, user: Current.user).call(
      review_status: params[:review_status], verified: params[:verified]
    )
    audit('document_submission_reviewed', @submission, review_status: @submission.review_status,
                                                       verified: @submission.verified)
    render json: serialize(@submission.reload)
  rescue ArgumentError => e
    render_unprocessable(e.message)
  end

  private

  def visible_submissions
    scope = CrmDocumentSubmission.where(account_id: Current.account.id)
    documents_access.administrator? ? scope : scope.where(contact_id: documents_access.visible_contacts.select(:id))
  end

  def load_submission
    @submission = visible_submissions.find(params[:id])
  end

  def status_filter
    CrmDocumentSubmission::REVIEW_STATUSES.include?(params[:review_status]) ? params[:review_status] : 'new'
  end

  def serialize(submission)
    form = submission.crm_document_form
    {
      id: submission.id, protocol: submission.protocol, created_at: submission.created_at,
      review_status: submission.review_status, verified: submission.verified, match_status: submission.match_status,
      documents_count: submission.documents_count, contact_id: submission.contact_id,
      contact_name: submission.contact&.name, form_id: form&.id, form_name: form&.name,
      answers: labeled_answers(form, submission.answers)
    }
  end

  # Respostas com o rótulo do campo, na ordem do formulário.
  def labeled_answers(form, answers)
    fields = Array(form&.fields).map { |field| field.to_h.stringify_keys }
    fields.filter_map do |field|
      next unless answers.key?(field['key'])

      { key: field['key'], label: field['label'], type: field['type'], value: answers[field['key']] }
    end
  end
end
