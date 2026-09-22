# Cofre de documentos (PROJETO-COFRE-DOCUMENTOS.md). Tarefas de operação.
namespace :crm do
  namespace :documents do
    desc 'Captura para o cofre os anexos já existentes. Uso: rake "crm:documents:backfill[ACCOUNT_ID,2026-01-01]"'
    task :backfill, [:account_id, :since] => :environment do |_task, args|
      account = Account.find(args.fetch(:account_id))
      abort "Cofre desligado na conta #{account.id}. Ligue com Crm::Documents::Feature.enable!." unless
        Crm::Documents::Feature.enabled?(account)

      since = args[:since].present? ? Date.parse(args[:since]) : nil
      started = Time.current
      report = Crm::Documents::Backfill.new(account: account, since: since).call
      puts "Conta #{account.id}: #{report.scanned} anexos vistos, #{report.created} documentos criados, " \
           "#{report.skipped} já existiam ou foram ignorados (#{(Time.current - started).round}s)."
    end
  end
end
