class Api::V1::Accounts::Crm::LossReasonsController < Api::V1::Accounts::Crm::BaseController
  before_action :loss_reason, only: [:update]

  def index
    authorize CrmLossReason, :index?

    @loss_reasons = Current.account.crm_loss_reasons.active.ordered
    render json: @loss_reasons.map { |r| { id: r.id, name: r.name, slug: r.slug, legal_area: r.legal_area, position: r.position } }
  end

  def create
    authorize CrmLossReason, :create?

    @loss_reason = Current.account.crm_loss_reasons.create!(loss_reason_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'loss_reason_created',
      target: @loss_reason
    )
    render json: { id: @loss_reason.id, name: @loss_reason.name, slug: @loss_reason.slug }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    authorize @loss_reason, :update?

    @loss_reason.update!(loss_reason_params)
    Crm::AuditLogger.log(
      account: Current.account,
      actor: Current.user,
      action: 'loss_reason_updated',
      target: @loss_reason,
      payload: { changes: audited_changes(@loss_reason, loss_reason_params.keys) }
    )
    render json: { id: @loss_reason.id, name: @loss_reason.name, slug: @loss_reason.slug }
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def loss_reason
    @loss_reason = Current.account.crm_loss_reasons.find(params[:id])
  end

  def loss_reason_params
    params.permit(:name, :slug, :legal_area, :position)
  end

  def audited_changes(record, keys)
    keys.map(&:to_s).each_with_object({}) do |key, changes|
      next unless record.saved_changes.key?(key)

      changes[key] = {
        from: record.saved_changes[key].first,
        to: record.saved_changes[key].last
      }
    end
  end
end
