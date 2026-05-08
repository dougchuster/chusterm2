Account.find_each do |account|
  next if account.crm_pipelines.exists?

  pipeline = account.crm_pipelines.create!(
    name: 'Pipeline Jurídico',
    slug: 'pipeline-juridico',
    kind: 'legal_intake',
    is_default: true,
    position: 0
  )

  stages = [
    { name: 'Novo atendimento', slug: 'novo-atendimento', position: 0, probability_pct: 5, color: '#6b7280' },
    { name: 'Triagem IA', slug: 'triagem-ia', position: 1, probability_pct: 10, color: '#8b5cf6' },
    { name: 'Qualificado', slug: 'qualificado', position: 2, probability_pct: 30, color: '#3b82f6' },
    { name: 'Consulta/Reunião', slug: 'consulta-reuniao', position: 3, probability_pct: 45, color: '#06b6d4' },
    { name: 'Documentos solicitados', slug: 'documentos-solicitados', position: 4, probability_pct: 55, color: '#f59e0b' },
    { name: 'Em análise jurídica', slug: 'em-analise-juridica', position: 5, probability_pct: 65, color: '#f97316' },
    { name: 'Proposta enviada', slug: 'proposta-enviada', position: 6, probability_pct: 75, color: '#ec4899' },
    { name: 'Contrato fechado', slug: 'contrato-fechado', position: 7, probability_pct: 100, color: '#10b981' },
    { name: 'Perdido/Arquivado', slug: 'perdido-arquivado', position: 8, probability_pct: 0, color: '#ef4444' }
  ]

  stages.each { |s| pipeline.crm_pipeline_stages.create!(s.merge(account: account)) }

  loss_reasons = [
    { name: 'Sem retorno', slug: 'sem_retorno', position: 0 },
    { name: 'Sem documentação', slug: 'sem_documentacao', position: 1 },
    { name: 'Sem viabilidade jurídica', slug: 'sem_viabilidade_juridica', position: 2 },
    { name: 'Sem capacidade financeira', slug: 'sem_capacidade_financeira', position: 3 },
    { name: 'Fora da área de atuação', slug: 'fora_da_area_de_atuacao', position: 4 },
    { name: 'Conflito de interesses', slug: 'conflito_de_interesses', position: 5 },
    { name: 'Cliente escolheu outro escritório', slug: 'cliente_escolheu_outro_escritorio', position: 6 },
    { name: 'Prazo perdido', slug: 'prazo_perdido', position: 7 },
    { name: 'Atendimento duplicado', slug: 'atendimento_duplicado', position: 8 },
    { name: 'Caso resolvido sem contratação', slug: 'caso_resolvido_sem_contratacao', position: 9 }
  ]

  loss_reasons.each { |r| account.crm_loss_reasons.create!(r) }

  next if account.crm_checklist_templates.exists?

  checklist_templates = [
    {
      name: 'Aposentadoria por Tempo de Contribuição',
      case_type: 'aposentadoria',
      legal_area: 'previdenciario',
      position: 0,
      items: [
        { key: 'cnis', title: 'CNIS atualizado (últimos 6 meses)', kind: 'document', required: true },
        { key: 'rg_cpf', title: 'RG e CPF', kind: 'document', required: true },
        { key: 'ctps', title: 'Carteira de Trabalho (CTPS)', kind: 'document', required: true },
        { key: 'comprovante_residencia', title: 'Comprovante de residência', kind: 'document', required: true },
        { key: 'carta_concessao', title: 'Carta de concessão (se já recebe benefício)', kind: 'document', required: false },
        { key: 'agendar_consulta', title: 'Agendar consulta para análise de tempo de contribuição', kind: 'task', required: true },
        { key: 'verificar_periodos', title: 'Verificar períodos descobertos no CNIS', kind: 'task', required: true }
      ]
    },
    {
      name: 'Revisão de Benefício Previdenciário',
      case_type: 'revisao_de_beneficio',
      legal_area: 'previdenciario',
      position: 1,
      items: [
        { key: 'cnis', title: 'CNIS atualizado', kind: 'document', required: true },
        { key: 'carta_concessao', title: 'Carta de concessão do benefício atual', kind: 'document', required: true },
        { key: 'historico_pagamentos', title: 'Histórico de pagamentos (extrato INSS)', kind: 'document', required: true },
        { key: 'rg_cpf', title: 'RG e CPF', kind: 'document', required: true },
        { key: 'calcular_diferenca', title: 'Calcular diferença entre benefício recebido e correto', kind: 'task', required: true },
        { key: 'verificar_prescricao', title: 'Verificar prazo prescricional (10 anos)', kind: 'task', required: true }
      ]
    },
    {
      name: 'Divórcio Consensual',
      case_type: 'divorcio',
      legal_area: 'familia',
      position: 2,
      items: [
        { key: 'rg_cpf_ambos', title: 'RG e CPF de ambos os cônjuges', kind: 'document', required: true },
        { key: 'certidao_casamento', title: 'Certidão de casamento atualizada', kind: 'document', required: true },
        { key: 'certidao_nascimento_filhos', title: 'Certidão de nascimento dos filhos (se houver)', kind: 'document', required: false },
        { key: 'relacao_bens', title: 'Relação de bens e patrimônio do casal', kind: 'document', required: true },
        { key: 'comprovante_residencia', title: 'Comprovante de residência atual', kind: 'document', required: true },
        { key: 'acordo_partilha', title: 'Rascunho do acordo de partilha de bens', kind: 'task', required: true },
        { key: 'acordo_guarda', title: 'Definir acordo de guarda e visitas (se houver filhos)', kind: 'task', required: false }
      ]
    },
    {
      name: 'Rescisão Trabalhista',
      case_type: 'rescisao_trabalhista',
      legal_area: 'trabalhista',
      position: 3,
      items: [
        { key: 'ctps', title: 'Carteira de Trabalho (CTPS)', kind: 'document', required: true },
        { key: 'termo_rescisao', title: 'Termo de rescisão contratual (TRCT)', kind: 'document', required: true },
        { key: 'contracheques', title: 'Últimos 12 contracheques', kind: 'document', required: true },
        { key: 'extrato_fgts', title: 'Extrato do FGTS', kind: 'document', required: true },
        { key: 'aviso_previo', title: 'Aviso prévio (se aplicável)', kind: 'document', required: false },
        { key: 'rg_cpf', title: 'RG e CPF', kind: 'document', required: true },
        { key: 'calcular_verbas', title: 'Calcular verbas rescisórias devidas', kind: 'task', required: true },
        { key: 'verificar_fgts_multa', title: 'Verificar multa de 40% sobre FGTS', kind: 'task', required: true }
      ]
    },
    {
      name: 'Ação de Cobrança / Dano Moral',
      case_type: 'dano_moral',
      legal_area: 'civil',
      position: 4,
      items: [
        { key: 'rg_cpf', title: 'RG e CPF do cliente', kind: 'document', required: true },
        { key: 'documentos_do_caso', title: 'Documentos comprobatórios do dano (contratos, prints, fotos)', kind: 'document', required: true },
        { key: 'comprovante_prejuizo', title: 'Comprovante de prejuízo ou dano sofrido', kind: 'document', required: true },
        { key: 'tentativa_administrativa', title: 'Registro de tentativa de resolução administrativa (protocolo, e-mail)', kind: 'document', required: false },
        { key: 'avaliar_valor', title: 'Avaliar valor do dano e quantum indenizatório', kind: 'task', required: true },
        { key: 'verificar_prescricao', title: 'Verificar prazo prescricional (3 anos)', kind: 'task', required: true }
      ]
    },
    {
      name: 'Inventário e Sucessões',
      case_type: 'inventario',
      legal_area: 'sucessoes',
      position: 5,
      items: [
        { key: 'certidao_obito', title: 'Certidão de óbito do(a) falecido(a)', kind: 'document', required: true },
        { key: 'certidao_nascimento_herdeiros', title: 'Certidão de nascimento de todos os herdeiros', kind: 'document', required: true },
        { key: 'relacao_bens', title: 'Relação completa de bens do espólio', kind: 'document', required: true },
        { key: 'certidao_imoveis', title: 'Certidão de matrícula dos imóveis (Cartório de Registro)', kind: 'document', required: false },
        { key: 'certidao_casamento_falecido', title: 'Certidão de casamento do(a) falecido(a)', kind: 'document', required: false },
        { key: 'rg_cpf_herdeiros', title: 'RG e CPF de todos os herdeiros', kind: 'document', required: true },
        { key: 'verificar_testamento', title: 'Verificar existência de testamento', kind: 'task', required: true },
        { key: 'calcular_imposto', title: 'Calcular ITCMD devido', kind: 'task', required: true }
      ]
    }
  ]

  checklist_templates.each { |t| account.crm_checklist_templates.create!(t) }
end
