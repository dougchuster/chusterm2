# Revisão de um envio pela equipe:
# - verificar: confirma que o envio é mesmo daquele contato; os arquivos
#   deixam de aparecer como "não verificado";
# - concluir: tira da fila "Novos envios" — só depois de verificar, para
#   ninguém dar por bom um arquivo que qualquer pessoa pode ter mandado;
# - spam: tira da fila e arquiva os arquivos (continuam restauráveis).
class Crm::Documents::SubmissionReviewer
  def initialize(submission, user:)
    @submission = submission
    @user = user
  end

  def call(review_status: nil, verified: nil)
    status = review_status.to_s.presence
    raise ArgumentError, 'Situação desconhecida.' if status && CrmDocumentSubmission::REVIEW_STATUSES.exclude?(status)

    CrmDocumentSubmission.transaction do
      verify! if ActiveModel::Type::Boolean.new.cast(verified) == true
      review!(status) if status
    end
    @submission
  end

  private

  def verify!
    @submission.update!(verified: true)
    @submission.documents.find_each do |document|
      document.update!(meta: (document.meta || {}).except('unverified'))
    end
  end

  def review!(status)
    raise ArgumentError, 'Confirme que é este cliente antes de concluir.' if status == 'done' && !@submission.verified

    @submission.update!(review_status: status, reviewed_by_user: @user, reviewed_at: Time.current)
    @submission.documents.active.find_each { |document| document.update!(archived_at: Time.current) } if status == 'spam'
  end
end
