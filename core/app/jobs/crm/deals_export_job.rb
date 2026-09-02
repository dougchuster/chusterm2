# PERF-04: export de deals em background (padrão do Account::ContactsExportJob):
# gera o CSV fora do request, anexa em Active Storage e envia o link por email.
class Crm::DealsExportJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_id, filters = {})
    @account = Account.find(account_id)
    @user = @account.users.find(user_id)

    deals = Crm::DealFilterService.new(scope: @account.crm_deals, filters: filters).perform
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
    file_url = Rails.application.routes.url_helpers.rails_blob_url(@account.crm_deals_export)
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
          deal.status,
          deal.legal_area,
          deal.case_type,
          deal.urgency_level,
          deal.score_total,
          deal.score_classification,
          (deal.value_estimate_cents.to_f / 100).round(2),
          deal.probability_pct,
          deal.crm_pipeline_stage&.name,
          deal.lgpd_basis,
          deal.consent_status,
          deal.consent_channel,
          deal.consent_collected_at&.iso8601,
          deal.data_retention_until&.iso8601,
          csv_value(deal.summary),
          csv_value(deal.next_best_action),
          deal.contact_id,
          deal.conversation_id,
          deal.crm_loss_reason&.name,
          deal.created_at.iso8601,
          deal.updated_at.iso8601
        ]
      end
    end
  end

  def csv_value(text)
    return '' if text.blank?

    # Remove line breaks that would break CSV rows
    text.to_s.gsub(/[\r\n]+/, ' ').strip
  end
end
