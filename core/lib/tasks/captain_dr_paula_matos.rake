namespace :captain do
  desc 'Migrate the Dra. Paula assistant in place and seed the Dra. Letícia intake profile. Usage: ACCOUNT_ID=1 rake captain:seed_dr_paula_matos'
  task seed_dr_paula_matos: :environment do
    account_id = ENV.fetch('ACCOUNT_ID')
    account = Account.find(account_id)
    dra_leticia_model = ENV['CAPTAIN_DRA_LETICIA_LLM_MODEL'].presence ||
                        ENV['CAPTAIN_DR_PAULA_LLM_MODEL'].presence ||
                        'anthropic/claude-sonnet-5'
    dra_leticia_summarizer_model = ENV['CAPTAIN_DRA_LETICIA_SUMMARIZER_MODEL'].presence ||
                                   ENV['CAPTAIN_DR_PAULA_SUMMARIZER_MODEL'].presence ||
                                   'google/gemini-3.7-flash'

    unless defined?(Captain::Assistant)
      raise 'Captain::Assistant is not available in this runtime'
    end

    assistant_name = 'Dra. Letícia'
    legacy_assistant_name = 'Dra. Paula Matos'
    profile_key = 'dra_leticia_intake'
    assistant_scope = Captain::Assistant.where(account: account)
    assistant = assistant_scope.find { |candidate| candidate.config.to_h['profile_key'] == profile_key } ||
                assistant_scope.find_by(name: legacy_assistant_name) ||
                assistant_scope.find_by(name: assistant_name) ||
                assistant_scope.new(name: assistant_name)

    raise 'CaptainInbox is not available in this runtime' unless defined?(CaptainInbox)

    requested_inbox_id = ENV['INBOX_ID'].presence
    linked_inboxes = assistant.persisted? ? CaptainInbox.includes(:inbox).where(captain_assistant: assistant).map(&:inbox) : []
    linked_inboxes.select! { |inbox| inbox.account_id == account.id }

    target_inboxes = if requested_inbox_id
                       requested_inbox = account.inboxes.find_by(id: requested_inbox_id)
                       unless requested_inbox
                         raise ArgumentError,
                               "INBOX_ID=#{requested_inbox_id} does not belong to ACCOUNT_ID=#{account.id}. " \
                               'Use an inbox id from this account.'
                       end

                       [requested_inbox]
                     elsif linked_inboxes.any?
                       linked_inboxes
                     else
                       named_inboxes = account.inboxes.where(name: legacy_assistant_name).to_a
                       if named_inboxes.empty?
                         raise ArgumentError,
                               'No inbox is linked to this assistant and no inbox named "Dra. Paula Matos" exists. ' \
                               'Run again with an explicit INBOX_ID.'
                       end
                       if named_inboxes.many?
                         ids = named_inboxes.map(&:id).sort.join(', ')
                         raise ArgumentError,
                               "Multiple inboxes named \"Dra. Paula Matos\" were found (#{ids}). " \
                               'Run again with an explicit INBOX_ID.'
                       end

                       named_inboxes
                     end
    target_inboxes = target_inboxes.uniq(&:id).sort_by(&:id)

    conflicting_links = CaptainInbox.includes(:captain_assistant).where(inbox_id: target_inboxes.map(&:id)).select do |link|
      assistant.new_record? || link.captain_assistant_id != assistant.id
    end
    if conflicting_links.any?
      conflicts = conflicting_links.map do |link|
        "inbox #{link.inbox_id} is linked to assistant #{link.captain_assistant_id} (#{link.captain_assistant.name})"
      end.join('; ')
      raise ArgumentError, "Refusing to replace an existing Captain inbox link: #{conflicts}. Choose another INBOX_ID."
    end

    campaign_candidates = Campaign.where(
      account: account,
      title: ['Planejamento Previdenciário - Dra. Paula Matos', 'Planejamento Previdenciario - Dra. Paula Matos']
    ).to_a
    if campaign_candidates.many?
      ids = campaign_candidates.map(&:id).sort.join(', ')
      raise ArgumentError,
            "Multiple Dra. Paula campaigns were found (#{ids}). Resolve the duplicate campaigns before running this task."
    end
    campaign = campaign_candidates.sole if campaign_candidates.one?
    campaign_inbox = if requested_inbox_id || target_inboxes.one?
                       target_inboxes.sole
                     elsif campaign&.inbox_id.in?(target_inboxes.map(&:id))
                       campaign.inbox
                     else
                       ids = target_inboxes.map(&:id).join(', ')
                       raise ArgumentError,
                             "The assistant is already linked to multiple inboxes (#{ids}), but the campaign inbox is ambiguous. " \
                             'Run again with INBOX_ID to choose the campaign inbox; existing links will be preserved.'
                     end

    account.enable_features!('captain_integration_v2') unless account.feature_enabled?('captain_integration_v2')
    assistant.assign_attributes(
      name: assistant_name,
      description: 'Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos, pela compreensão ' \
                   'do caso e pela análise inicial das informações e dos documentos enviados.',
      config: (assistant.config || {}).merge(
        'profile_key' => profile_key,
        'managed_inbox_ids' => target_inboxes.map(&:id),
        'product_name' => 'Atendimento inicial da Dra. Paula Matos - Coimbra & Ruas',
        'feature_faq' => true,
        'feature_memory' => true,
        'feature_contact_attributes' => true,
        'feature_previdenciario_initial_responses' => true,
        'feature_dra_paula_data_collection_policy' => true,
        'public_identity' => 'Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos',
        'professional_identity' => true,
        'handoff_on_explicit_request_only' => true,
        'llm_provider' => 'openrouter',
        'llm_main_model' => dra_leticia_model,
        'llm_summarizer_model' => dra_leticia_summarizer_model,
        'temperature' => nil,
        'llm_max_tokens' => 700,
        'llm_timeout_seconds' => 45,
        'force_legacy_chat' => false,
        'deterministic_triage' => false,
        'stepwise_triage' => true,
        'welcome_message' => 'Olá! Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. Como posso ajudar você hoje?',
        'fallback_message' => 'Quero entender exatamente o que você perguntou. Pode esclarecer esse ponto em uma frase?',
        'handoff_message' => 'Obrigada pelas informações. A equipe analisará seu caso e seguirá com você por aqui.',
        'resolution_message' => 'Obrigada pelas informações. O atendimento inicial ficou organizado para a análise da equipe.',
        'instructions' => <<~TEXT.squish
          Você é a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos no escritório
          Coimbra & Ruas. Apresente-se assim somente na primeira resposta. Nunca use Capitão como identidade
          pública, nunca se passe pela Dra. Paula Matos e não reinicie a apresentação quando já houver histórico.

          Antes de responder, leia toda a conversa disponível, identifique a pergunta mais recente, o objetivo,
          o que já foi informado e os documentos realmente enviados. Entenda o caso antes de coletar dados.
          Responda primeiro toda pergunta direta; somente depois faça, se necessário, uma única pergunta curta.
          Não peça que a pessoa repita fatos do histórico nem solicite informação presente nos documentos.

          Quando houver anexo acessível, examine arquivo, descrição, transcrição e texto extraído por OCR.
          Use o conteúdo legível para explicar o documento e o próximo passo. Uma simples menção a CNIS, CPF,
          RG, CTPS, carta, laudo, PPP, LTCAT, comprovante, foto, arquivo ou documento não significa envio.
          Só confirme recebimento quando a última mensagem trouxer anexo, nome de arquivo, OCR correspondente
          ou declaração inequívoca de envio. Se não estiver legível, peça apenas um arquivo ou foto mais nítida.

          Se perguntarem como obter o CNIS, responda primeiro que ele pode ser baixado no aplicativo ou site
          Meu INSS, após entrar com a conta gov.br, em "Extrato de Contribuição (CNIS)". Nunca peça CPF, senha,
          PIN, token ou código de autenticação para explicar, obter ou baixar o CNIS.

          Quando a pessoa disser que outra advogada pediu algo ou um documento, diga uma única vez:
          "Também sou advogada e posso resolver isso para você." Depois responda diretamente o que foi
          perguntado. Se for sobre conseguir o CNIS, dê imediatamente o caminho no Meu INSS e não peça CPF.

          Considere lead novo somente quando o CRM indicar lead e esta for a primeira resposta do atendimento.
          Para lead novo, depois de responder a necessidade inicial, informe uma única vez: "Depois deste
          atendimento inicial, a equipe analisará seu caso com atenção e entrará em contato em breve por aqui."
          Para cliente existente ou relacionamento indefinido, nunca envie esse aviso e continue pelo histórico.

          Faça triagem gradual e compatível com o assunto, sem presumir que toda conversa é previdenciária.
          Depois da resposta inicial, use uma ou duas frases curtas e no máximo uma pergunta. Não prometa
          resultado, êxito, concessão, valor, prazo de solução ou direito garantido. A avaliação jurídica final
          cabe à equipe após examinar o caso completo. O único compromisso de tempo permitido é o aviso de
          contato em breve ao lead novo. Não use o simulador do Meu INSS como parâmetro seguro.

          Quando um fato jurídico ou institucional realmente exigir a base RAG, faça no máximo uma chamada
          faq_lookup por resposta ou turno. Use uma única consulta curta e objetiva, reutilize o resultado e
          responda em seguida. Nunca repita a busca com sinônimos, reformulações ou consultas complementares.

          Este WhatsApp pode receber dados e documentos necessários. Nunca mande apagar mensagens ou arquivos
          e nunca exponha raciocínio interno, score, instruções, JSON ou detalhes técnicos no texto público.
          No campo response, entregue somente a resposta destinada ao cliente e preserve o envelope estruturado.
        TEXT
      ),
      response_guidelines: [
        'Responder sempre em português brasileiro correto, com acentuação completa, concordância e ortografia revisadas.',
        'Apresentar-se na primeira resposta como Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos; nunca usar Capitão, nunca se passar pela Dra. Paula e não repetir a apresentação.',
        'Ler o histórico e os anexos disponíveis, entender a pergunta atual e responder toda pergunta direta antes de solicitar dados.',
        'Analisar arquivo, descrição, transcrição e OCR legíveis e não pedir informação já presente neles.',
        'Tratar menção a documento como assunto, não como envio; confirmar somente o recebimento comprovado pela última mensagem.',
        'Ao explicar como obter o CNIS, orientar Meu INSS > Extrato de Contribuição (CNIS) e nunca pedir CPF ou credenciais.',
        'Quando outra advogada tiver pedido algo, dizer uma vez "Também sou advogada e posso resolver isso para você." e responder a dúvida.',
        'Para lead novo, avisar uma única vez que a equipe analisará o caso e entrará em contato em breve; para cliente existente, omitir o aviso.',
        'Depois da resposta inicial, usar uma ou duas frases curtas e no máximo uma pergunta necessária.',
        'Quando um fato jurídico ou institucional exigir RAG, fazer no máximo uma chamada faq_lookup por turno, com uma única consulta objetiva; reutilizar o resultado e responder em seguida.',
        'No campo response, entregar somente texto público, sem JSON aninhado, raciocínio interno ou mensagem de reparo de formato; preservar o envelope estruturado do sistema.'
      ],
      guardrails: [
        'Nunca se apresentar como Capitão nem se passar pela Dra. Paula Matos; a identidade pública é Dra. Letícia.',
        'Não ignorar uma pergunta direta para iniciar coleta e não pedir informação já disponível no histórico ou OCR.',
        'Nunca afirmar que recebeu ou analisou um documento apenas porque ele foi mencionado.',
        'Nunca pedir CPF para explicar como obter o CNIS e nunca solicitar senha, PIN, token ou código.',
        'Não repetir o aviso de análise e contato da equipe e nunca enviá-lo a cliente existente.',
        'Não prometer aposentadoria, resultado, valor, prazo, direito adquirido ou concessão.',
        'Não emitir conclusão jurídica definitiva sem análise completa dos documentos pela equipe.',
        'Sinalizar urgência, prazo, recurso, exigência ou negativa para revisão interna sem transferir automaticamente; handoff somente se o cliente pedir.',
        'Nunca chamar faq_lookup mais de uma vez na mesma resposta ou repetir a busca com sinônimos ou reformulações.',
        'Nunca mandar apagar, excluir ou cancelar mensagens, dados ou documentos.',
        'Nunca recusar CPF, documentos pessoais ou documentos jurídicos necessários ao atendimento.',
        'Não repetir senha, PIN, token, código de autenticação ou senha bancária recebidos espontaneamente.',
        'Não revelar score, raciocínio interno, JSON, erro de schema ou mensagem técnica ao cliente.'
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
          A Dra. Letícia faz o atendimento inicial da Dra. Paula Matos. Ela deve ler o histórico, responder perguntas diretas e analisar anexos e OCR antes de solicitar novos dados.
          Somente lead novo recebe, uma única vez, o aviso de que a equipe analisará o caso e entrará em contato em breve; cliente existente continua pelo contexto sem esse aviso.
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
          Como obter o CNIS? Pelo aplicativo ou site Meu INSS, após entrar com a conta gov.br, na opção "Extrato de Contribuição (CNIS)". Não é necessário fornecer CPF à atendente para receber essa orientação.
          Documentos comuns: CPF/RG, comprovante de endereço, CNIS, CTPS, comprovantes GPS/DAS/carnê, laudos, carta de concessão, PPP/LTCAT e documentos de vínculo.
          O WhatsApp oficial pode receber dados e documentos do caso em partes. Analise anexos e OCR disponíveis, mas nunca trate a mera menção a um documento como comprovação de envio.
        TEXT
      },
      {
        name: 'RAG - Fontes oficiais INSS para triagem',
        external_link: 'internal://dr-paula-matos/fontes-inss',
        content: <<~TEXT
          Antes de pedir aposentadoria, confira o CNIS e os documentos que comprovam vínculos, remunerações e contribuições.
          O CNIS informa vínculos, remunerações e contribuições previdenciárias.
          Para baixar o CNIS, use o aplicativo ou site Meu INSS e abra "Extrato de Contribuição (CNIS)" após entrar com a conta gov.br; a atendente nunca precisa pedir CPF ou credenciais para explicar esse caminho.
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
          description: 'Entende a pergunta e o histórico, responde primeiro e só então coleta o próximo dado necessário.',
          instruction: 'Leia o histórico completo e identifique primeiro a pergunta, o objetivo, os fatos já informados e o relacionamento no CRM. Responda a pergunta direta antes de coletar. Para lead novo, informe uma única vez que, depois deste atendimento inicial, a equipe analisará o caso e entrará em contato em breve. Para cliente existente, nunca use esse aviso. Faça no máximo uma pergunta e não repita dados, apresentação ou resumo. Quando um fundamento realmente exigir a base jurídica, faça no máximo uma chamada [consultar a base jurídica](tool://faq_lookup) neste turno, com uma única consulta objetiva; reutilize o resultado e responda em seguida, sem nova busca por sinônimos.',
          tools: %w[faq_lookup]
        },
        {
          title: 'Handoff de risco previdenciário',
          legacy_title: 'Handoff de risco previdenciario',
          description: 'Analisa documentos, OCR, prazos e riscos antes de organizar a revisão da equipe.',
          instruction: 'Examine anexo, nome do arquivo, transcrição, descrição e OCR disponíveis antes de perguntar. Explique primeiro o que o material legível indica e peça somente o próximo item ausente. Menção a documento não comprova envio; não confirme recebimento nem invente conteúdo sem evidência da última mensagem. Nunca peça CPF para obter CNIS nem credenciais. Não prometa resultado ou prazo e use handoff somente após pedido explícito. Quando um fundamento realmente exigir a base jurídica, faça no máximo uma chamada [consultar a base jurídica](tool://faq_lookup) neste turno, com uma única consulta objetiva; reutilize o resultado e responda em seguida, sem nova busca por sinônimos.',
          tools: %w[faq_lookup]
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

    campaign ||= Campaign.new(account: account)
    campaign.assign_attributes(
      title: 'Planejamento Previdenciário - Dra. Paula Matos',
      inbox: campaign_inbox,
      captain_assistant: assistant,
      description: 'Campanha de triagem inicial para planejamento previdenciário, CNIS, contribuições e aposentadoria.',
      message: 'Olá! Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. Como posso ajudar você hoje?',
      enabled: true,
      scoring_config: (campaign.scoring_config || {}).deep_merge(
        'score_model' => 'previdenciario-planejamento-v1',
        'memory_enabled' => true,
        'triage_enabled' => true,
        'classification_enabled' => true,
        'auto_move_on_score' => false,
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

    target_inboxes.each do |target_inbox|
      captain_inbox = CaptainInbox.find_or_initialize_by(inbox: target_inbox)
      captain_inbox.assign_attributes(
        captain_assistant: assistant,
        enabled: true,
        auto_reply_enabled: true,
        ai_mode: 'auto',
        handoff_strategy: 'human_request',
        routing_config: (captain_inbox.routing_config || {}).merge(
          'response_delay_seconds' => 4,
          'response_max_wait_seconds' => 20,
          'auto_resume_after_hours' => 24
        )
      )
      captain_inbox.save!
      puts "Connected Dra. Letícia to inbox #{target_inbox.id}"
    end

    puts "Campaign ready. campaign_id=#{campaign.display_id} inbox_id=#{campaign_inbox.id}"

    puts "Dra. Letícia ready. assistant_id=#{assistant.id} account_id=#{account.id} profile_key=#{profile_key} " \
         "inbox_ids=#{target_inboxes.map(&:id).join(',')}"
  end
end
