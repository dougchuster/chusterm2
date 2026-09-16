# Cleans up artifacts produced by the pending-conversation auto-resolve sweep:
#   1. "Revisão recomendada" private notes (the yellow cards)
#   2. Failed outgoing messages sent by Captain assistants (template errors)
#   3. Pending conversations → real human handoff (bot_handoff!)
#   4. score_payload review/evaluation flags
#
# Deletions are not reversible — run with dry_run: true first and take a DB
# backup before applying changes.
# rubocop:disable Rails/Output -- operator-facing CLI report, stdout is correct
class Captain::PendingSweepCleanup
  REVIEW_NOTE_PREFIX = 'Revisão recomendada%'.freeze
  REVIEW_PAYLOAD_KEYS = %w[review_recommended review_reason automatic_handoff last_evaluated_at].freeze

  pattr_initialize [:account!, { inbox_id: nil, since: nil, dry_run: true }]

  def perform
    report
    return if dry_run

    apply
  end

  private

  delegate :conversations, :account_id, to: :account

  def messages
    scope = Message.where(account_id: account.id)
    scope = scope.where(inbox_id: inbox_id) if inbox_id
    scope = scope.where('messages.created_at >= ?', since) if since
    scope
  end

  def scoped_conversations
    scope = conversations
    scope = scope.where(inbox_id: inbox_id) if inbox_id
    scope
  end

  def review_notes
    messages.where(private: true).where('content LIKE ?', REVIEW_NOTE_PREFIX)
  end

  # content_attributes is double-serialized in this install (a JSON string inside
  # the json column), so match on the raw text — that covers both encodings.
  # Scoped to Captain senders: failures on human agent messages stay visible.
  def failed_outgoing
    messages.where(message_type: :outgoing, status: :failed, sender_type: 'Captain::Assistant')
            .where('content_attributes::text LIKE ?', '%external_error%')
  end

  def pending_conversations
    scoped_conversations.pending
  end

  def flagged_states
    CaptainConversationState.where(conversation_id: scoped_conversations.select(:id))
                            .where('score_payload ?| array[:keys]', keys: REVIEW_PAYLOAD_KEYS)
  end

  def report
    scope_label = inbox_id ? ", inbox #{inbox_id}" : ''
    scope_label += ", since #{since.to_date}" if since
    puts "== captain:cleanup_pending_sweep (account #{account.id}#{scope_label}) =="
    puts "review notes:        #{review_notes.count}"
    puts "failed outgoing:     #{failed_outgoing.count}"
    puts "pending→handoff:     #{pending_conversations.count}"
    puts "flagged states:      #{flagged_states.count}"
    puts dry_run ? 'DRY_RUN — nothing changed. Re-run with DRY_RUN=false after a DB backup.' : 'APPLYING CHANGES…'
  end

  def apply
    review_notes.find_each(&:destroy!)
    failed_outgoing.find_each(&:destroy!)

    handed_off = 0
    pending_conversations.find_each do |conversation|
      conversation.bot_handoff!
      handed_off += 1
    rescue StandardError => e
      puts "  ! conversation #{conversation.id}: #{e.class} #{e.message}"
    end

    flagged_states.find_each do |state|
      state.update!(score_payload: state.score_payload.to_h.except(*REVIEW_PAYLOAD_KEYS))
    end

    puts "Done — #{handed_off} conversations handed off."
  end
end
# rubocop:enable Rails/Output
