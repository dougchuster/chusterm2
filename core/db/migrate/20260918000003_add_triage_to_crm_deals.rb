class AddTriageToCrmDeals < ActiveRecord::Migration[7.1]
  def change
    # 3.2: resultado cru do classificador (LLM ou regras) — inspecionável na
    # ficha do deal ("IA classificou como X (motivo)") e auditável.
    add_column :crm_deals, :triage, :jsonb, default: {}
  end
end
