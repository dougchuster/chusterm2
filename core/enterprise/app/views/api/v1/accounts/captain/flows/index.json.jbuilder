json.payload do
  json.array! @flows do |flow|
    json.partial! 'api/v1/models/captain/flow', flow: flow
  end
end

json.meta do
  json.total_count @flows.count
end
