# "X de Y" de documentos de um negócio (PROJETO-COFRE-DOCUMENTOS.md §8.6):
# GET com deal_id; PATCH escolhe o checklist (template_id) ou marca um item
# entregue em papel (mark: { key, done }).
class Api::V1::Accounts::Crm::DocumentChecklistsController < Api::V1::Accounts::Crm::DocumentsBaseController
  before_action :load_deal

  def show
    authorize CrmDocument, :index?
    render json: Crm::Documents::Checklist.new(@deal).call
  end

  def update
    authorize CrmDocument, :update?
    checklist = Crm::Documents::Checklist.new(@deal)
    apply_change(checklist)
    audit('document_checklist_updated', @deal, params.permit(:template_id, mark: [:key, :done]).to_h)
    render json: Crm::Documents::Checklist.new(@deal.reload).call
  end

  private

  def load_deal
    @deal = CrmDeal.visible_to(Current.user, Current.account).where(account_id: Current.account.id)
                   .find(params.require(:deal_id))
    raise ActiveRecord::RecordNotFound unless documents_access.contact_visible?(@deal.contact)
  end

  def apply_change(checklist)
    checklist.choose_template!(params[:template_id]) if params.key?(:template_id)
    return unless params[:mark].is_a?(ActionController::Parameters)

    checklist.mark!(params[:mark].require(:key), done: ActiveModel::Type::Boolean.new.cast(params[:mark][:done]))
  end
end
