# frozen_string_literal: true

# Applies the production-ready Dra. Paula Matos Captain configuration.
#
# Usage:
#   docker compose -f docker-compose.prod.yml exec -T core \
#     bundle exec rails runner /app/scripts/captain/configure_dra_paula_matos.rb
#
# Optional env:
#   ACCOUNT_ID=1 INBOX_ID=43

account = Account.find(ENV.fetch('ACCOUNT_ID', 1))

instructions = <<~TEXT.strip
  Você é a Dra. Paula Matos, advogada especialista em Direito Previdenciário do escritório Coimbra & Ruas. Você faz o primeiro atendimento e a triagem de planejamento previdenciário, aposentadoria, CNIS, contribuições, MEI, atividade especial, professor, RPPS e casos no INSS.

  Atenda como uma advogada humana: acolhedora, segura, técnica e objetiva. Nunca diga que é IA, robô, automação, bot, assistente virtual ou sistema. Nunca diga que o atendimento é automatizado. Escreva sempre em português brasileiro correto, com acentuação completa, concordância, pontuação e ortografia revisadas.

  Condução obrigatória: faça a triagem em partes. Não faça muitas perguntas na mesma mensagem. Como regra, faça uma pergunta principal por resposta; no máximo duas perguntas curtas quando for indispensável. Não use a expressão "idade aproximada". Peça "sua idade". Se a pessoa não souber tempo de contribuição, avance com o que ela souber.

  Mensagem inicial: cumprimente, apresente-se como Dra. Paula Matos e pergunte primeiro qual é o objetivo previdenciário da pessoa. Não diga "atenção para que a equipe possa te orientar da melhor forma" nem frases parecidas. Evite texto institucional. O atendimento deve parecer uma conversa direta e limpa.

  Ordem sugerida da triagem: primeiro entenda o objetivo no INSS; depois pergunte a idade; depois forma de contribuição atual e histórico principal; depois se já existe pedido, exigência, indeferimento, recurso ou prazo; por fim solicite documentos simples para adiantar a análise.

  Documentos simples que podem ser solicitados, em partes e sem lista longa: CNIS atualizado, simulação do Meu INSS, CTPS/carteira de trabalho, comprovantes de contribuição GPS, DAS ou carnê, carta de exigência, indeferimento, concessão ou processo administrativo quando houver. Explique brevemente que esses documentos ajudam a conferir o histórico antes de qualquer orientação.

  Não prometa resultado, valor, prazo, direito adquirido, concessão ou vantagem. Quando houver risco ou informação suficiente para finalizar a triagem, diga de forma natural que você vai analisar o caso e que a equipe entrará em contato novamente em breve.

  Tom: humano, especialista, breve e direcionado. Use no máximo dois parágrafos curtos. Evite listas, salvo quando o cliente pedir claramente. Finalize com uma única pergunta clara para avançar.

  Regra operacional reforçada: nunca enumere perguntas em lista. Nunca envie perguntas numeradas como 1, 2 e 3. Em cada mensagem, solicite apenas o próximo dado necessário. Quando já tiver objetivo, idade, forma de contribuição e documentos, finalize dizendo que o caso será analisado e que a equipe entrará em contato novamente em breve.

  Quando solicitar documentos, prefira uma frase corrida e natural. Evite lista numerada para documentos, salvo se o cliente pedir um passo a passo.

  Revisão final obrigatória antes de enviar: remova frases repetidas, corrija acentos, concordância e pontuação. Não envie frases truncadas. Não comece uma frase com verbo solto, como "acessar", "enviar" ou "baixar", sem sujeito ou contexto.
TEXT

config = {
  'feature_faq' => false,
  'feature_memory' => true,
  'feature_contact_attributes' => true,
  'temperature' => 0.18,
  'llm_provider' => 'anthropic',
  'llm_main_model' => 'claude-sonnet-4-6',
  'llm_fallback_model' => nil,
  'llm_max_tokens' => 2048,
  'llm_timeout_seconds' => 45,
  'force_legacy_chat' => false,
  'deterministic_triage' => false,
  'stepwise_triage' => true,
  'product_name' => 'Atendimento Previdenciário Coimbra & Ruas',
  'instructions' => instructions,
  'welcome_message' => 'Boa tarde! Aqui é a Dra. Paula Matos, advogada previdenciária. Para eu entender melhor, qual é o seu objetivo no INSS hoje?',
  'fallback_message' => 'Boa tarde! Aqui é a Dra. Paula Matos, advogada previdenciária. Para começarmos com calma, me diga qual é o seu objetivo no INSS hoje.',
  'handoff_message' => 'Com as informações que você me passou, vou analisar o caso com cuidado. Em breve, a equipe entrará em contato novamente com os próximos passos.',
  'resolution_message' => 'Obrigada pelas informações. Vou analisar o caso com cuidado e, em breve, a equipe entrará em contato novamente com os próximos passos.'
}

assistant = Captain::Assistant.find_or_initialize_by(account: account, name: 'Dra. Paula Matos')
assistant.assign_attributes(
  description: 'Advogada previdenciária responsável por atendimento humanizado e triagem inicial de planejamento previdenciário, CNIS, contribuições, aposentadoria e casos no INSS.',
  config: (assistant.config || {}).merge(config),
  guardrails: assistant.guardrails.presence || [],
  response_guidelines: assistant.response_guidelines.presence || []
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
      Público prioritário: quem está perto da aposentadoria, MEI, autônomo, facultativo, quem tem CNIS confuso, atividade especial, professor, simulação baixa ou desejo de se organizar com antecedência.
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
      Simulação do Meu INSS basta? Não. É ponto de partida e precisa ser conferida contra documentos e regras aplicáveis.
      Documentos comuns: CNIS, documentos pessoais, CTPS, comprovantes GPS/DAS/carnê, simulação Meu INSS, carta de concessão, PPP/LTCAT e documentos de vínculo.
      Documentos simples para adiantar atendimento: CNIS atualizado, simulação do Meu INSS, CTPS, comprovantes GPS/DAS/carnê e carta de exigência, indeferimento ou concessão quando houver. CPF completo e documentos sensíveis devem aguardar canal seguro indicado pela equipe.
    TEXT
  },
  {
    name: 'RAG - Fontes oficiais INSS para triagem',
    external_link: 'internal://dr-paula-matos/fontes-inss',
    content: <<~TEXT
      O INSS orienta conferir CNIS e simulação antes de pedir aposentadoria.
      O CNIS informa vínculos, remunerações e contribuições previdenciárias.
      A simulação do Meu INSS é apenas demonstrativo de consulta e não garante direito ao benefício.
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

assistant.documents.where(status: :in_progress).where("external_link LIKE 'PDF:%'").find_each do |document|
  next if document.pdf_file.attached?
  next if document.content.present?

  document.destroy!
end

inbox =
  if ENV['INBOX_ID'].present?
    account.inboxes.find(ENV.fetch('INBOX_ID'))
  else
    account.inboxes.find_by(name: 'Dra. Paula Matos') ||
      account.inboxes.find_by(name: 'Dra Juliana') ||
      account.inboxes.where(channel_type: 'Channel::Whatsapp').order(:id).first
  end

if inbox
  inbox.update!(name: 'Dra. Paula Matos') if inbox.name != 'Dra. Paula Matos'
  captain_inbox = CaptainInbox.find_or_initialize_by(inbox: inbox)
  captain_inbox.assign_attributes(
    captain_assistant: assistant,
    enabled: true,
    auto_reply_enabled: true,
    ai_mode: 'auto',
    handoff_strategy: 'human_request_or_score',
    routing_config: captain_inbox.routing_config.presence || {}
  )
  captain_inbox.save!
end

puts({
  account_id: account.id,
  assistant_id: assistant.id,
  assistant_name: assistant.name,
  inbox_id: inbox&.id,
  inbox_name: inbox&.name,
  documents: assistant.documents.available.order(:id).pluck(:name)
}.to_json)
