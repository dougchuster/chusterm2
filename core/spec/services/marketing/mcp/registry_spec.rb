require 'rails_helper'

RSpec.describe Marketing::Mcp::Registry do
  let(:account) { create(:account) }
  let(:registry) { described_class.new(account: account) }

  it 'retorna vazio sem configuracao' do
    expect(registry.server_configs).to be_empty
  end

  it 'le servers do metadata das conexoes ativas' do
    account.crm_external_connections.create!(
      provider: 'meta_ads', status: 'active', access_token: 't',
      metadata: {
        'mcp_servers' => [
          { 'name' => 'meta-ads', 'transport' => 'streamable_http', 'url' => 'http://mcp-meta:8080/mcp' }
        ]
      }
    )

    configs = registry.server_configs
    expect(configs.size).to eq(1)
    expect(configs.first.name).to eq('meta-ads')
    expect(configs.first.transport).to eq('streamable_http')
  end

  it 'le servers da env MARKETING_MCP_SERVERS' do
    with_modified_env MARKETING_MCP_SERVERS: '[{"name":"ga4","url":"https://analyticsdata.googleapis.com/mcp/v1"}]' do
      expect(registry.server_configs.map(&:name)).to eq(['ga4'])
    end
  end

  it 'ignora env JSON invalido' do
    with_modified_env MARKETING_MCP_SERVERS: '{not json' do
      expect(registry.server_configs).to be_empty
    end
  end

  it 'with_clients devolve lista vazia sem servers' do
    registry.with_clients do |tools|
      expect(tools).to eq([])
    end
  end
end
