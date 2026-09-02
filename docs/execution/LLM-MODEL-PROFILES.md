# Perfis de modelos LLM

**Atualizado em:** 2026-08-20
**Gateway:** OpenRouter (`https://openrouter.ai/api/v1`)

| Finalidade | Variável | Modelo |
|---|---|---|
| Orchestrator geral | `LLM_MODEL` | `google/gemini-3.7-flash` |
| Orchestrator da Dra. Letícia | `ORCHESTRATOR_DRA_LETICIA_LLM_MODEL` | `anthropic/claude-sonnet-5` |
| CAPITÃO Dra. Letícia (configuração Rails) | `CAPTAIN_DRA_LETICIA_LLM_MODEL` | `anthropic/claude-sonnet-5` |
| Atendimento inicial da Dra. Letícia | `llm_main_model` do perfil `dra_leticia_intake` | `anthropic/claude-sonnet-5` |
| Resumos da Dra. Letícia | `CAPTAIN_DRA_LETICIA_SUMMARIZER_MODEL` / `llm_summarizer_model` | `google/gemini-3.7-flash` |
| Visão: imagens, PDFs, documentos | `CAPTAIN_MEDIA_AI_MODEL` | `google/gemini-3.7-flash` |
| Visão: fallbacks | `CAPTAIN_MEDIA_AI_FALLBACK_MODELS` | `anthropic/claude-sonnet-5`, `google/gemini-2.5-flash` |
| Transcrição de áudio | `CAPTAIN_AUDIO_TRANSCRIPTION_MODEL` | `openai/gpt-4o-transcribe` |
| teste controlado de atendimento | `LLM_ATTENDANCE_TEST_MODEL` | `deepseek/deepseek-v4-flash` |
| teste controlado de codificação | `LLM_CODING_TEST_MODEL` | `z-ai/glm-5.2` |

O atendimento inicial da Dra. Letícia usa `anthropic/claude-sonnet-5`, enquanto os resumos usam `google/gemini-3.7-flash`,
modelo catalogado pelo Core e configurado para saída estruturada. O modelo geral
do Orchestrator e os modelos de visão permanecem independentes em Gemini 3.7 Flash.

A chave fica somente no `.env` local ignorado pelo Git. `.env.example` e
`services/orchestrator/.env.example` registram os perfis, mas mantêm a chave
vazia.

O agente Dra. Letícia no Orchestrator usa seu perfil dedicado, sem herdar o
modelo geral. No Core, o perfil `dra_leticia_intake` persiste
`llm_provider=openrouter`, `llm_main_model=anthropic/claude-sonnet-5` e
`llm_summarizer_model=google/gemini-3.7-flash`; tanto o configurador do gateway
quanto `captain:seed_dr_paula_matos` preservam essa escolha sem gravar o segredo
no código. Os nomes antigos das variáveis continuam aceitos apenas para
compatibilidade com instalações existentes.

Validações realizadas:

- os quatro IDs constam no catálogo oficial do OpenRouter;
- Grok 4.5 respondeu à chamada mínima do Orchestrator;
- Gemini 3.6 Flash está catalogado e possui tratamento explícito de saída estruturada no Core;
- DeepSeek V4 Flash respondeu exatamente `OK` no smoke de atendimento;
- reindexação dos três documentos da Dra. Paula e embeddings terminou sem
  falhas no Sidekiq;
- GLM 5.2 foi validado no catálogo e permanece reservado para testes de
  codificação, sem chamada paga nesta configuração.
