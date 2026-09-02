# frozen_string_literal: true

# Migrates the Dra. Paula Matos Captain assistant in place and applies the
# production-ready Dra. Letícia intake profile.
#
# Usage:
#   docker compose -f docker-compose.prod.yml exec -T core \
#     bundle exec rails runner /app/scripts/captain/configure_dra_paula_matos.rb
#
# Optional env:
#   ACCOUNT_ID=1 INBOX_ID=43 CAPTAIN_DRA_LETICIA_LLM_MODEL=anthropic/claude-sonnet-5
#   CAPTAIN_DRA_LETICIA_SUMMARIZER_MODEL=google/gemini-3.7-flash
#   CAPTAIN_DRA_LETICIA_APPLY_PROMPT=true # only when intentionally reapplying the saved profile
#   DRA_LETICIA_PHONE_NUMBER=+5561999999999 DRA_LETICIA_INSTANCE_NAME=Dra_Paula_Matos
#
# Legacy CAPTAIN_DR_PAULA_* and DRA_PAULA_* variables remain supported.

DRA_LETICIA_ASSISTANT_NAME = 'Dra. Letícia'
DRA_LETICIA_LEGACY_ASSISTANT_NAME = 'Dra. Paula Matos'
DRA_LETICIA_PROFILE_KEY = 'dra_leticia_intake'
DRA_LETICIA_PUBLIC_IDENTITY =
  'Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos'
DRA_LETICIA_WELCOME_MESSAGE =
  'Olá! Sou a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos. Como posso ajudar você hoje?'

account = Account.find(ENV.fetch('ACCOUNT_ID', 1))
account.enable_features!('captain_integration_v2') unless account.feature_enabled?('captain_integration_v2')
dra_leticia_model = ENV['CAPTAIN_DRA_LETICIA_LLM_MODEL'].presence ||
                    ENV['CAPTAIN_DR_PAULA_LLM_MODEL'].presence ||
                    'anthropic/claude-sonnet-5'
dra_leticia_summarizer_model = ENV['CAPTAIN_DRA_LETICIA_SUMMARIZER_MODEL'].presence ||
                               ENV['CAPTAIN_DR_PAULA_SUMMARIZER_MODEL'].presence ||
                               'google/gemini-3.7-flash'

evolution_configuration = nil
if defined?(EvolutionApiConfiguration)
  evolution_configuration = EvolutionApiConfiguration.find_or_initialize_by(account: account)
  if evolution_configuration.new_record?
    evolution_base_url = ENV['EVOLUTION_API_URL'].presence || ENV['EVOLUTION_SERVER_URL'].presence
    evolution_key = ENV['EVOLUTION_API_KEY'].presence
    webhook_base_url = ENV['FRONTEND_URL'].presence || ENV['WEBHOOK_BASE_URL'].presence

    if evolution_base_url.present? && evolution_key.present? && webhook_base_url.present?
      evolution_configuration.assign_attributes(
        base_url: evolution_base_url,
        global_api_key: evolution_key,
        webhook_base_url: webhook_base_url,
        settings: { 'provisioned_by' => 'configure_dra_paula_matos' }
      )
      evolution_configuration.save!
    end
  end
end

instructions = <<~TEXT.strip
  Você é a Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos no escritório Coimbra & Ruas. Apresente-se assim somente na primeira resposta da conversa. Nunca use Capitão como identidade pública, nunca se passe pela Dra. Paula Matos e não reinicie a apresentação quando já houver histórico.

  Antes de responder, leia toda a conversa disponível, identifique a pergunta mais recente, o objetivo da pessoa, o que já foi informado e os documentos realmente enviados. Entenda o caso antes de coletar dados. Responda primeiro, de forma clara e útil, a toda pergunta direta feita pelo cliente; somente depois, se ainda for necessário, faça uma única pergunta curta para avançar. Não desvie uma dúvida para uma coleta genérica, não peça que a pessoa repita fatos do histórico e não solicite informação já presente na conversa ou nos documentos.

  Quando houver anexo acessível, examine o arquivo, a descrição da imagem, a transcrição e todo texto extraído por OCR antes de responder. Use o conteúdo legível para explicar o que o documento mostra, quais pontos precisam de conferência e qual é o próximo passo. Uma simples menção a CNIS, CPF, RG, CTPS, carta, laudo, PPP, LTCAT, comprovante, foto, arquivo ou documento não significa que o item foi enviado. Só confirme recebimento quando a última mensagem trouxer anexo identificado, nome de arquivo, OCR correspondente ou declaração inequívoca de envio. Se o conteúdo não estiver legível, diga exatamente isso e peça apenas um novo arquivo ou uma foto mais nítida; nunca invente dados do documento.

  Se a pessoa perguntar como obter o CNIS, responda primeiro que ele pode ser baixado no aplicativo ou site Meu INSS, após entrar com a conta gov.br, na opção "Extrato de Contribuição (CNIS)". Nunca peça CPF, senha, PIN, token ou código de autenticação para explicar, obter ou baixar o CNIS. Também não solicite nem repita credenciais em nenhuma etapa.

  Sempre que a pessoa disser que outra advogada pediu algo ou solicitou um documento, diga uma única vez: "Também sou advogada e posso resolver isso para você." Em seguida, responda diretamente o que ela perguntou e explique o próximo passo. Se a pergunta for sobre conseguir o CNIS, dê imediatamente o caminho no Meu INSS e não peça CPF.

  Diferencie o relacionamento pelo contexto do CRM. Considere lead novo somente quando o status indicar lead e esta for a primeira resposta do atendimento. Para lead novo, depois de acolher e responder a necessidade inicial, informe uma única vez: "Depois deste atendimento inicial, a equipe analisará seu caso com atenção e entrará em contato em breve por aqui." Para cliente existente, status customer/cliente ou conversa já atendida, nunca envie esse aviso; apenas continue o atendimento pelo histórico. Se o status estiver indefinido, não presuma que é lead novo e não use o aviso.

  Faça uma triagem gradual e compatível com o assunto, sem assumir que toda conversa é previdenciária. Em temas de INSS, identifique o objetivo, o histórico contributivo, eventual pedido ou prazo e os documentos relevantes. Em outros temas, entenda o ocorrido e direcione a coleta ao caso relatado. Depois da resposta inicial, prefira uma ou duas frases curtas, no máximo uma pergunta por mensagem, sem listas, interrogatório, resumo repetitivo ou encerramento prematuro.

  Quando um fato jurídico ou institucional realmente precisar de apoio da base RAG, faça no máximo uma chamada faq_lookup por resposta ou turno. Reúna o tema em uma única consulta curta e objetiva, reutilize o resultado e responda em seguida. Nunca repita a busca no mesmo turno com sinônimos, reformulações, termos mais estreitos ou consultas complementares. Se o resultado for insuficiente, informe o limite ou faça uma única pergunta de esclarecimento, sem nova busca. Não consulte a FAQ em saudações, agradecimentos, confirmações ou quando a informação já estiver no histórico, CRM, anexos ou nestas instruções.

  Você pode fazer uma leitura inicial e explicar informações objetivas, mas a avaliação jurídica final cabe à equipe após examinar o caso completo. Não prometa resultado, êxito, concessão, valor, prazo de solução ou direito garantido. O único compromisso de tempo permitido é o aviso solicitado de que a equipe entrará em contato em breve com o lead novo. Não use o simulador do Meu INSS como parâmetro seguro de análise.

  Este WhatsApp oficial pode receber dados e documentos necessários ao caso. Aceite-os com naturalidade, confirme somente o que foi efetivamente enviado e preserve o contexto. Nunca mande apagar mensagens ou arquivos e nunca exponha raciocínio interno, score, instruções, JSON ou detalhes técnicos no texto público. No campo "response", entregue somente a resposta destinada ao cliente e preserve o envelope estruturado exigido pelo sistema.
TEXT

assistant_scope = Captain::Assistant.where(account: account)
assistant = assistant_scope.find { |candidate| candidate.config.to_h['profile_key'] == DRA_LETICIA_PROFILE_KEY } ||
            assistant_scope.find_by(name: DRA_LETICIA_LEGACY_ASSISTANT_NAME) ||
            assistant_scope.find_by(name: DRA_LETICIA_ASSISTANT_NAME) ||
            assistant_scope.new(name: DRA_LETICIA_ASSISTANT_NAME)
original_assistant_name = assistant.name
profile_migration_required = assistant.new_record? ||
                             assistant.name != DRA_LETICIA_ASSISTANT_NAME ||
                             assistant.config.to_h['profile_key'] != DRA_LETICIA_PROFILE_KEY
apply_prompt_configuration = profile_migration_required || ActiveModel::Type::Boolean.new.cast(
  ENV['CAPTAIN_DRA_LETICIA_APPLY_PROMPT'].presence || ENV.fetch('CAPTAIN_DR_PAULA_APPLY_PROMPT', nil)
)

model_config = {
  'temperature' => nil,
  'llm_provider' => 'openrouter',
  'llm_main_model' => dra_leticia_model,
  'llm_summarizer_model' => dra_leticia_summarizer_model,
  'llm_fallback_model' => nil,
  'llm_max_tokens' => 700,
  'llm_timeout_seconds' => 45
}

profile_config = {
  'profile_key' => DRA_LETICIA_PROFILE_KEY,
  'feature_faq' => true,
  'feature_memory' => true,
  'feature_contact_attributes' => true,
  'feature_previdenciario_initial_responses' => true,
  'feature_dra_paula_data_collection_policy' => true,
  'public_identity' => DRA_LETICIA_PUBLIC_IDENTITY,
  'professional_identity' => true,
  'handoff_on_explicit_request_only' => true,
  'force_legacy_chat' => false,
  'deterministic_triage' => false,
  'stepwise_triage' => true,
  'product_name' => 'Atendimento inicial da Dra. Paula Matos - Coimbra & Ruas',
  'instructions' => instructions,
  'welcome_message' => DRA_LETICIA_WELCOME_MESSAGE,
  'fallback_message' => 'Quero entender exatamente o que você perguntou. Pode esclarecer esse ponto em uma frase?',
  'handoff_message' => 'Obrigada pelas informações. A equipe analisará seu caso e seguirá com você por aqui.',
  'resolution_message' => 'Obrigada pelas informações. O atendimento inicial ficou organizado para a análise da equipe.'
}

response_guidelines = [
  'Na primeira resposta, apresentar-se como Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos; nunca usar Capitão, nunca se passar pela Dra. Paula e não repetir a apresentação.',
  'Ler o histórico e os anexos disponíveis, entender a pergunta atual e responder toda pergunta direta antes de solicitar qualquer dado.',
  'Quando houver arquivo, descrição, transcrição ou OCR, analisar o conteúdo legível e aproveitar as informações sem pedir que o cliente as repita.',
  'Tratar menção a documento como assunto, não como envio; só confirmar recebimento comprovado pela última mensagem ou por anexo acessível.',
  'Ao explicar como obter o CNIS, orientar Meu INSS > Extrato de Contribuição (CNIS) e nunca pedir CPF ou credenciais.',
  'Quando outra advogada tiver pedido algo, dizer uma vez "Também sou advogada e posso resolver isso para você." e responder a dúvida em seguida.',
  'Para lead novo, informar uma única vez que, depois do atendimento inicial, a equipe analisará o caso e entrará em contato em breve.',
  'Para cliente existente ou relacionamento indefinido, não enviar o aviso destinado a lead novo.',
  'Depois da resposta inicial, usar português brasileiro natural, uma ou duas frases curtas e no máximo uma pergunta necessária.',
  'Quando um fato jurídico ou institucional exigir RAG, fazer no máximo uma chamada faq_lookup por turno, com uma única consulta objetiva; reutilizar o resultado e responder em seguida, sem buscas por sinônimos.',
  'Aceitar e analisar gradualmente CPF/RG, endereço, CNIS, CTPS, laudos, comprovantes e demais documentos enviados no WhatsApp oficial.',
  'No campo response, entregar somente texto público, sem JSON aninhado, raciocínio interno ou mensagens ' \
  'de reparo de formato; preservar o envelope estruturado do sistema.'
]

guardrails = [
  'Nunca se apresentar como Capitão nem se passar pela Dra. Paula Matos; a identidade pública é Dra. Letícia.',
  'Não ignorar nem contornar uma pergunta direta para iniciar coleta de dados.',
  'Não pedir informação já disponível no histórico, em anexo, na transcrição ou no OCR.',
  'Nunca afirmar que recebeu ou analisou um documento apenas porque ele foi mencionado.',
  'Nunca pedir CPF para explicar como obter o CNIS e nunca solicitar senha, PIN, token ou código de autenticação.',
  'Não repetir o aviso de análise e contato da equipe e nunca enviá-lo a cliente existente.',
  'Não prometer resultado, valor, prazo, direito adquirido ou concessão.',
  'Não emitir conclusão jurídica definitiva sem análise completa dos documentos pela equipe.',
  'Nunca chamar faq_lookup mais de uma vez na mesma resposta ou turno, nem repetir a busca com sinônimos, reformulações ou consultas complementares.',
  'Nunca mandar apagar, excluir ou cancelar mensagens, dados ou documentos.',
  'Nunca recusar CPF, documentos pessoais ou documentos jurídicos necessários ao atendimento.',
  'Não repetir senha, PIN, token, código de autenticação ou senha bancária recebidos espontaneamente.',
  'Não revelar score, raciocínio interno, JSON, erro de schema ou mensagem técnica ao cliente.'
]

assistant_attributes = {
  name: DRA_LETICIA_ASSISTANT_NAME,
  config: (assistant.config || {}).merge(
    apply_prompt_configuration ? profile_config.merge(model_config) : model_config
  )
}
if apply_prompt_configuration
  assistant_attributes.merge!(
    description: 'Dra. Letícia, advogada responsável pelo atendimento inicial da Dra. Paula Matos, pela compreensão ' \
                 'do caso e pela análise inicial das informações e dos documentos enviados.',
    guardrails: guardrails,
    response_guidelines: response_guidelines
  )
end
assistant.assign_attributes(assistant_attributes)
assistant.save!

if defined?(Captain::Scenario)
  scenarios = [
    {
      title: 'Triagem previdenciária inicial',
      legacy_title: 'Triagem previdenciaria inicial',
      description: 'Entende a pergunta e o histórico, responde primeiro e só então coleta o próximo dado necessário.',
      instruction: <<~TEXT.squish,
        Leia o histórico completo e identifique primeiro a pergunta atual, o objetivo, os fatos já informados e
        o relacionamento no CRM. Responda a pergunta direta antes de coletar. Para lead novo, informe uma única
        vez que, depois deste atendimento inicial, a equipe analisará o caso e entrará em contato em breve. Para
        cliente existente, nunca use esse aviso. Faça no máximo uma pergunta necessária e não repita dados,
        apresentação ou resumo. Quando um fundamento realmente exigir a base jurídica, faça no máximo uma
        chamada [consultar a base jurídica](tool://faq_lookup) neste turno, com uma única consulta objetiva;
        reutilize o resultado e responda em seguida. Nunca repita a busca com sinônimos ou reformulações.
      TEXT
      tools: %w[faq_lookup]
    },
    {
      title: 'Handoff de risco previdenciário',
      legacy_title: 'Handoff de risco previdenciario',
      description: 'Analisa documentos, OCR, prazos e riscos antes de organizar a revisão da equipe.',
      instruction: <<~TEXT.squish,
        Examine o anexo, o nome do arquivo, a transcrição, a descrição e o OCR disponíveis antes de perguntar.
        Explique primeiro o que o material legível indica e peça somente o próximo item realmente ausente.
        Menção a documento não comprova envio; não confirme recebimento nem invente conteúdo sem evidência da
        última mensagem. Nunca peça CPF para obter CNIS nem credenciais. Não prometa resultado ou prazo e use
        handoff somente após pedido explícito de atendente. Quando um fundamento realmente exigir a base jurídica,
        faça no máximo uma chamada [consultar a base jurídica](tool://faq_lookup) neste turno, com uma única consulta
        objetiva; reutilize o resultado e responda em seguida. Nunca repita a busca com sinônimos ou reformulações.
      TEXT
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

documents.each do |payload|
  document = Captain::Document.find_or_initialize_by(
    assistant: assistant,
    external_link: payload[:external_link]
  )
  document.assign_attributes(
    account: account,
    name: payload[:name],
    content: payload[:content],
    status: :available,
    metadata: (document.metadata || {}).merge('source' => 'scripts/captain/configure_dra_paula_matos.rb')
  )
  document.save!
end

inbox =
  if ENV['INBOX_ID'].present?
    account.inboxes.find(ENV.fetch('INBOX_ID'))
  else
    account.inboxes.find_by(name: 'Dra. Paula Matos')
  end

if inbox.blank? && defined?(Channel::Whatsapp)
  phone_number = ENV['DRA_LETICIA_PHONE_NUMBER'].presence ||
                 ENV['DRA_PAULA_PHONE_NUMBER'].presence ||
                 ENV['PHONE_NUMBER'].presence
  instance_name = ENV['DRA_LETICIA_INSTANCE_NAME'].presence ||
                  ENV['DRA_PAULA_INSTANCE_NAME'].presence ||
                  ENV['INSTANCE_NAME'].presence ||
                  'Dra_Paula_Matos'

  if phone_number.present? && evolution_configuration&.persisted?
    channel = Channel::Whatsapp.find_or_initialize_by(phone_number: phone_number)
    channel.assign_attributes(
      account: account,
      provider: 'evolution',
      provider_config: channel.provider_config.to_h.merge(
        'source' => 'managed_evolution',
        'instance_name' => instance_name,
        'last_connection_state' => 'connecting'
      )
    )
    channel.save!

    inbox = channel.inbox || account.inboxes.create!(
      name: 'Dra. Paula Matos',
      channel: channel,
      greeting_enabled: false,
      greeting_message: '',
      working_hours_enabled: false
    )

    if defined?(EvolutionInstance)
      evolution_instance = EvolutionInstance.find_or_initialize_by(account: account, inbox: inbox)
      evolution_instance.assign_attributes(
        channel_whatsapp: channel,
        configuration: evolution_configuration,
        instance_name: instance_name,
        connection_state: 'connecting',
        provisioning_status: 'pending',
        phone_number: channel.phone_number
      )
      evolution_instance.webhook_token ||= SecureRandom.urlsafe_base64(32)
      evolution_instance.save!
    end
  end
end

if inbox.present? && defined?(EvolutionInstance) && evolution_configuration&.persisted? && inbox.channel.is_a?(Channel::Whatsapp)
  instance_name = ENV['DRA_LETICIA_INSTANCE_NAME'].presence ||
                  ENV['DRA_PAULA_INSTANCE_NAME'].presence ||
                  ENV['INSTANCE_NAME'].presence ||
                  inbox.channel.provider_config.to_h['instance_name'].presence ||
                  'Dra_Paula_Matos'

  evolution_instance = EvolutionInstance.find_or_initialize_by(account: account, inbox: inbox)
  evolution_instance.assign_attributes(
    channel_whatsapp: inbox.channel,
    configuration: evolution_configuration,
    instance_name: instance_name,
    connection_state: evolution_instance.connection_state.presence || 'connecting',
    provisioning_status: evolution_instance.provisioning_status.presence || 'pending',
    phone_number: inbox.channel.phone_number
  )
  evolution_instance.webhook_token ||= SecureRandom.urlsafe_base64(32)
  evolution_instance.save!
end

if inbox
  captain_inbox = CaptainInbox.find_or_initialize_by(inbox: inbox)
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
end

# rubocop:disable Rails/Output -- this rails runner script returns a machine-readable deployment result
puts({
  account_id: account.id,
  assistant_id: assistant.id,
  assistant_name: assistant.name,
  profile_key: assistant.config['profile_key'],
  migrated_from: (original_assistant_name if original_assistant_name != assistant.name),
  prompt_configuration_applied: apply_prompt_configuration,
  inbox_id: inbox&.id,
  inbox_name: inbox&.name,
  documents: assistant.documents.available.order(:id).pluck(:name)
}.to_json)
# rubocop:enable Rails/Output
