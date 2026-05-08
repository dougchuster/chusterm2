# frozen_string_literal: true

assistant = Captain::Assistant.find_by(name: 'Dra Juliana - Triagem Jurídica')

puts "=== Verificação Captain Dra Juliana ==="
puts "Account: ##{assistant.account_id} #{assistant.account.name}"
puts "Assistant: ##{assistant.id} #{assistant.name}"
puts

puts "FAQ Responses:"
total_responses = assistant.responses.count
with_embedding = assistant.responses.where.not(embedding: nil).count
puts "  Total: #{total_responses}"
puts "  Com embedding: #{with_embedding}"
puts

# Pega primeiro response com embedding e mede a dimensão
sample = assistant.responses.where.not(embedding: nil).first
if sample
  vec = sample.embedding.is_a?(Array) ? sample.embedding : sample.embedding.to_a
  puts "  Dimensões da embedding: #{vec.size}"
  puts "  Primeiros valores: #{vec.first(3).map { |v| v.round(4) }}"
end
puts

puts "Documentos:"
puts "  Total: #{assistant.documents.count}"
puts "  Status:"
assistant.documents.group(:status).count.each { |s, c| puts "    #{s}: #{c}" }
puts "  Responses por documento (chunks):"
assistant.documents.find_each do |doc|
  count = Captain::AssistantResponse.where(documentable_type: 'Captain::Document', documentable_id: doc.id).count
  puts "    ##{doc.id} #{doc.name[0..40]} -> #{count} responses"
end
puts

puts "Scenario:"
assistant.scenarios.each do |s|
  puts "  ##{s.id} #{s.title} | enabled: #{s.enabled} | tools: #{s.tools}"
end
puts

puts "Config principal:"
puts "  Welcome: #{assistant.config['welcome_message']}"
puts "  Temperature: #{assistant.config['temperature']}"
puts "  Features: faq=#{assistant.config['feature_faq']} memory=#{assistant.config['feature_memory']} contact_attrs=#{assistant.config['feature_contact_attributes']}"
puts

puts "Captain features na account: #{assistant.account.enabled_features.select { |k, v| v && k.to_s.start_with?('captain') }.keys}"
