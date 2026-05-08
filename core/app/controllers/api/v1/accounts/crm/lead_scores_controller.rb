class Api::V1::Accounts::Crm::LeadScoresController < Api::V1::Accounts::Crm::BaseController
  def recompute
    deal = Current.account.crm_deals.find(params[:deal_id])
    authorize deal, :update?

    score = Crm::LeadScoreCalculator.new(deal, actor: Current.user).perform
    Crm::AuditLogger.log(account: Current.account, actor: Current.user, action: 'score_recomputed', target: deal)
    render json: {
      total_score: score.total_score,
      classification: score.classification,
      reason: score.reason,
      factors: score.factors,
      crm_pipeline_stage_id: deal.reload.crm_pipeline_stage_id
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Deal not found' }, status: :not_found
  end
end
