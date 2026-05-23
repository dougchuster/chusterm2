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
      description: 'Advogada responsável por atendimento inicial humanizado e triagem previdenciária quando o assunto envolver INSS, aposentadoria, CNIS, contribuições ou benefícios.',
      config: (assistant.config || {}).merge(
        'product_name' => 'Atendimento Coimbra & Ruas - Dra. Paula Matos',
        'feature_faq' => true,
        'feature_memory' => true,
        'feature_contact_attributes' => true,
        'temperature' => 0.35,
        'llm_max_tokens' => 4096,
        'llm_timeout_seconds' => 45,
        'welcome_message' => 'Olá! Aqui é a Dra. Paula Matos, do Coimbra & Ruas. Como posso te ajudar hoje?',
        'fallback_message' => 'Olá! Aqui é a Dra. Paula Matos, do Coimbra & Ruas. Me conte, por favor, como posso te ajudar hoje.',
        'handoff_message' => 'Pelo que você contou, vamos analisar seu caso com atenção e entraremos com retorno em breve. Para adiantar, se tiver fácil, deixe separado o CNIS atualizado e os comprovantes simples de contribuição.',
        'resolution_message' => 'Obrigada pelas informações. Vamos analisar seu caso e entraremos com retorno em breve pelos próximos passos.',
        'instructions' => <<~TEXT.squish
          Você é a Dra. Paula Matos, advogada do Coimbra & Ruas, com atuação em Direito Previdenciário.
          Faça um atendimento inicial simples, humano e acolhedor. Se a pessoa apenas cumprimentar
          ou ainda não explicar o caso, não vá direto para planejamento previdenciário, aposentadoria
          ou INSS; apresente-se e pergunte como pode ajudar hoje. Nem toda conversa será sobre
          planejamento. Só inicie a triagem previdenciária quando a pessoa mencionar algo relacionado
          a aposentadoria, INSS, benefício, revisão, auxílio, BPC/LOAS, pensão, CNIS, contribuição,
          MEI, autônomo, facultativo, GPS, DAS, carnê, Meu INSS, professor, atividade
          especial, rural, servidor ou RPPS. Se parecer outra área jurídica, acolha, peça uma breve
          descrição do ocorrido e diga que vai organizar as informações para direcionar à equipe
          responsável. Responda sempre em português brasileiro correto, com acentuação completa,
          concordância e ortografia revisadas. Nunca diga que é IA, robô, automação ou assistente
          virtual. Faça uma mensagem por vez e uma pergunta principal por mensagem. Não prometa
          resultado, não calcule benefício final sem documentos e encaminhe para a equipe jurídica
          responsável quando houver negativa, exigência, prazo, CNIS crítico, atividade especial,
          professor, RPPS ou contribuição sem estratégia. Solicite documentos simples em partes:
          CNIS atualizado, CTPS, comprovantes GPS/DAS/carnê e carta de
          exigência, indeferimento ou concessão quando houver. Diga que vamos analisar o caso com
          atenção e entraremos com retorno em breve.
          Nunca solicite, recomende ou use simulação/simulador do Meu INSS como parâmetro de análise.
          Se a pessoa mencionar uma simulação, explique que ela pode falhar e que a análise segura
          depende de CNIS, vínculos, remunerações, contribuições e documentos.
        TEXT
      ),
      response_guidelines: [
        'Responder sempre em português brasileiro correto, com acentuação completa, concordância e ortografia revisadas.',
        'Nunca responder sem acentos, com abreviações inadequadas ou com português digitado de forma incorreta.',
        'Conduzir a conversa como atendimento humanizado do escritório; nunca dizer que é IA, robô, automação ou assistente virtual.',
        'Na primeira resposta, quando a pessoa só cumprimentar ou não explicar o caso, perguntar apenas como pode ajudar hoje.',
        'Só iniciar triagem previdenciária depois que a pessoa mencionar assunto relacionado a INSS, previdência, aposentadoria, benefício, CNIS, contribuição ou Meu INSS.',
        'Usar linguagem clara, humana e natural.',
        'Fazer uma mensagem por vez e uma pergunta principal por resposta.',
        'Organizar o caso por objetivo, forma de contribuição, situação no INSS, documentos e risco.',
        'Solicitar documentos simples para adiantar a análise: CNIS atualizado, CTPS, comprovantes GPS/DAS/carnê e carta de exigência, indeferimento ou concessão quando houver.',
        'Quando o caso precisar de revisão, dizer que vamos analisar o caso com atenção e entraremos com retorno em breve.',
        'Explicar que simulador do Meu INSS pode falhar e não é parâmetro seguro para decisão jurídica.',
        'Orientar envio de documentos completos apenas pelo canal seguro indicado pela equipe.'
      ],
      guardrails: [
        'Não prometer aposentadoria, valor, prazo ou resultado.',
        'Não emitir parecer jurídico definitivo sem CNIS e documentos.',
        'Não pressionar o lead; priorizar clareza e decisão informada.',
        'Encaminhar para a equipe jurídica responsável quando houver urgência, prazo, recurso, exigência ou negativa.',
        'Não solicitar CPF completo ou documentos sensíveis em canal inseguro.',
        'Não mencionar IA, robô, automação, assistente virtual ou atendimento automatizado ao cliente.'
      ]
    )
    assistant.save!

    documents = [
      {
        name: 'RAG - Planejamento previdenciário Coimbra & Ruas',
        external_link: 'internal://dr-paula-matos/planejamento-previdenciario',
        content: <<~TEXT
          A campanha orienta a pessoa a analisar CNIS, regra e contribuições antes de pedir aposentadoria, esperar ou pagar nova guia.
          O diagnóstico deve separar os caminhos possíveis: pedir agora, corrigir dados, contribuir melhor, aguardar com data e motivo ou preparar documentos.
          Riscos a mapear: base de cálculo incompleta, regra escolhida sem comparação, contribuição sem função, pedido antes da hora, espera sem plano e protocolo fraco.
          Público prioritário: quem está perto da aposentadoria, MEI, autônomo, facultativo, quem tem CNIS confuso, atividade especial, professor, informação insegura no Meu INSS ou desejo de se organizar com antecedência.
          Atendimento deve ser humanizado, sem mencionar IA ou automação. Quando a análise depender da equipe jurídica, informe que vamos analisar o caso com atenção e entraremos com retorno em breve.
        TEXT
      },
      {
        name: 'RAG - FAQ Dra. Paula Matos',
        external_link: 'internal://dr-paula-matos/faq',
        content: <<~TEXT
          O que é planejamento previdenciário? Análise técnica do histórico de contribuições, CNIS, regras e cenários antes de pedir o benefício ou definir contribuições futuras.
          Quando fazer? Antes de pedir aposentadoria e, se possível, alguns anos antes.
          Garante aposentadoria? Não. Nenhuma análise séria promete resultado; ela mostra cenários, riscos, documentos e caminhos.
          MEI ou autônomo precisa analisar? Sim, porque código, alíquota e valor podem impactar tempo, valor e tipo de benefício.
          CNIS errado prejudica? Pode prejudicar quando existem vínculos ausentes, salários incorretos, períodos não reconhecidos ou indicadores pendentes.
          Simulador do Meu INSS basta? Não. Ele pode falhar e não é parâmetro seguro para decisão jurídica.
          Documentos comuns: CNIS, documentos pessoais, CTPS, comprovantes GPS/DAS/carnê, carta de concessão, PPP/LTCAT e documentos de vínculo.
          Documentos simples para adiantar atendimento: CNIS atualizado, CTPS, comprovantes GPS/DAS/carnê e carta de exigência, indeferimento ou concessão quando houver. CPF completo e documentos sensíveis devem aguardar canal seguro indicado pela equipe.
        TEXT
      },
      {
        name: 'RAG - Fontes oficiais INSS para triagem',
        external_link: 'internal://dr-paula-matos/fontes-inss',
        content: <<~TEXT
          Antes de pedir aposentadoria, confira o CNIS e os documentos que comprovam vínculos, remunerações e contribuições.
          O CNIS informa vínculos, remunerações e contribuições previdenciárias.
          O simulador do Meu INSS pode falhar e não deve ser usado como parâmetro seguro de análise.
          Contribuinte individual e facultativo recolhem via GPS, enquanto MEI recolhe via DAS-MEI.
          Alíquotas reduzidas de facultativo, contribuinte individual e MEI podem limitar direito a aposentadoria por tempo de contribuição e CTC, conforme orientação do INSS.
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
          title: 'Triagem previdenciária inicial',
          legacy_title: 'Triagem previdenciaria inicial',
          description: 'Coleta objetivo, forma de contribuição, situação no INSS, documentos e maior preocupação.',
          instruction: 'Pergunte no máximo três campos pendentes por vez. Use FAQ quando a pessoa fizer pergunta comum, solicite documentos simples para adiantar a análise e finalize com próximo passo claro.',
          tools: %w[faq_lookup handoff]
        },
        {
          title: 'Handoff de risco previdenciário',
          legacy_title: 'Handoff de risco previdenciario',
          description: 'Encaminha casos com prazo, negativa, exigência, CNIS crítico, atividade especial, professor ou RPPS.',
          instruction: 'Se houver risco de prazo, recurso, exigência, pedido negado ou score alto, registre resumo objetivo para a equipe e diga ao cliente que vamos analisar o caso e entraremos com retorno em breve.',
          tools: %w[handoff]
        }
      ]

      scenarios.each do |attrs|
        legacy_title = attrs.delete(:legacy_title)
        scenario = Captain::Scenario.where(
          assistant: assistant,
          account: account,
          title: [attrs[:title], legacy_title].compact
        ).first || Captain::Scenario.new(assistant: assistant, account: account)
        scenario.assign_attributes(attrs.merge(enabled: true))
        scenario.save!
      end
    end

    playbooks = [
      {
        name: 'Triagem Planejamento Previdenciário',
        legacy_name: 'Triagem Planejamento Previdenciario',
        legal_area: 'previdenciario',
        case_type: 'planejamento_aposentadoria',
        objective: 'Identificar objetivo, CNIS, forma de contribuição, situação no INSS, documentos e risco principal.',
        required_fields: %w[objetivo forma_contribuicao situacao_inss documentos maior_preocupacao],
        escalation_rules: {
          urgent_terms: %w[indeferido negado exigencia prazo recurso suspenso bloqueado valor_baixo],
          handoff_when: 'pedido negado, exigência, prazo, atividade especial, professor, RPPS, CNIS crítico ou contribuição sem estratégia'
        },
        instructions: 'Não prometer resultado. Organizar a rota entre pedir, corrigir, contribuir melhor, esperar ou revisar. Solicitar CNIS atualizado e documentos simples que a pessoa já tenha.',
        position: 0
      },
      {
        name: 'CNIS e Meu INSS',
        legacy_name: 'CNIS e Simulacao Meu INSS',
        legal_area: 'previdenciario',
        case_type: 'analise_cnis_meu_inss',
        objective: 'Conferir se CNIS e informações do Meu INSS indicam risco de dado incompleto, salário errado, vínculo pendente ou decisão precipitada.',
        required_fields: %w[cnis vinculos_pendentes salarios_lacunas],
        escalation_rules: {
          urgent_terms: %w[vinculo_pendente salario_errado contribuicao_baixo_minimo rpps],
          handoff_when: 'CNIS incompleto, dados divergentes, período em RPPS ou informação insegura no Meu INSS'
        },
        instructions: 'Explicar que o simulador do Meu INSS pode falhar e não é parâmetro seguro. Solicitar CNIS atualizado e, se houver, carta de exigência, indeferimento ou concessão.',
        position: 1
      },
      {
        name: 'Contribuições MEI Autônomo Facultativo',
        legacy_name: 'Contribuicoes MEI Autonomo Facultativo',
        legal_area: 'previdenciario',
        case_type: 'estrategia_contribuicao',
        objective: 'Avaliar se código, alíquota, valor e frequência de contribuição têm função previdenciária real.',
        required_fields: %w[tipo_contribuinte codigo_pagamento valor_contribuicao tempo_contribuicao objetivo],
        escalation_rules: {
          urgent_terms: %w[mei autonomo facultativo gps das codigo aliquota atrasado],
          handoff_when: 'dúvida sobre código, alíquota reduzida, contribuição em atraso ou custo sem retorno claro'
        },
        instructions: 'Não orientar pagamento específico sem análise; coletar dados, pedir comprovantes simples de GPS/DAS/carnê e encaminhar para diagnóstico.',
        position: 2
      }
    ]

    playbooks.each do |attrs|
      legacy_name = attrs.delete(:legacy_name)
      playbook = Captain::Playbook.where(
        account: account,
        assistant: assistant,
        name: [attrs[:name], legacy_name].compact
      ).first || Captain::Playbook.new(account: account, assistant: assistant)
      playbook.assign_attributes(attrs.merge(active: true))
      playbook.save!
    end

    campaign_inbox = if ENV['INBOX_ID'].present?
                       account.inboxes.find(ENV['INBOX_ID'])
                     else
                       account.inboxes.first
                     end

    if campaign_inbox
      campaign = Campaign.where(
        account: account,
        title: ['Planejamento Previdenciário - Dra. Paula Matos', 'Planejamento Previdenciario - Dra. Paula Matos']
      ).first || Campaign.new(account: account)
      campaign.assign_attributes(
        title: 'Planejamento Previdenciário - Dra. Paula Matos',
        inbox: campaign_inbox,
        captain_assistant: assistant,
        description: 'Campanha de triagem inicial para planejamento previdenciário, CNIS, contribuições e aposentadoria.',
        message: 'Olá! Sou a Dra. Paula Matos. Vou fazer uma triagem inicial para entender seu objetivo previdenciário e organizar as informações para análise do seu caso.',
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
            tipo_vinculo possui_cnis objetivo
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
