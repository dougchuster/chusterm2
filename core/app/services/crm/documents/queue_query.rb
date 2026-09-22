# Filas do escritório (PROJETO-COFRE-DOCUMENTOS.md §8.5), sempre recortadas
# pelo que o usuário pode ver:
#
# - review:   classificados e ainda não aprovados nem rejeitados
# - expiring: validade vencida ou vencendo em até EXPIRING_DAYS dias
#
# A fila de triagem tem consulta própria (TriageQuery), com contexto extra.
class Crm::Documents::QueueQuery
  QUEUES = %w[review expiring].freeze
  EXPIRING_DAYS = 30

  def initialize(access, queue)
    raise ArgumentError, "fila desconhecida: #{queue}" unless QUEUES.include?(queue.to_s)

    @access = access
    @queue = queue.to_s
  end

  def scope
    base = @access.documents.active.where.not(doc_type: nil)
    @queue == 'review' ? review(base) : expiring(base)
  end

  private

  def review(base)
    base.where(status: 'received').ordered
  end

  def expiring(base)
    base.where.not(status: %w[obsolete rejected])
        .where(expires_on: ..(Date.current + EXPIRING_DAYS))
        .order(:expires_on, :id)
  end
end
