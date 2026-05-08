# frozen_string_literal: true

# Gera embeddings para documentos e FAQ da Dra Juliana via Gemini.

assistant = Captain::Assistant.find_by(name: 'Dra Juliana - Triagem Jurídica')
raise 'Dra Juliana não encontrada' unless assistant

account_id = assistant.account_id
service = Captain::Llm::EmbeddingService.new(account_id: account_id)

puts "=== Documentos (#{assistant.documents.count}) ==="
assistant.documents.find_each do |doc|
  content = "#{doc.name}\n\n#{doc.content}"
  embedding = service.get_embedding(content)
  doc.update!(embedding: embedding, status: :available)
  puts "  ##{doc.id} #{doc.name[0..45]} | embedding: #{embedding ? "#{embedding.size} dims" : 'nil'}"
rescue StandardError => e
  puts "  ##{doc.id} ERRO: #{e.class}: #{e.message[0..150]}"
end

puts
puts "=== FAQ Responses (#{assistant.responses.count}) ==="
assistant.responses.find_each do |resp|
  content = "#{resp.question}\n#{resp.answer}"
  embedding = service.get_embedding(content)
  resp.update!(embedding: embedding)
  print '.'
rescue StandardError => e
  print 'X'
  Rails.logger.warn "FAQ ##{resp.id} embedding falhou: #{e.message}"
end

puts
puts
puts "=== Resumo final ==="
puts "Docs com embedding: #{assistant.documents.where.not(embedding: nil).count}/#{assistant.documents.count}"
puts "FAQ com embedding:  #{assistant.responses.where.not(embedding: nil).count}/#{assistant.responses.count}"
