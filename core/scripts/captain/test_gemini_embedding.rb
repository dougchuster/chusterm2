# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

key = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_API_KEY').value
endpoint = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_ENDPOINT').value
model = InstallationConfig.find_by(name: 'CAPTAIN_EMBEDDING_MODEL').value

puts "Endpoint: #{endpoint}"
puts "Model: #{model}"
puts "Key: #{key.to_s[0..15]}..."
puts

uri = URI("#{endpoint.chomp('/')}/models/#{model}:embedContent?key=#{key}")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
req.body = { content: { parts: [{ text: 'teste embedding Dra Juliana' }] } }.to_json

res = http.request(req)
puts "Status: #{res.code}"

if res.code == '200'
  data = JSON.parse(res.body)
  vec = data.dig('embedding', 'values')
  if vec
    puts "Gemini embedding OK: dimensoes=#{vec.size}"
    puts "Primeiros valores: #{vec.first(3).map { |v| v.round(4) }}"
  else
    puts "Resposta sem embedding: #{data.inspect[0..300]}"
  end
else
  puts "FALHA: #{res.body[0..500]}"
end
