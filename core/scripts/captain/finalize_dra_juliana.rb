# frozen_string_literal: true

assistant = Captain::Assistant.find_by(name: 'Dra Juliana - Triagem Jurídica')
account = assistant.account

# 1. Marca todos os documentos como available
assistant.documents.update_all(status: Captain::Document.statuses[:available])
puts "Status de #{assistant.documents.count} documentos -> available"

# 2. Cria response chunks (Q&A pairs) ligados aos documentos para vector search
# Cada chunk vira um Captain::AssistantResponse com documentable_type/id apontando ao Document.
# O after_commit :update_response_embedding gera o embedding automaticamente via Gemini.

# Limpa chunks antigos vinculados aos documentos
Captain::AssistantResponse.where(
  assistant_id: assistant.id,
  documentable_type: 'Captain::Document'
).destroy_all

document_chunks = {
  'Dados oficiais' => [
    ['Qual é o nome oficial do escritório?', 'O nome oficial é Coimbra e Ruas Advocacia. O escritório atua desde 2019, com atendimento nacional.'],
    ['Qual é o WhatsApp prioritário?', 'O WhatsApp prioritário é +55 (61) 99337-4530.'],
    ['Quais são os telefones do escritório?', 'Os telefones são (61) 99337-4530 e (61) 3522-7333.'],
    ['Qual é o e-mail do escritório?', 'O e-mail de contato é contato@coimbraeruas.com.br.'],
    ['Qual é o endereço?', 'Le Quartier - Águas Claras, Av. Pau Brasil, Lote 10 - Sala 438, Brasília/DF, CEP 71926-000.'],
    ['Quais áreas o escritório atende?', 'O escritório atende Direito Criminal, Direito Civil, Direito Trabalhista, Direito de Família e Direito Previdenciário.'],
    ['Qual o horário de atendimento?', 'Atendimento em horário comercial de segunda a sexta. Para urgências, há suporte 24/7 via +55 61 99970-4777.']
  ],
  'Equipe oficial' => [
    ['Quem é Ingrid Ruas?', 'Ingrid Ruas é advogada especialista em Direito Civil, contratos e processo civil. É aluna especial no mestrado da UNB. Destaque para ética, transparência, empatia e estratégias personalizadas.'],
    ['Quem é Sávia Coimbra?', 'Sávia Coimbra é advogada especialista em Direito Civil — contratos, responsabilidade civil, direitos reais, família, sucessões e resolução extrajudicial. Mestra em Ciência Política.'],
    ['Quem é Paula Matos Andrade?', 'Paula Matos Andrade é advogada especialista em Direito Previdenciário. Atua com defesa contra fraudes bancárias contra idosos, planejamentos previdenciários, RGPS, RPPS e auxílio-maternidade.'],
    ['Quem é Leticia Miguel de Morais?', 'Leticia Miguel de Morais é advogada especialista em Direito do Trabalho (consultivo e litigioso) e Direito Processual Civil.'],
    ['Quem é Amanda Sousa Fernandes?', 'Amanda Sousa Fernandes é advogada com atuação em Direito de Família, inventários, contencioso civil, consultivo, execuções, Consumidor e Trânsito. Bacharelado em Direito, pós em Residência Jurídica e fluência em inglês.'],
    ['Quem é Ismael de A. Coimbra Santos?', 'Ismael de A. Coimbra Santos é assistente jurídico, acadêmico do 5º semestre de Direito (UCB). Atua em suporte técnico, operacional, pesquisa e organização. Fluente em inglês.'],
    ['Como responder pergunta genérica sobre equipe?', 'Para perguntas genéricas, listar somente nomes e funções: Ingrid Ruas, Sávia Coimbra, Paula Matos Andrade, Leticia Miguel de Morais e Amanda Sousa Fernandes (advogadas); Ismael de A. Coimbra Santos (assistente jurídico). Detalhes apenas se perguntarem sobre alguém específico.']
  ],
  'Manual de triagem objetiva' => [
    ['Como abrir uma conversa de triagem?', 'Abertura recomendada: "Olá. Sou a Dra. Juliana, advogada do Coimbra e Ruas Advocacia. Como posso te ajudar hoje?". Tom objetivo, profissional e direto, sem acolhimento emocional.'],
    ['O que fazer durante a triagem?', 'Perguntar nome se ainda não houver, pedir explicação do que aconteceu, classificar área internamente, fazer perguntas abertas e objetivas, coletar objetivo/fatos/etapa/datas/prazos/envolvidos/urgência, e só ao final pedir documentos pertinentes.'],
    ['O que NÃO fazer durante a triagem?', 'Não pedir documentos no começo. Não confirmar classificação jurídica em voz alta. Não usar múltipla escolha. Não emitir parecer. Não prometer resultado. Não citar valores. Não usar emoji/Markdown/negrito. Não inventar informações.']
  ],
  'FAQ institucional' => [
    ['Atendem auxílio-maternidade?', 'Sim. Auxílio-maternidade é uma demanda de Direito Previdenciário atendida pelo Coimbra e Ruas Advocacia e pode ser encaminhada para a Dra. Paula.'],
    ['Como funciona o atendimento de Direito do Consumidor?', 'Demandas de consumidor podem ser analisadas dentro de Direito Civil, conforme o caso.'],
    ['Como funciona casos imobiliários?', 'Demandas imobiliárias podem ser analisadas dentro de Direito Civil.'],
    ['Quanto custa um processo?', 'O time jurídico vai te orientar sobre isso pessoalmente após analisar o caso.'],
    ['Tenho direito a algo?', 'A triagem não emite parecer jurídico. A Dra. Juliana precisa entender melhor os fatos antes de encaminhar para análise técnica.'],
    ['Posso enviar documentos agora?', 'Sim, mas a solicitação de documentos ocorre depois da triagem inicial, quando o caso já estiver minimamente compreendido.']
  ]
}

doc_by_keyword = assistant.documents.index_by { |d| d.name.split(' - ').first.strip }

total_chunks = 0
document_chunks.each do |doc_keyword, qa_pairs|
  doc = doc_by_keyword[doc_keyword]
  next unless doc

  qa_pairs.each do |question, answer|
    Captain::AssistantResponse.create!(
      assistant: assistant,
      account: account,
      question: question,
      answer: answer,
      status: :approved,
      documentable: doc
    )
    total_chunks += 1
  end
  puts "  Doc ##{doc.id} #{doc.name[0..40]}: #{qa_pairs.size} chunks"
end
puts "Total: #{total_chunks} response chunks criados (embeddings via after_commit)"

# 3. Re-aplica tools do scenario
scenario = assistant.scenarios.first
if scenario
  scenario.update!(
    tools: %w[add_private_note add_label_to_conversation update_priority faq_lookup handoff],
    enabled: true
  )
  scenario.reload
  puts "Scenario ##{scenario.id} tools: #{scenario.tools}"
end

# 4. Aguarda embeddings serem gerados (after_commit é síncrono no caminho aqui)
puts
puts "Aguardando geração dos embeddings dos chunks..."
sleep 2

# 5. Resumo final
total_resp = assistant.responses.count
with_emb = assistant.responses.where.not(embedding: nil).count
manual_q = assistant.responses.where(documentable_id: nil).count
doc_chunks = assistant.responses.where.not(documentable_id: nil).count

puts
puts "=== ESTADO FINAL ==="
puts "Documentos available: #{assistant.documents.where(status: :available).count}/#{assistant.documents.count}"
puts "Responses totais: #{total_resp}"
puts "  Manuais (FAQ direta): #{manual_q}"
puts "  Chunks de documentos: #{doc_chunks}"
puts "Responses com embedding: #{with_emb}/#{total_resp}"
puts "Scenario tools: #{scenario&.tools}"
