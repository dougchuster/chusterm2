# Catálogo de tools do MCP server (5.4 do PLANO_17_09.md) — só os schemas.
# Os handlers moram em Crm::McpHandlers e rodam com `instance_exec` dentro
# do Crm::McpServer, então enxergam @account/@actor e os helpers privados.
module Crm::McpTools
  ToolError = Class.new(StandardError)

  TOOLS = [
    {
      name: 'deals.search',
      description: 'Search CRM deals in the current account',
      inputSchema: {
        type: 'object',
        properties: {
          q: { type: 'string', description: 'Title, contact name, email or phone' },
          status: { type: 'string', enum: %w[open won lost archived] },
          operational_status: { type: 'string',
                                description: 'active, returning_client, base_client, invalid, spam, duplicated, no_lead, archived' },
          stage_id: { type: 'integer' },
          owner_id: { type: 'integer' },
          limit: { type: 'integer', maximum: 50, default: 20 }
        }
      }
    },
    {
      name: 'deals.move',
      description: 'Move a deal to another pipeline stage',
      inputSchema: {
        type: 'object',
        properties: {
          deal_id: { type: 'integer' },
          stage_id: { type: 'integer' }
        },
        required: %w[deal_id stage_id]
      }
    },
    {
      name: 'activities.create',
      description: 'Create an activity (task, call, follow-up) linked to a deal',
      inputSchema: {
        type: 'object',
        properties: {
          deal_id: { type: 'integer' },
          title: { type: 'string' },
          kind: { type: 'string', default: 'follow_up' },
          due_at: { type: 'string', format: 'date-time' },
          description: { type: 'string' }
        },
        required: %w[deal_id title]
      }
    },
    {
      name: 'contacts.timeline',
      description: 'Timeline of a contact: deals, activities and conversations',
      inputSchema: {
        type: 'object',
        properties: {
          contact_id: { type: 'integer' },
          limit: { type: 'integer', maximum: 50, default: 20 }
        },
        required: %w[contact_id]
      }
    },
    {
      name: 'fields.list',
      description: 'List the CRM custom field definitions available in this account',
      inputSchema: { type: 'object', properties: {} }
    }
  ].freeze
end
