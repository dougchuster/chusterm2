json.partial! 'api/v1/models/captain/flow', flow: flow
json.nodes flow.flow_nodes do |node|
  json.id node.id
  json.node_id node.node_id
  json.node_type node.node_type
  json.position_x node.position_x
  json.position_y node.position_y
  json.config node.config
end
json.edges flow.flow_edges do |edge|
  json.id edge.id
  json.edge_id edge.edge_id
  json.source_node_id edge.source_node_id
  json.target_node_id edge.target_node_id
  json.label edge.label
  json.condition edge.condition
end
