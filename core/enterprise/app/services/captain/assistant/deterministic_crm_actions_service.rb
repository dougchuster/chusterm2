class Captain::Assistant::DeterministicCrmActionsService
  def initialize(assistant:, conversation:, response:)
    @assistant = assistant
    @conversation = conversation
    @response = response
  end

  def perform
    return @response unless @conversation

    sync_triage_from_conversation
    @response
  end

  private

  def sync_triage_from_conversation
    return unless defined?(Crm::TriageFromConversation)
    return unless @conversation.account.crm_pipelines.active.exists?

    deal = Crm::TriageFromConversation.new(
      conversation: @conversation,
      account: @conversation.account,
      actor: nil
    ).perform

    sync_captain_state_score(deal)
  rescue StandardError => e
    Rails.logger.warn "[Captain V2] Deterministic CRM sync failed: #{e.class} - #{e.message}"
    ::ChusteRMExceptionTracker.new(e, account: @conversation&.account).capture_exception
  end

  def sync_captain_state_score(deal)
    state = @conversation.account.captain_conversation_states.find_by(conversation: @conversation)
    return unless state && deal

    updates = {}
    updates[:crm_deal_id] = deal.id if state.crm_deal_id != deal.id
    updates[:score_total] = deal.score_total if state.score_total.to_i != deal.score_total.to_i
    state.update!(updates) if updates.any?
  end
end
