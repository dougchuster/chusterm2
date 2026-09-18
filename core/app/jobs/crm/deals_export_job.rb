# PERF-04: export de deals em background (padrão do Account::ContactsExportJob):
# gera o CSV fora do request, anexa em Active Storage e envia o link por email.
class Crm::DealsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, filters = {})
    @account = Account.find(account_id)
    @user = @account.users.find(user_id)

    deals = Crm::DealFilterService.new(scope: @account.crm_deals.visible_to(@user, @account), filters: filters).perform
                                  .order(created_at: :desc)
                                  .includes(:crm_pipeline_stage, :crm_loss_reason, :contact)

    attach_export_file(build_csv(deals))
    send_mail
  end

  private

  def attach_export_file(csv_data)
    @account.crm_deals_export.attach(
      io: StringIO.new(csv_data),
      filename: "crm_deals_#{Date.today.iso8601}.csv",
      content_type: 'text/csv'
    )
  end

  def send_mail
    # URL de serviço com expiração de 24h: o rails_blob_url permanente deixava
    # o CSV (com dados LGPD) acessível para sempre a qualquer portador do link.
    file_url = @account.crm_deals_export.blob.url(expires_in: 24.hours)
    mailer = AdministratorNotifications::AccountNotificationMailer.with(account: @account)
    mailer.crm_deals_export_complete(file_url, @user.email)&.deliver_later
  end

  def build_csv(deals)
    require 'csv'

    headers = [
      'ID', 'Título', 'Status', 'Área Jurídica', 'Tipo de Caso',
      'Urgência', 'Score', 'Classificação', 'Valor Estimado (R$)',
      'Probabilidade (%)', 'Etapa', 'Base LGPD', 'Consentimento',
      'Canal Consentimento', 'Coleta Consentimento', 'Retenção Até',
      'Resumo', 'Próxima Ação', 'Contato ID', 'Conversa ID',
      'Motivo Perda', 'Criado Em', 'Atualizado Em'
    ]

    CSV.generate(headers: true, col_sep: ',', encoding: 'UTF-8') do |csv|
      csv << headers
      deals.each do |deal|
        csv << [
          deal.id,
          csv_value(deal.title),
          csv_value(deal.status),
          csv_value(deal.legal_area),
          csv_value(deal.case_type),
          csv_value(deal.urgency_level),
          deal.score_total,
          csv_value(deal.score_classification),
          (deal.value_estimate_cents.to_f / 100).round(2),
          deal.probability_pct,
          csv_value(deal.crm_pipeline_stage&.name),
          csv_value(deal.lgpd_basis),
          csv_value(deal.consent_status),
          csv_value(deal.consent_channel),
          deal.consent_collected_at&.iso8601,
          deal.data_retention_until&.iso8601,
          csv_value(deal.summary),
          csv_value(deal.next_best_action),
          deal.contact_id,
          deal.conversation_id,
          csv_value(deal.crm_loss_reason&.name),
          deal.created_at.iso8601,
          deal.updated_at.iso8601
        ]
      end
    end
  end

  def csv_value(text)
    return '' if text.blank?

    # Remove line breaks that would break CSV rows
    sanitized = text.to_s.gsub(/[\r\n]+/, ' ').strip
    # Neutraliza fórmulas: células começando com = + - @ ou tab executam ao
    # abrir o CSV no Excel/LibreOffice (formula injection).
    sanitized.sub(/\A(?=[=+\-@\t])/, "'")
  end
end
