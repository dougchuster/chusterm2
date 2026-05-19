namespace :captain do
  desc 'Seed Dra. Paula Matos Captain assistant for previdenciario planning. Usage: ACCOUNT_ID=1 rake captain:seed_dr_paula_matos'
  task seed_dr_paula_matos: :environment do
    account_id = ENV.fetch('ACCOUNT_ID')
    account = Account.find(account_id)

    unless defined?(Captain::Assistant)
      raise 'Captain::Assistant is not available in this runtime'
    end

    assistant = Captain::Assistant.find_or_initialize_by(account: account, name: 'Dra. Paula Matos')
    assistant.assign_attributes(
      description: 'Advogada previdenciaria para triagem inicial de planejamento de aposentadoria, CNIS, contribuicoes e riscos antes do pedido ao INSS.',
      config: (assistant.config || {}).merge(
        'product_name' => 'Planejamento Previdenciario Coimbra & Ruas',
        'feature_faq' => true,
        'feature_memory' => true,
        'feature_contact_attributes' => true,
        'temperature' => 0.35,
        'llm_max_tokens' => 4096,
        'llm_timeout_seconds' => 45,
        'instructions' => <<~TEXT.squish
          Voce e a Dra. Paula Matos, advogada previdenciaria do Coimbra & Ruas.
          Faça triagem inicial de planejamento previdenciario com acolhimento,
          objetividade e tecnica. Nao prometa resultado, nao calcule beneficio
          final sem documentos e encaminhe para humano quando houver negativa,
          exigencia, prazo, CNIS critico, atividade especial, professor, RPPS
          ou contribuicao sem estrategia.
        TEXT
      ),
      response_guidelines: [
        'Responder em portugues brasileiro, com linguagem clara e humana.',
        'Fazer no maximo tres perguntas por resposta.',
        'Organizar o caso por objetivo, forma de contribuicao, situacao no INSS, documentos e risco.',
        'Explicar que simulacao do Meu INSS e ponto de partida, nao garantia de direito.',
        'Orientar envio de documentos completos apenas pelo canal seguro indicado pela equipe.'
      ],
      guardrails: [
        'Nao prometer aposentadoria, valor, prazo ou resultado.',
        'Nao emitir parecer juridico definitivo sem CNIS e documentos.',
        'Nao pressionar o lead; priorizar clareza e decisao informada.',
        'Encaminhar para atendimento humano quando houver urgencia, prazo, recurso, exigencia ou negativa.',
        'Nao solicitar CPF completo ou documentos sensiveis em canal inseguro.'
      ]
    )
    assistant.save!

    documents = [
      {
        name: 'RAG - Planejamento previdenciario Coimbra & Ruas',
        external_link: 'internal://dr-paula-matos/planejamento-previdenciario',
        content: <<~TEXT
          A campanha orienta a pessoa a analisar CNIS, regra e contribuicoes antes de pedir aposentadoria, esperar ou pagar nova guia.
          O diagnostico deve separar os caminhos possiveis: pedir agora, corrigir dados, contribuir melhor, aguardar com data e motivo ou preparar documentos.
          Riscos a mapear: base de calculo incompleta, regra escolhida sem comparacao, contribuicao sem funcao, pedido antes da hora, espera sem plano e protocolo fraco.
          Publico prioritario: quem esta perto da aposentadoria, MEI, autonomo, facultativo, quem tem CNIS confuso, atividade especial, professor, simulacao baixa ou desejo de se organizar com antecedencia.
        TEXT
      },
      {
        name: 'RAG - FAQ Dra. Paula Matos',
        external_link: 'internal://dr-paula-matos/faq',
        content: <<~TEXT
          O que e planejamento previdenciario? Analise tecnica do historico de contribuicoes, CNIS, regras e cenarios antes de pedir o beneficio ou definir contribuicoes futuras.
          Quando fazer? Antes de pedir aposentadoria e, se possivel, alguns anos antes.
          Garante aposentadoria? Nao. Nenhuma analise seria promete resultado; ela mostra cenarios, riscos, documentos e caminhos.
          MEI ou autonomo precisa analisar? Sim, porque codigo, aliquota e valor podem impactar tempo, valor e tipo de beneficio.
          CNIS errado prejudica? Pode prejudicar quando existem vinculos ausentes, salarios incorretos, periodos nao reconhecidos ou indicadores pendentes.
          Simulacao do Meu INSS basta? Nao. E ponto de partida e precisa ser conferida contra documentos e regras aplicaveis.
          Documentos comuns: CNIS, documentos pessoais, CTPS, comprovantes GPS/DAS/carne, simulacao Meu INSS, carta de concessao, PPP/LTCAT e documentos de vinculo.
        TEXT
      },
      {
        name: 'RAG - Fontes oficiais INSS para triagem',
        external_link: 'internal://dr-paula-matos/fontes-inss',
        content: <<~TEXT
          O INSS orienta conferir CNIS e simulacao antes de pedir aposentadoria.
          O CNIS informa vinculos, remuneracoes e contribuicoes previdenciarias.
          A simulacao do Meu INSS e apenas demonstrativo de consulta e nao garante direito ao beneficio.
          Contribuinte individual e facultativo recolhem via GPS, enquanto MEI recolhe via DAS-MEI.
          Alíquotas reduzidas de facultativo, contribuinte individual e MEI podem limitar direito a aposentadoria por tempo de contribuicao e CTC, conforme orientacao do INSS.
        TEXT
      }
    ]

    documents.each do |attrs|
      document = Captain::Document.find_or_initialize_by(
        assistant: assistant,
        external_link: attrs[:external_link]
      )
      document.assign_attributes(
        account: account,
        name: attrs[:name],
        content: attrs[:content],
        status: 'available',
        metadata: (document.metadata || {}).merge(
          'agent_slug' => 'dr-paula-matos',
          'campaign_slug' => 'planejamento-previdenciario',
          'sector' => 'previdenciario'
        )
      )
      document.save!
    rescue Captain::Document::LimitExceededError => e
      warn "Document limit reached for #{attrs[:name]}: #{e.message}"
    end

    if defined?(Captain::Scenario)
      scenarios = [
        {
          title: 'Triagem previdenciaria inicial',
          description: 'Coleta objetivo, forma de contribuicao, situacao no INSS, documentos e maior preocupacao.',
          instruction: 'Pergunte no maximo tres campos pendentes por vez. Use FAQ quando a pessoa fizer pergunta comum e finalize com proximo passo claro.',
          tools: %w[faq_lookup handoff]
        },
        {
          title: 'Handoff de risco previdenciario',
          description: 'Encaminha casos com prazo, negativa, exigencia, CNIS critico, atividade especial, professor ou RPPS.',
          instruction: 'Se houver risco de prazo, recurso, exigencia, pedido negado ou score alto, use handoff e registre resumo objetivo para a equipe.',
          tools: %w[handoff]
        }
      ]

      scenarios.each do |attrs|
        scenario = Captain::Scenario.find_or_initialize_by(
          assistant: assistant,
          account: account,
          title: attrs[:title]
        )
        scenario.assign_attributes(attrs.merge(enabled: true))
        scenario.save!
      end
    end

    playbooks = [
      {
        name: 'Triagem Planejamento Previdenciario',
        legal_area: 'previdenciario',
        case_type: 'planejamento_aposentadoria',
        objective: 'Identificar objetivo, CNIS, forma de contribuicao, situacao no INSS, documentos e risco principal.',
        required_fields: %w[objetivo forma_contribuicao situacao_inss documentos maior_preocupacao],
        escalation_rules: {
          urgent_terms: %w[indeferido negado exigencia prazo recurso suspenso bloqueado valor_baixo],
          handoff_when: 'pedido negado, exigencia, prazo, atividade especial, professor, RPPS, CNIS critico ou contribuicao sem estrategia'
        },
        instructions: 'Nao prometer resultado. Organizar a rota entre pedir, corrigir, contribuir melhor, esperar ou revisar.',
        position: 0
      },
      {
        name: 'CNIS e Simulacao Meu INSS',
        legal_area: 'previdenciario',
        case_type: 'analise_cnis_simulacao',
        objective: 'Conferir se CNIS e simulacao indicam risco de dado incompleto, salario errado, vinculo pendente ou decisao precipitada.',
        required_fields: %w[cnis simulacao_meu_inss vinculos_pendentes salarios_lacunas],
        escalation_rules: {
          urgent_terms: %w[vinculo_pendente salario_errado contribuicao_baixo_minimo rpps],
          handoff_when: 'CNIS incompleto, dados divergentes, periodo em RPPS ou simulacao baixa'
        },
        instructions: 'Explicar que a simulacao e ponto de partida e precisa ser lida com documentos.',
        position: 1
      },
      {
        name: 'Contribuicoes MEI Autonomo Facultativo',
        legal_area: 'previdenciario',
        case_type: 'estrategia_contribuicao',
        objective: 'Avaliar se codigo, aliquota, valor e frequencia de contribuicao tem funcao previdenciaria real.',
        required_fields: %w[tipo_contribuinte codigo_pagamento valor_contribuicao tempo_contribuicao objetivo],
        escalation_rules: {
          urgent_terms: %w[mei autonomo facultativo gps das codigo aliquota atrasado],
          handoff_when: 'duvida sobre codigo, aliquota reduzida, contribuicao em atraso ou custo sem retorno claro'
        },
        instructions: 'Nao orientar pagamento especifico sem analise; coletar dados e encaminhar para diagnostico.',
        position: 2
      }
    ]

    playbooks.each do |attrs|
      playbook = Captain::Playbook.find_or_initialize_by(
        account: account,
        assistant: assistant,
        name: attrs[:name]
      )
      playbook.assign_attributes(attrs.merge(active: true))
      playbook.save!
    end

    campaign_inbox = if ENV['INBOX_ID'].present?
                       account.inboxes.find(ENV['INBOX_ID'])
                     else
                       account.inboxes.first
                     end

    if campaign_inbox
      campaign = Campaign.find_or_initialize_by(
        account: account,
        title: 'Planejamento Previdenciario - Dra. Paula Matos'
      )
      campaign.assign_attributes(
        inbox: campaign_inbox,
        captain_assistant: assistant,
        description: 'Campanha de triagem inicial para planejamento previdenciario, CNIS, contribuicoes e aposentadoria.',
        message: 'Ola! Sou a Dra. Paula Matos. Vou fazer uma triagem inicial para entender seu objetivo previdenciario e indicar o proximo passo com seguranca.',
        enabled: true,
        scoring_config: (campaign.scoring_config || {}).deep_merge(
          'score_model' => 'previdenciario-planejamento-v1',
          'memory_enabled' => true,
          'triage_enabled' => true,
          'classification_enabled' => true,
          'auto_move_on_score' => true,
          'weights' => Crm::LeadScoreCalculator::DEFAULT_WEIGHTS,
          'classification_thresholds' => CrmScoreClassification::DEFAULT_THRESHOLDS,
          'classification_labels' => {
            'baixo_potencial' => 'Frio',
            'medio_potencial' => 'Morno',
            'qualificado' => 'Quente',
            'prioridade_alta' => 'Prioridade alta'
          },
          'memory_fields' => %w[
            nome idade profissao regime_previdenciario tempo_contribuicao
            cnis_status objetivo_previdenciario urgencia pendencias_documentais
          ],
          'triage_required_fields' => %w[
            idade sexo profissao regime_previdenciario tempo_contribuicao
            tipo_vinculo possui_cnis simulacao_meu_inss objetivo
          ]
        )
      )
      campaign.save!

      if defined?(CaptainInbox)
        captain_inbox = CaptainInbox.find_or_initialize_by(inbox: campaign_inbox)
        captain_inbox.assign_attributes(
          captain_assistant: assistant,
          enabled: true,
          auto_reply_enabled: true,
          ai_mode: 'auto',
          handoff_strategy: 'human_request_or_score',
          routing_config: (captain_inbox.routing_config || {}).reverse_merge(
            'response_delay_seconds' => 2,
            'response_max_wait_seconds' => 60
          )
        )
        captain_inbox.save!
        puts "Connected Dra. Paula Matos to inbox #{campaign_inbox.id}"
      end

      puts "Campaign ready. campaign_id=#{campaign.display_id} inbox_id=#{campaign_inbox.id}"
    else
      warn 'No inbox found; skipped Dra. Paula Matos campaign creation.'
    end

    puts "Dra. Paula Matos ready. assistant_id=#{assistant.id} account_id=#{account.id}"
  end
end
