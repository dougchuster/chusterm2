# Configurações do cofre da conta: modelo de documentos por área, padrões de
# nome e captura. Ler: quem usa o cofre. Alterar: administrador.
class Api::V1::Accounts::Crm::DocumentSettingsController < Api::V1::Accounts::Crm::DocumentsBaseController
  def show
    authorize CrmDocument, :index?
    render json: payload
  end

  def update
    authorize CrmDocument, :manage?
    return render_unprocessable('Modelo de documentos desconhecido.') if unknown_preset?

    settings = Crm::Documents::Defaults.settings_for(Current.account)
    apply_preset(settings)
    settings.update!(update_params)
    audit('document_settings_updated', settings, changes: settings.saved_changes.except('updated_at'))
    render json: payload
  rescue ActiveRecord::RecordInvalid => e
    render_unprocessable(e.record.errors.full_messages.to_sentence)
  end

  private

  def unknown_preset?
    params[:preset].present? && Crm::Documents::Defaults.preset_slugs.exclude?(params[:preset].to_s)
  end

  # Trocar de modelo acrescenta os tipos e troca os modelos de pasta; pastas e
  # documentos que já existem não mudam.
  def apply_preset(settings)
    preset = params[:preset].to_s
    return if preset.blank? || preset == settings.preset

    Crm::Documents::Defaults.apply_preset!(Current.account, preset)
    settings.reload
  end

  def update_params
    attributes = params.permit(:capture_outgoing).to_h
    attributes[:naming] = params[:naming].permit(*CrmDocumentSetting::NAMING_KEYS).to_h.compact_blank if params[:naming].respond_to?(:permit)
    attributes
  end

  def payload
    settings = Crm::Documents::Defaults.settings_for(Current.account)
    {
      preset: settings.preset, presets: Crm::Documents::Defaults.presets,
      naming: settings.naming, effective_naming: settings.effective_naming,
      default_naming: Crm::Documents::Defaults.preset_config(settings.preset)['naming'],
      naming_tokens: Crm::Documents::Naming::Template::SPECS.transform_values { |spec| spec[:allowed] },
      capture_outgoing: settings.capture_outgoing
    }
  end
end
