# Página pública do formulário de envio (PROJETO-COFRE-DOCUMENTOS.md §8.7).
#
#   /f/:token  formulário aberto da conta (link fixo, divulgado pela conta)
#   /l/:token  link personalizado de um cliente ("o que falta")
#
# HTML renderizado no servidor, que funciona sem JavaScript (celular simples);
# o JS só mostra/esconde campos condicionais e reduz fotos antes do envio.
# Defesas: CSRF, campo-isca, tempo mínimo de preenchimento, rack-attack por IP,
# nenhum dado do cliente exibido no formulário aberto, 404 genérico.
class PublicDocumentFormsController < ActionController::Base
  MIN_FILL_SECONDS = 3
  STARTED_AT_PURPOSE = :crm_document_form

  protect_from_forgery with: :exception
  layout 'public_document_form'

  before_action :load_form
  after_action :harden_headers

  def show
    @started_at = verifier.generate(Time.current.to_i, purpose: STARTED_AT_PURPOSE, expires_in: 12.hours)
    register_link_access
  end

  def submit
    started = verifier.verified(params[:started_at].to_s, purpose: STARTED_AT_PURPOSE)
    return render_expired if started.nil?
    return render_success(nil) if bot?(started)

    result = Crm::Documents::FormSubmitter.new(
      form: @form, link: @link, answers: answers_params, files: files_params, consent: params[:consent],
      ip: request.remote_ip, user_agent: request.user_agent
    ).call
    result.success? ? render_success(result) : render_errors(result)
  end

  private

  def load_form
    @link = CrmDocumentFormLink.find_usable(params[:token]) if params[:link]
    @form = @link ? @link.crm_document_form : CrmDocumentForm.published.find_by(public_token: params[:token].to_s)
    return render_not_found if @form.nil? || !Crm::Documents::Feature.enabled?(@form.account)

    @fields = Crm::Documents::FormAnswers.fields_for(@form, skip_mapped: @link.present?)
    @items = Array(@form.document_items).map { |item| item.to_h.stringify_keys }
  end

  def register_link_access
    return if @link.nil?

    @link.update_columns(access_count: @link.access_count + 1, last_access_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  # Robô: campo-isca preenchido ou envio rápido demais. Responde como se tivesse
  # dado certo, para não ensinar o que foi detectado.
  def bot?(started)
    params[:website].present? || Time.current.to_i - started.to_i < MIN_FILL_SECONDS
  end

  def answers_params
    raw = params[:answers]
    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h.slice(*@fields.pluck('key')) : {}
  end

  def files_params
    raw = params[:files]
    return {} unless raw.respond_to?(:to_unsafe_h)

    raw.to_unsafe_h.slice(*@items.pluck('key')).transform_values do |list|
      Array(list).grep(ActionDispatch::Http::UploadedFile)
    end
  end

  def render_success(result)
    @submission = result&.submission
    @rejected = result&.rejected || []
    render :success
  end

  def render_errors(result)
    @errors = result.errors
    @answers = answers_params
    @started_at = params[:started_at]
    render :show, status: :unprocessable_entity
  end

  def render_expired
    @errors = { 'form' => 'A página ficou aberta por muito tempo. Confira os dados e envie de novo.' }
    @answers = answers_params
    @started_at = verifier.generate(Time.current.to_i, purpose: STARTED_AT_PURPOSE, expires_in: 12.hours)
    render :show, status: :unprocessable_entity
  end

  def render_not_found
    render :not_found, status: :not_found
  end

  def verifier
    Rails.application.message_verifier(STARTED_AT_PURPOSE)
  end

  def harden_headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['Referrer-Policy'] = 'no-referrer'
    response.headers['X-Robots-Tag'] = 'noindex, nofollow'
    response.headers['Cache-Control'] = 'no-store'
  end
end
