class Api::V1::Accounts::Crm::MetricsController < Api::V1::Accounts::Crm::BaseController
  CACHE_TTL = 5.minutes

  def overview
    render json: cached('overview', params[:period_days]) do
      metrics_service.overview(period_days: params[:period_days]&.to_i || 30)
    end
  end

  def stage_funnel
    render json: cached('stage_funnel', params[:pipeline_id]) do
      metrics_service.stage_funnel(pipeline_id: params[:pipeline_id])
    end
  end

  def time_in_stage
    render json: cached('time_in_stage', params[:pipeline_id], params[:period_days]) do
      metrics_service.time_in_stage(
        pipeline_id: params[:pipeline_id],
        period_days: params[:period_days]&.to_i || 90
      )
    end
  end

  def win_loss_trend
    render json: cached('win_loss_trend', params[:months]) do
      metrics_service.win_loss_trend(months: params[:months]&.to_i || 6)
    end
  end

  def top_loss_reasons
    render json: cached('top_loss_reasons', params[:limit]) do
      metrics_service.top_loss_reasons(limit: params[:limit]&.to_i || 10)
    end
  end

  def score_by_stage
    render json: cached('score_by_stage', params[:pipeline_id]) do
      metrics_service.score_by_stage(pipeline_id: params[:pipeline_id])
    end
  end

  def area_distribution
    render json: cached('area_distribution') { metrics_service.area_distribution }
  end

  def top_deals
    render json: cached('top_deals', params[:limit]) do
      metrics_service.top_deals(limit: params[:limit]&.to_i || 10)
    end
  end

  def stale_deals
    render json: cached('stale_deals', params[:days], params[:limit]) do
      metrics_service.stale_deals(
        days: params[:days]&.to_i || 7,
        limit: params[:limit]&.to_i || 20
      )
    end
  end

  private

  def cached(*keys, &block)
    cache_key = "crm_metrics/account_#{Current.account.id}/#{keys.join('_')}"
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL, &block)
  end

  def metrics_service
    @metrics_service ||= Crm::MetricsService.new(Current.account)
  end
end
