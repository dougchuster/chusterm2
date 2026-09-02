# frozen_string_literal: true

# Repairs historical Captain state rows whose deal was reused by a newer
# conversation. New writes are protected by Crm::DealCreator and
# CaptainConversationState.for_conversation!.

scope = CaptainConversationState
        .joins(:crm_deal)
        .where.not(crm_deals: { conversation_id: nil })
        .where('captain_conversation_states.conversation_id <> crm_deals.conversation_id')

repaired = scope.update_all(crm_deal_id: nil, updated_at: Time.current)
remaining = scope.count

raise "STALE_CRM_LINK_REPAIR_FAILED remaining=#{remaining}" unless remaining.zero?

puts "STALE_CRM_LINKS_REPAIRED=#{repaired}"
