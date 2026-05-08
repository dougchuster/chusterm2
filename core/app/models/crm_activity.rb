class CrmActivity < ApplicationRecord
  belongs_to :account
  belongs_to :crm_deal, optional: true
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :owner, class_name: 'User', optional: true
  belongs_to :assignee, class_name: 'User', optional: true

  KINDS = %w[ligacao reuniao analise_documental solicitacao_documentos follow_up envio_contrato
             envio_proposta revisao_juridica retorno_cliente arquivamento].freeze
  PRIORITIES = %w[baixa normal alta critica].freeze

  validates :account, :kind, :title, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :priority, inclusion: { in: PRIORITIES }

  scope :pending, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }
  scope :overdue, -> { pending.where('due_at < ?', Time.current) }
  scope :due_today, -> { pending.where(due_at: Time.current.beginning_of_day..Time.current.end_of_day) }
  scope :synced_to_calendar, -> { where.not(external_calendar_event_id: nil) }

  def complete!(outcome: nil, actor: nil)
    update!(completed_at: Time.current, outcome: outcome)
    Crm::AuditLogger.log(account: account, actor: actor, action: 'activity_completed', target: self) if crm_deal
  end
end
