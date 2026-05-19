# frozen_string_literal: true

require 'net/http'
require 'json'

class EvoManagerController < ActionController::Base
  protect_from_forgery with: :exception
  layout false

  def login
    # Renderiza o formulário customizado (sem parâmetros — página pura)
  end

  def authenticate
    unless valid_super_admin?
      flash[:error] = 'Credenciais inválidas. Tente novamente.'
      return redirect_to '/manager/login'
    end

    info = fetch_evolution_info
    if info.nil?
      flash[:error] = 'Erro ao conectar com Evolution API. Contate o administrador.'
      return redirect_to '/manager/login'
    end

    @evo_api_url     = evolution_public_url
    @evo_token       = evolution_api_key
    @evo_version     = info['version']    || '2.3.0'
    @evo_client      = info['clientName'] || 'evolution_api'
    @evo_manager_url = evolution_public_url
    render :bridge
  end

  private

  def valid_super_admin?
    super_admin = SuperAdmin.find_by(email: params[:email]&.strip&.downcase)
    super_admin&.valid_password?(params[:password])
  rescue StandardError => e
    Rails.logger.error "[EvoManager] Auth error: #{e.message}"
    false
  end

  def fetch_evolution_info
    uri  = URI("#{evolution_api_internal_url}/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = uri.scheme == 'https'
    http.open_timeout = 5
    http.read_timeout = 5
    JSON.parse(http.get(uri.path).body)
  rescue StandardError => e
    Rails.logger.error "[EvoManager] Could not fetch Evolution API info: #{e.message}"
    nil
  end

  def evolution_api_internal_url
    ENV.fetch('EVOLUTION_API_URL', 'http://localhost:8085').chomp('/')
  end

  def evolution_public_url
    ENV.fetch('EVOLUTION_SERVER_URL', 'http://localhost:8085').chomp('/')
  end

  def evolution_api_key
    ENV.fetch('EVOLUTION_API_KEY', '')
  end
end
