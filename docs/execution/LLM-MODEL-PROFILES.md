# Perfis de modelos LLM

**Atualizado em:** 2026-08-17  
**Gateway:** OpenRouter (`https://openrouter.ai/api/v1`)

| Finalidade | Variável | Modelo |
|---|---|---|
| Orchestrator geral | `LLM_MODEL` | `google/gemini-3.7-flash` |
| Orchestrator de atendimento | `ORCHESTRATOR_DR_PAULA_LLM_MODEL` | `google/gemini-3.7-flash` |
| CAPITÃO Dra. Paula Matos (configuração Rails) | `CAPTAIN_DR_PAULA_LLM_MODEL` | `google/gemini-3.7-flash` |
| Atendimento WhatsApp (cérebro do Captain) | `CAPTAIN_OPEN_AI_MODEL` / `llm_main_model` | `anthropic/claude-sonnet-5` |
| Resumos da conversa | `llm_summarizer_model` | `google/gemini-3.7-flash` |
| Visão: imagens, PDFs, documentos | `CAPTAIN_MEDIA_AI_MODEL` | `google/gemini-3.7-flash` |
| Visão: fallbacks | `CAPTAIN_MEDIA_AI_FALLBACK_MODELS` | `anthropic/claude-sonnet-5`, `google/gemini-2.5-flash` |
| Transcrição de áudio | `CAPTAIN_AUDIO_TRANSCRIPTION_MODEL` | `openai/gpt-4o-transcribe` |
| teste controlado de atendimento | `LLM_ATTENDANCE_TEST_MODEL` | `deepseek/deepseek-v4-flash` |
| teste controlado de codificação | `LLM_CODING_TEST_MODEL` | `z-ai/glm-5.2` |

O atendimento em si permanece no `claude-sonnet-5` por decisão de qualidade;
o Gemini 3.7 Flash cobre visão, resumo e as rotinas do orchestrator, onde o
custo por token pesa mais que a diferença de redação.

A chave fica somente no `.env` local ignorado pelo Git. `.env.example` e
`services/orchestrator/.env.example` registram os perfis, mas mantêm a chave
vazia.

O agente Dra. Paula no Orchestrator usa seu perfil dedicado, sem herdar o
modelo geral. No Core, a assistente `Dra. Paula Matos` também persiste
`llm_provider=anthropic` e `llm_main_model=anthropic/claude-sonnet-5`; a task
`captain:seed_dr_paula_matos` reconcilia endpoint, chave e modelo sem gravar o
segredo no código.

Validações realizadas:

- os quatro IDs constam no catálogo oficial do OpenRouter;
- Grok 4.5 respondeu à chamada mínima do Orchestrator;
- Sonnet 5 respondeu à chamada mínima da Dra. Paula;
- DeepSeek V4 Flash respondeu exatamente `OK` no smoke de atendimento;
- reindexação dos três documentos da Dra. Paula e embeddings terminou sem
  falhas no Sidekiq;
- GLM 5.2 foi validado no catálogo e permanece reservado para testes de
  codificação, sem chamada paga nesta configuração.
