json.thread do
  json.partial! 'api/v1/models/captain/copilot_thread', formats: [:json], resource: @copilot_thread
end

json.first_message do
  first_message = @copilot_thread.copilot_messages.order(created_at: :asc).first
  if first_message
    json.partial! 'api/v1/models/captain/copilot_message', formats: [:json], resource: first_message
  else
    json.nil!
  end
end
