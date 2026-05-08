json.payload do
  json.array! @captain_inboxes do |captain_inbox|
    json.partial! 'api/v1/accounts/captain/inboxes/captain_inbox', formats: [:json], captain_inbox: captain_inbox
  end
end

json.meta do
  json.total_count @captain_inboxes.count
  json.page 1
end
