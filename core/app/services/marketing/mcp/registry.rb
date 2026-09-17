# Registry de MCP servers de marketing por conta.
# Servers configurados no metadata da conexao (`mcp_servers`) ou via env
# MARKETING_MCP_SERVERS (JSON). Preferir streamable_http — stdio so em dev.
class Marketing::Mcp::Registry
  ServerConfig = Struct.new(:name, :transport, :url, :command, :args, :headers, keyword_init: true)

  def initialize(account:)
    @account = account
  end

  # Lista as configuracoes ativas (sem conectar).
  def server_configs
    from_connections + from_env
  end

  # Abre clientes MCP para os servers configurados. Uso:
  #   Marketing::Mcp::Registry.new(account: acc).with_clients do |tools|
  #     chat.with_tools(*tools)
  #   end
  def with_clients
    clients = server_configs.filter_map { |cfg| build_client(cfg) }
    return yield [] if clients.empty?

    yield clients.flat_map { |client| safe_tools(client) }
  ensure
    stop_all(clients)
  end

  private

  def from_connections
    @account.crm_external_connections
            .where(provider: CrmExternalConnection::MARKETING_PROVIDERS, status: 'active')
            .flat_map { |conn| Array(conn.metadata['mcp_servers']).map { |s| to_config(s) } }
  end

  def from_env
    raw = ENV['MARKETING_MCP_SERVERS'].to_s
    return [] if raw.blank?

    Array(JSON.parse(raw)).map { |s| to_config(s) }
  rescue JSON::ParserError
    []
  end

  def to_config(hash)
    hash = hash.stringify_keys
    ServerConfig.new(
      name: hash['name'],
      transport: hash['transport'] || 'streamable_http',
      url: hash['url'],
      command: hash['command'],
      args: hash['args'],
      headers: hash['headers']
    )
  end

  def build_client(cfg)
    return if cfg.name.blank?

    options = client_options(cfg)
    return if options.nil?

    client = RubyLLM::MCP.client(**options)
    client.start
    client
  rescue StandardError => e
    Rails.logger.warn("[Marketing::Mcp] failed to start #{cfg.name}: #{e.message}")
    nil
  end

  def client_options(cfg)
    base = { name: "acct-#{@account.id}-#{cfg.name}" }
    if cfg.transport == 'stdio' && cfg.command.present?
      base.merge(transport_type: :stdio, config: { command: cfg.command, args: cfg.args || [] })
    elsif cfg.url.present?
      base.merge(transport_type: :streamable_http, config: { url: cfg.url, headers: cfg.headers || {} })
    end
  end

  def safe_tools(client)
    client.tools
  rescue StandardError => e
    Rails.logger.warn("[Marketing::Mcp] tools listing failed for #{client.name}: #{e.message}")
    []
  end

  def stop_all(clients)
    Array(clients).each do |client|
      client.stop
    rescue StandardError
      nil
    end
  end
end
