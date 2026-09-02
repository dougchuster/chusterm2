# RubyLLM 1.9.2 emite "strict": true DENTRO do JSON Schema, em
# `to_json_schema[:schema]`. Esse lugar é inválido: `strict` pertence ao
# envelope `response_format.json_schema`, não ao schema em si — e o provider
# openai/chat.rb já o coloca lá corretamente, a partir de `schema[:strict]`.
#
# Modelos Gemini ignoram a chave extra. Modelos Anthropic (em todos os
# provedores da OpenRouter — Anthropic, Amazon Bedrock e Azure) recusam com
# HTTP 400:
#
#   output_config.format.schema: For 'object' type, property 'strict' is not supported
#
# Sem esta correção, qualquer assistente do Captain apontado para um modelo
# Anthropic falha em 100% das chamadas e cai no texto enlatado de fallback.
#
# Removemos apenas a chave mal posicionada. Como `schema[:strict]` passa a ser
# nil, `strict = schema[:strict] != false` continua resolvendo para true e o
# envelope segue pedindo structured output estrito, como antes.
module ChusteRM
  module RubyLlmSchemaStrictFix
    def to_json_schema
      resultado = super
      return resultado unless resultado.is_a?(Hash)

      schema = resultado[:schema]
      return resultado unless schema.is_a?(Hash)

      resultado.merge(schema: schema.except(:strict, 'strict'))
    end
  end
end

Rails.application.config.to_prepare do
  next unless defined?(RubyLLM::Schema)
  next if RubyLLM::Schema.ancestors.include?(ChusteRM::RubyLlmSchemaStrictFix)

  RubyLLM::Schema.prepend(ChusteRM::RubyLlmSchemaStrictFix)
end
