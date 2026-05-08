Account.find_each do |account|
  next if account.crm_automation_rules.exists?

  pipeline = account.crm_pipelines.find_by(is_default: true)
  next unless pipeline

  default_rules = [
    {
      stage_slug: 'documentos-solicitados',
      name: 'Solicitar conferência de documentos',
      action_config: {
        kind: 'solicitacao_documentos',
        title: 'Conferir envio de documentos',
        description: 'Verificar se o cliente enviou os documentos solicitados e atualizar o status documental.',
        priority: 'normal',
        due_in_hours: 48
      }
    },
    {
      stage_slug: 'proposta-enviada',
      name: 'Follow-up de proposta',
      action_config: {
        kind: 'follow_up',
        title: 'Retomar proposta enviada',
        description: 'Confirmar se o cliente recebeu a proposta e registrar a decisao.',
        priority: 'alta',
        due_in_hours: 24
      }
    },
    {
      stage_slug: 'consulta-reuniao',
      name: 'Preparar consulta jurídica',
      action_config: {
        kind: 'reuniao',
        title: 'Preparar consulta juridica',
        description: 'Revisar resumo, documentos e pontos de atencao antes da consulta.',
        priority: 'normal',
        due_in_hours: 12
      }
    },
    {
      stage_slug: 'em-analise-juridica',
      name: 'Concluir análise jurídica',
      action_config: {
        kind: 'revisao_juridica',
        title: 'Concluir analise juridica',
        description: 'Avaliar viabilidade, riscos, documentos pendentes e proxima acao.',
        priority: 'alta',
        due_in_hours: 24
      }
    }
  ]

  default_rules.each_with_index do |rule, i|
    stage = pipeline.crm_pipeline_stages.find_by(slug: rule[:stage_slug])
    next unless stage

    account.crm_automation_rules.create!(
      crm_pipeline_stage: stage,
      name: rule[:name],
      action_config: rule[:action_config],
      is_active: true,
      position: i
    )
  end
end
