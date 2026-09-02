# UX-05: listas de domínio (áreas, origens, urgências, motivos de descarte)
# servidas pelo backend — o front não hardcoda mais essas listas.
class Api::V1::Accounts::Crm::OptionsController < Api::V1::Accounts::Crm::BaseController
  def index
    render json: Crm::DomainOptions.payload
  end
end
