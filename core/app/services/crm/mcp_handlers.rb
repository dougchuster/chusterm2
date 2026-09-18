# Handlers das tools MCP (5.4 do PLANO_17_09.md).
# Cada lambda roda com `instance_exec` dentro do Crm::McpServer, então
# enxerga @account/@actor e os helpers privados dele (serialize_deal,
# limit_param). Toda query sai escopada pela conta — ids de outra conta
# simplesmente não resolvem.
module Crm::McpHandlers
  ToolError = Crm::McpTools::ToolError

  HANDLERS = {
    'deals.search' => lambda do |args|
      filters = Crm::DealFilterService.permitted_filters(
        args.slice(*Crm::DealFilterService::SCALAR_KEYS, *Crm::DealFilterService::LIST_KEYS, :custom_fields)
      )
      deals = Crm::DealFilterService.new(scope: @account.crm_deals, filters: filters, account: @account)
                                    .perform
                                    .order(updated_at: :desc)
                                    .limit(limit_param(args))
      { deals: deals.map { |deal| serialize_deal(deal) }, count: deals.size }
    end,
    'deals.move' => lambda do |args|
      deal = @account.crm_deals.find_by(id: args[:deal_id])
      raise ToolError, 'Deal not found' unless deal

      stage = @account.crm_pipeline_stages.find_by(id: args[:stage_id])
      raise ToolError, 'Stage not found' unless stage

      Crm::DealMover.new(deal: deal, stage_id: stage.id, actor: @actor).perform
      { deal: serialize_deal(deal.reload) }
    end,
    'activities.create' => lambda do |args|
      deal = @account.crm_deals.find_by(id: args[:deal_id])
      raise ToolError, 'Deal not found' unless deal

      activity = @account.crm_activities.create!(
        crm_deal: deal,
        contact: deal.contact,
        conversation: deal.conversation,
        title: args[:title].to_s,
        kind: args[:kind].presence || 'follow_up',
        due_at: args[:due_at].presence,
        description: args[:description].presence,
        owner: @actor.is_a?(User) ? @actor : nil
      )
      Crm::AuditLogger.log(account: @account, actor: @actor, action: 'activity_created', target: activity)
      { activity: { id: activity.id, title: activity.title, kind: activity.kind, due_at: activity.due_at } }
    end,
    'contacts.timeline' => lambda do |args|
      contact = @account.contacts.find_by(id: args[:contact_id])
      raise ToolError, 'Contact not found' unless contact

      limit = limit_param(args)
      {
        contact: { id: contact.id, name: contact.name, email: contact.email, phone_number: contact.phone_number },
        deals: contact.crm_deals.order(updated_at: :desc).limit(limit).map { |deal| serialize_deal(deal) },
        activities: @account.crm_activities.where(contact: contact).order(created_at: :desc).limit(limit)
                            .map { |a| { id: a.id, title: a.title, kind: a.kind, created_at: a.created_at } },
        conversations: contact.conversations.order(last_activity_at: :desc).limit(limit)
                              .map { |c| { id: c.id, display_id: c.display_id, status: c.status, last_activity_at: c.last_activity_at } }
      }
    end,
    'fields.list' => lambda do |_args|
      {
        field_definitions: @account.crm_field_definitions.active.for_deals.map do |field|
          { key: field.key, label: field.label, field_type: field.field_type, options: field.options }
        end
      }
    end
  }.freeze
end
