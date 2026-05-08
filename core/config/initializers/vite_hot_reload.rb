# Recarrega o manifesto do Vite a cada request em modo hot-reload.
# Necessário quando core-vite rebuilda ativos em background (volume compartilhado)
# e o Rails em produção precisa servir os arquivos atualizados sem restart.
#
# Ativar: VITE_HOT_RELOAD=true (definido no docker-compose.yml no serviço core)
if ENV['VITE_HOT_RELOAD'] == 'true'
  class ViteManifestReloader
    def initialize(app)
      @app = app
    end

    def call(env)
      ViteRuby.instance.manifest.refresh rescue nil
      @app.call(env)
    end
  end

  Rails.application.config.middleware.insert_before 0, ViteManifestReloader
end
