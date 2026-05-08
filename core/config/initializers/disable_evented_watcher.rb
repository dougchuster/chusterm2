# Substitui o EventedFileUpdateChecker (que requer a gem `listen`, ausente
# no bundle de produção) pelo FileUpdateChecker baseado em polling.
# Necessário para rodar RAILS_ENV=development na imagem Docker sem instalar
# as gems do grupo :development.
if Rails.env.development?
  Rails.application.config.file_watcher = ActiveSupport::FileUpdateChecker
end
