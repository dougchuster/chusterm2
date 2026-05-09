# frozen_string_literal: true

# Stub no-op para versão órfã em schema_migrations herdada de uma imagem
# anterior do Chatwoot que continha esta migration. Aplicar este arquivo
# não muda nada no banco — o schema correspondente já foi aplicado quando
# a versão original rodou. Vide docs/system-audit-report.md (NEW-01).
class LegacyUpstreamStub20260406000005 < ActiveRecord::Migration[7.1]
  def change; end
end
