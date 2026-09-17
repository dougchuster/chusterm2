# Fase 2 (A0): packs de vertical da conta. `index` lista packs disponíveis e
# instalados; `create` instala. Só existe no modo universal — com a flag off
# responde 404 e a conta legada nem enxerga o recurso.
class Api::V1::Accounts::Crm::PacksController < Api::V1::Accounts::Crm::BaseController
  before_action :check_universal_flag
  before_action :check_admin!, only: [:create]

  def index
    installed = Current.account.crm_account_packs.pluck(:slug, :installed_at).to_h
    render json: { packs: Crm::Pack.all.map { |pack| serialize_pack(pack, installed) } }
  end

  def create
    pack = Crm::PackInstaller.new(Current.account).install(params[:slug].to_s)
    render json: { slug: pack.slug, installed: true }, status: :created
  rescue Crm::Pack::UnknownPackError => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def serialize_pack(pack, installed)
    {
      slug: pack.slug,
      name: pack.name,
      version: pack.version,
      installed: installed.key?(pack.slug),
      installed_at: installed[pack.slug]&.iso8601,
      categories: pack.categories.map { |c| { value: c[:value], label: c[:label] } },
      activity_types: pack.activity_types.map { |t| { value: t[:key], label: t[:label] } },
      field_definitions: pack.field_definitions.map { |f| { key: f[:key], label: f[:label], field_type: f[:field_type] } }
    }
  end

  def check_universal_flag
    render json: { error: 'not_found' }, status: :not_found unless Current.account&.feature_enabled?('crm_universal')
  end

  def check_admin!
    head :unauthorized unless administrator?
  end
end
