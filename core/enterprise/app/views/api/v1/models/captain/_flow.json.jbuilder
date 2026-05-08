json.id flow.id
json.name flow.name
json.slug flow.slug
json.description flow.description
json.status flow.status
json.version flow.version
json.published_at flow.published_at
json.captain_assistant_id flow.captain_assistant_id
json.account_id flow.account_id
json.created_at flow.created_at
json.updated_at flow.updated_at
json.nodes_count flow.flow_nodes.size
json.edges_count flow.flow_edges.size
if flow.captain_assistant.present?
  json.assistant do
    json.id flow.captain_assistant.id
    json.name flow.captain_assistant.name
  end
end
