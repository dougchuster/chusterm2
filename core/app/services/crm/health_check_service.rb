module Crm
  class HealthCheckService
    MEDIA_STALE_AFTER = 10.minutes
    HOT_LEAD_SCORE = 60

    def initialize(account:)
      @account = account
    end

    def perform
      {
        account_id: @account.id,
        generated_at: Time.current.iso8601,
        contacts: contacts_summary,
        deals: deals_summary,
        labels: labels_summary,
        media: media_summary,
        activities: activities_summary,
        captain: captain_summary,
        status: overall_status
      }
    end

    private

    def contacts_summary
      scope = @account.contacts
      {
        total: scope.count,
        missing_relationship_status: missing_contact_field_count(scope, :relationship_status),
        missing_lifecycle_stage: missing_contact_field_count(scope, :lifecycle_stage),
        with_crm_owner: scope.where.not(crm_owner_id: nil).count,
        without_crm_owner: scope.where(crm_owner_id: nil).count
      }
    end

    def deals_summary
      scope = @account.crm_deals.open_deals
      {
        open: scope.count,
        without_owner: scope.where(owner_id: nil).count,
        hot_leads_without_owner: hot_leads_without_owner(scope).count,
        without_conversation: scope.where(conversation_id: nil).count
      }
    end

    def labels_summary
      scope = @account.labels
      system_labels = scope.where(is_system: true)
      {
        total: scope.count,
        crm_system: system_labels.count,
        missing_category: scope.where(category: [nil, '']).count,
        missing_slug: scope.where(slug: [nil, '']).count,
        system_visible_on_sidebar: system_labels.where(show_on_sidebar: true).count
      }
    end

    def media_summary
      attachments = Attachment.joins(:message).where(messages: { account_id: @account.id })
      stale_processing = attachments.where("attachments.meta->>'media_understanding_status' = ?", 'processing')
                                    .where('attachments.updated_at < ?', MEDIA_STALE_AFTER.ago)
      {
        audio_with_transcription: attachments.where(file_type: :audio).where("attachments.meta->>'transcribed_text' IS NOT NULL").count,
        media_with_understanding: attachments.where(file_type: %i[image file])
                                             .where("attachments.meta->>'media_understanding_status' IN (?)", %w[completed failed])
                                             .count,
        stale_processing: stale_processing.count
      }
    end

    def activities_summary
      scope = @account.crm_activities
      {
        pending: scope.pending.count,
        overdue: scope.overdue.count,
        due_today: scope.due_today.count
      }
    end

    def captain_summary
      assistants = @account.captain_assistants
      states = CaptainConversationState.where(account_id: @account.id)
      {
        assistants: assistants.count,
        inboxes: CaptainInbox.joins(:inbox).where(inboxes: { account_id: @account.id }).count,
        conversations_with_state: states.count,
        human_controlled: states.where(ai_mode: CaptainConversationState::HUMAN_MODES).count,
        linked_to_deal: states.where.not(crm_deal_id: nil).count
      }
    end

    def overall_status
      return 'attention' if critical_counts.any? { |_key, value| value.to_i.positive? }

      'ok'
    end

    def critical_counts
      {
        hot_leads_without_owner: deals_summary[:hot_leads_without_owner],
        system_visible_on_sidebar: labels_summary[:system_visible_on_sidebar],
        stale_processing_media: media_summary[:stale_processing]
      }
    end

    def missing_contact_field_count(scope, field)
      return 0 unless Contact.column_names.include?(field.to_s)

      scope.where(field => [nil, '']).count
    end

    def hot_leads_without_owner(scope)
      scope
        .left_joins(:contact)
        .where('crm_deals.score_total >= ?', HOT_LEAD_SCORE)
        .where(owner_id: nil)
        .where(contacts: { crm_owner_id: nil })
    end
  end
end
