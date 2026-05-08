json.additional_attributes resource.additional_attributes
json.availability_status resource.availability_status
json.email resource.email
json.id resource.id
json.name resource.name
json.phone_number resource.phone_number
json.blocked resource.blocked
json.identifier resource.identifier
json.thumbnail resource.avatar_url
json.custom_attributes resource.custom_attributes
json.campaign_opt_out resource.campaign_opted_out? if resource.respond_to?(:campaign_opted_out?)
json.labels resource.label_list.to_a if resource.respond_to?(:label_list)
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
# CRM lifecycle
json.relationship_status resource.crm_relationship_status if resource.respond_to?(:crm_relationship_status)
json.lifecycle_stage resource.lifecycle_stage if resource.respond_to?(:lifecycle_stage)
json.lifecycle_stage_changed_at resource.lifecycle_stage_changed_at if resource.respond_to?(:lifecycle_stage_changed_at)
json.became_lead_at resource.became_lead_at if resource.respond_to?(:became_lead_at)
json.became_customer_at resource.became_customer_at if resource.respond_to?(:became_customer_at)
json.first_deal_won_at resource.first_deal_won_at if resource.respond_to?(:first_deal_won_at)
json.last_crm_interaction_at resource.last_crm_interaction_at if resource.respond_to?(:last_crm_interaction_at)
json.lifetime_value_cents resource.lifetime_value_cents if resource.respond_to?(:lifetime_value_cents)
json.total_deals_count resource.total_deals_count if resource.respond_to?(:total_deals_count)
json.won_deals_count resource.won_deals_count if resource.respond_to?(:won_deals_count)
if resource.respond_to?(:crm_owner_id)
  json.crm_owner_id resource.crm_owner_id
  json.crm_owner_assigned_at resource.crm_owner_assigned_at
  json.crm_owner_source resource.crm_owner_source
  if resource.crm_owner.present?
    json.crm_owner do
      json.partial! 'api/v1/models/agent', formats: [:json], resource: resource.crm_owner
    end
  end
end
# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    json.array! resource.contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end
