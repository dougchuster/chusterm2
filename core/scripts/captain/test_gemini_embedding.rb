# frozen_string_literal: true

# Historical filename retained for operator compatibility. Embeddings are now
# always generated through the unified OpenRouter gateway.
vector = Captain::Llm::EmbeddingService.new.get_embedding('teste embedding Dra Juliana')
raise "Unexpected embedding dimensions: #{vector.size}" unless vector.size == LlmConstants::DEFAULT_EMBEDDING_DIMENSIONS

puts 'OPENROUTER_EMBEDDING_OK=true'
puts "MODEL=#{Captain::Llm::EmbeddingService.embedding_model}"
puts "DIMENSIONS=#{vector.size}"
