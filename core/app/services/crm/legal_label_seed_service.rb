module Crm
  class LegalLabelSeedService
    LABELS = [
      ['area_previdenciario', 'area.previdenciario', 'area', '#2563eb'],
      ['area_trabalhista', 'area.trabalhista', 'area', '#0f766e'],
      ['area_civel', 'area.civel', 'area', '#7c3aed'],
      ['area_consumidor', 'area.consumidor', 'area', '#0891b2'],
      ['area_familia', 'area.familia', 'area', '#db2777'],
      ['area_imobiliario', 'area.imobiliario', 'area', '#65a30d'],
      ['area_penal', 'area.penal', 'area', '#dc2626'],
      ['area_tributario', 'area.tributario', 'area', '#9333ea'],
      ['area_empresarial', 'area.empresarial', 'area', '#475569'],
      ['area_auxilio_maternidade', 'area.auxilio_maternidade', 'area', '#ea580c'],
      ['temp_quente', 'temp.quente', 'temperature', '#dc2626'],
      ['temp_morno', 'temp.morno', 'temperature', '#f59e0b'],
      ['temp_frio', 'temp.frio', 'temperature', '#64748b'],
      ['rel_lead', 'rel.lead', 'relationship', '#2563eb'],
      ['rel_cliente', 'rel.cliente', 'relationship', '#16a34a'],
      ['rel_cliente_ativo', 'rel.cliente_ativo', 'relationship', '#059669'],
      ['status_em_triagem', 'status.em_triagem', 'status', '#f59e0b'],
      ['status_consulta_agendada', 'status.consulta_agendada', 'status', '#7c3aed'],
      ['status_aguardando_documento', 'status.aguardando_documento', 'status', '#0891b2'],
      ['status_sem_responsavel', 'status.sem_responsavel', 'status', '#ef4444'],
      ['doc_rg_pendente', 'doc.rg_pendente', 'document', '#f97316'],
      ['doc_rg_recebido', 'doc.rg_recebido', 'document', '#16a34a'],
      ['doc_cpf_pendente', 'doc.cpf_pendente', 'document', '#f97316'],
      ['doc_cpf_recebido', 'doc.cpf_recebido', 'document', '#16a34a'],
      ['doc_cnis_pendente', 'doc.cnis_pendente', 'document', '#f97316'],
      ['doc_cnis_recebido', 'doc.cnis_recebido', 'document', '#16a34a'],
      ['doc_ctps_pendente', 'doc.ctps_pendente', 'document', '#f97316'],
      ['doc_ctps_recebido', 'doc.ctps_recebido', 'document', '#16a34a'],
      ['doc_cnh_recebido', 'doc.cnh_recebido', 'document', '#16a34a'],
      ['doc_comprovante_recebido', 'doc.comprovante_recebido', 'document', '#16a34a'],
      ['doc_procuracao_recebido', 'doc.procuracao_recebido', 'document', '#16a34a'],
      ['doc_contrato_recebido', 'doc.contrato_recebido', 'document', '#16a34a'],
      ['doc_termo_rescisao_recebido', 'doc.termo_rescisao_recebido', 'document', '#16a34a'],
      ['doc_extrato_recebido', 'doc.extrato_recebido', 'document', '#16a34a'],
      ['doc_peticao_recebida', 'doc.peticao_recebida', 'document', '#16a34a'],
      ['doc_decisao_recebida', 'doc.decisao_recebida', 'document', '#16a34a'],
      ['doc_documento_recebido', 'doc.documento_recebido', 'document', '#16a34a'],
      ['doc_documento_ilegivel', 'doc.documento_ilegivel', 'document', '#dc2626'],
      ['risk_prazo_urgente', 'risk.prazo_urgente', 'risk', '#dc2626'],
      ['risk_audiencia_marcada', 'risk.audiencia_marcada', 'risk', '#b91c1c'],
      ['risk_intimacao_recebida', 'risk.intimacao_recebida', 'risk', '#f97316']
    ].freeze

    def initialize(account)
      @account = account
    end

    def perform
      LABELS.each do |title, slug, category, color|
        label = @account.labels.find_or_initialize_by(title: title)
        label.assign_attributes(
          slug: slug,
          category: category,
          color: color,
          scope: label_scope_for(category),
          is_system: true,
          show_on_sidebar: false
        )
        label.save!
      end
    end

    private

    def label_scope_for(category)
      return 'contact' if category.in?(%w[temperature relationship])

      'both'
    end
  end
end
