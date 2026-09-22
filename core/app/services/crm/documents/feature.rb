# Liga/desliga o cofre por conta. Fica em `accounts.settings['crm_documents']`
# e não em config/features.yml porque o bitmask de feature_flags já está no
# limite de 63 bits (DECISOES.md, ADR-DOC, D15).
module Crm::Documents::Feature
  SETTING_KEY = 'crm_documents'.freeze

  module_function

  def enabled?(account)
    return false if account.nil?

    ActiveModel::Type::Boolean.new.cast(account.settings&.dig(SETTING_KEY)) == true
  end

  # `preset`: modelo de documentos da conta (geral, legal, clinic,
  # real_estate, education). Sem ele, vale o do pack instalado ou o geral.
  def enable!(account, preset: nil)
    update!(account, true)
    Crm::Documents::Defaults.ensure!(account, preset: preset)
  end

  def disable!(account)
    update!(account, false)
  end

  def update!(account, value)
    account.update!(settings: (account.settings || {}).merge(SETTING_KEY => value))
  end
end
