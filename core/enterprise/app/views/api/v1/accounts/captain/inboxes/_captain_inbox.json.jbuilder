json.partial! 'api/v1/models/inbox', formats: [:json], resource: captain_inbox.inbox

json.captain_inbox do
  json.id captain_inbox.id
  json.captain_assistant_id captain_inbox.captain_assistant_id
  json.inbox_id captain_inbox.inbox_id
  json.enabled captain_inbox.enabled
  json.auto_reply_enabled captain_inbox.auto_reply_enabled
  json.ai_mode captain_inbox.ai_mode
  json.handoff_strategy captain_inbox.handoff_strategy
  json.routing_config captain_inbox.routing_config
  json.responsible captain_inbox.responsible?
  json.active_for_auto_reply captain_inbox.active_for_auto_reply?
end
