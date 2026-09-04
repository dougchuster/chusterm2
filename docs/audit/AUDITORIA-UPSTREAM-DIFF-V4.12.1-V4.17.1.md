# Relatório de Auditoria Técnica: Diff Upstream Chatwoot (v4.12.1 → v4.17.1)

**Data da Auditoria:** 02 de Setembro de 2026  
**Status do Fork:** ChusteRM (Base Chatwoot Community Edition `v4.12.1` conforme `core/VERSION_CW`)  
**Repositório Upstream:** `https://github.com/chatwoot/chatwoot`  
**Alvo da Auditoria:** Tag `v4.12.1` (`899fce1c92`) até `v4.17.1` (`b354a9550e` / `upstream/master`)  
**Volume Total de Alterações:** 11 Releases, 756 Commits, 4.365 arquivos modificados (+331.779 / -40.902 linhas)

---

## 1. Resumo Executivo e Escopo Temporal

O ChusteRM opera atualmente sobre o núcleo Chatwoot v4.12.1 (março/2026). Desde então, a árvore upstream do Chatwoot publicou 11 releases estáveis (de `v4.13.0` a `v4.17.1`), abrangendo melhorias substanciais em:
- **Infraestrutura e Dependências:** Atualização para **Rails 7.2.3.1**, **Vite 6.4.2**, **RubyLLM 1.14.1** e remoção do Chart.js em favor da biblioteca proprietária `@chatwoot/viz`.
- **Segurança e Hardening:** Correções para CVEs de dependências (ex: `msgpack` CVE-2026-54522), proteção abrangente contra SSRF via `ssrf_filter` e `SafeFetch`, validação HMAC em webhooks e contenção de XSS em labels de identidade.
- **Performance e Escalabilidade:** Reestruturação do subsistema de contagem de mensagens não lidas (`UnreadCounts`), eliminação de queries N+1 em autenticação/inboxes e novos índices compostos de banco de dados.
- **Novas Funcionalidades Upstream:** Automações baseadas em tempo (`automation_rule_pending_executions`), chamadas de voz unificadas (`calls`), importador expandido de dados do Intercom, monitoramento de saúde de números do WhatsApp e evolução do ecossistema Captain v2 (sessões de agentes, sugestões de FAQ e desfechos de conversas).

Esta auditoria mapeia categoricamente todas as alterações, identifica riscos de colisão com as customizações proprietárias do ChusteRM e define a estratégia segura de sincronização.

---

## 2. Linha do Tempo e Mapeamento de Releases Upstream

| Tag Upstream | Data Release | Commits | Novas Migrations | Principais Destaques e Patches |
|---|---|---:|---:|---|
| **v4.13.0** | 16/04/2026 | 86 | 9 | Assinatura de webhooks para AgentBots/API channel; criação do model unificado `Call`; ativação de Assignment v2; sincronização de documentos Captain; flag de Custom Tools. |
| **v4.14.0** | 18/05/2026 | 135 | 11 | Unificação de Voice na Inbox Twilio SMS; model `PlatformBanner` para avisos de indisponibilidade; rastreamento de última atividade de empresas; suporte a autenticação IMAP; layout de documentação no Help Center. |
| **v4.14.1** | 29/05/2026 | 47 | 2 | Subsistema base de contagem de não-lidos (`unread_counts`); melhorias no Voice-call UX; detecção de MX de e-mails no onboarding; equidade no escalonador de IA. |
| **v4.14.2** | 10/06/2026 | 56 | 0 | Migração de requisições externas para `SafeFetch`; correção de escopos WABA no WhatsApp embedded signup; sanitização de endpoints Swagger; atualização de dependências OAuth. |
| **v4.15.0** | 17/06/2026 | 39 | 3 | Limite de sessões concorrentes por usuário (`user_sessions`); tokens de cores dedicados ao widget de voz; script para migração de provedores de ActiveStorage; suporte a cores/ícones em categorias. |
| **v4.15.1** | 17/06/2026 | 4 | 0 | *Hotfix release:* Reversão temporária de contadores não lidos para filtros de sidebar. |
| **v4.16.0** | 18/07/2026 | 136 | 18 | Expansão do framework de importação de dados (Intercom); models `Captain::MessageReport`, `Captain::FaqSuggestion` e `AgentSession`; layouts de e-mail com marca própria (`branded_email_layouts`); colunas de rascunho de artigos; introdução de `feature_flags_ext_2`. |
| **v4.16.1** | 23/07/2026 | 30 | 0 | Bloqueio de concorrência em quotas de agentes; restrição de deleção de hooks (Linear/Notion/Shopify) a administradores; proteções contra duplo-clique no widget. |
| **v4.16.2** | 27/07/2026 | 22 | 2 | Suporte a Business Scoped User IDs (BSUID) no WhatsApp; expurgo de respostas pendentes do Captain; monitoramento de saúde do número de telefone WhatsApp (`phone_number_health`). |
| **v4.17.0** | 19/08/2026 | 180 | 19 | Automações baseadas em tempo com atraso de execução (`automation_rule_pending_executions`); model de desfechos de conversas (`conversation_outcomes`); rastreamento de documentos citados em `agent_sessions`; migração para `@chatwoot/viz` e Vite 6; atualização de Rails para 7.2.3.1. |
| **v4.17.1** | 27/08/2026 | 21 | 1 | Reformulação visual do status de saúde do WhatsApp; associação polimórfica `ai_assignee` em `conversations`; sanitização de labels de identidade como texto plano; correção de separador de vírgula em filtros de automação. |

---

## 3. Inventário Categorizado de Arquivos Modificados no Upstream

### 3.1. Core Backend (461 arquivos)

#### A. Models e Concerns (65 arquivos)
- **Conversas e Mensagens:**
  - `app/models/conversation.rb`: Adicionados campos/associações para `ai_assignee_type`, `status_changed_at`, `applied_slas`, e métodos de integração com o subsistema de unread counts e outcomes.
  - `app/models/message.rb`: Suporte a índices adicionais de remetente, persistência de metadados de mídia BSUID e tratamento de quebras de linha em assinaturas.
  - `app/models/concerns/assignment_handler.rb` e `auto_assignment_handler.rb`: Nova política de idade máxima de conversas e suporte a atribuição de IA.
- **Contatos e Empresas:**
  - `app/models/contact.rb`: Adicionado seletor de empresas, sincronização assíncrona de avatares pós-commit e métodos de mesclagem sem orfandade de chamadas.
  - `app/models/concerns/avatarable.rb`: Proteção SSRF ao baixar avatares remotos via `Down` e `SafeFetch`.
- **Canais de Comunicação:**
  - `app/models/channel/whatsapp.rb`: Suporte a `phone_number_health`, `business_management_token`, fluxos Coexistence, BSUID e templates de mensagens.
  - `app/models/channel/twilio_sms.rb`: Fusão com capacidades de voz (`voice_enabled`) e remoção do antigo `Channel::Voice`.
  - `app/models/channel/email.rb`: Configuração de método de autenticação IMAP e layouts customizados de e-mail.
  - `app/models/channel/api.rb` e `app/models/agent_bot.rb`: Adição de segredo criptográfico (`secret`) para assinatura HMAC de webhooks.
- **Segurança e Sessões:**
  - `app/models/user_session.rb` (Novo): Controle de sessões ativas simultâneas com revogação e auditoria de IP/User-Agent.
  - `app/models/concerns/webhook_secretable.rb` (Novo): Concern unificado para geração e validação de tokens secretos HMAC.
- **Importação de Dados:**
  - `app/models/data_import_item.rb`, `data_import_mapping.rb`, `data_import_error.rb` (Novos): Framework escalável para importação de Intercom e Freshdesk.
- **Automações e SLAs:**
  - `app/models/automation_rule_pending_execution.rb` (Novo): Fila de execuções postergadas (time-based delay).
  - `app/models/applied_sla.rb`: Adição do timestamp `completed_at` para congelar cálculo de SLA após resolução.

#### B. Controllers (95 arquivos)
- `app/controllers/api/v1/accounts/conversations/unread_counts_controller.rb` (Novo): Endpoints de contadores em tempo real.
- `app/controllers/api/v1/accounts/branded_email_layouts_controller.rb` (Novo): CRUD de layouts de e-mail.
- `app/controllers/api/v1/accounts/articles/bulk_actions_controller.rb` (Novo): Ações em lote no Help Center (tradução, deleção, status).
- `app/controllers/api/v1/accounts/concerns/whatsapp_health_management.rb` (Novo): Métricas de saúde do canal WhatsApp.
- `app/controllers/api/v1/accounts/custom_attribute_definitions_controller.rb`: Enforce de autorização exclusiva para administradores.
- `app/controllers/api/v1/accounts/dashboard_apps_controller.rb`: Bloqueio de mutações por agentes comuns.

#### C. Services e Libs (199 arquivos)
- **Subsistema Unread Counts (13 arquivos em `app/services/conversations/unread_counts/`):**
  - `builder.rb`, `counter.rb`, `filter_query_counter.rb`, `filtered_count_invalidator.rb`, `store.rb`, `refresher.rb`, `listener.rb`.
  - Substitui consultas recorrentes no PostgreSQL por contagem agregada em cache com invalidação orientada a eventos.
- **Utilitários de Segurança e Rede:**
  - `lib/safe_fetch.rb` e `app/services/safe_fetch.rb`: Wrapper obrigatório para download de URLs externas com validação contra redes privadas (anti-SSRF).
  - `lib/integrations/linear/auto_link_service.rb`: Criação automática de links de issues Linear em notas privadas.
  - `lib/integrations/cloudflare/realtime_kit_credentials_validator.rb`: Migração de Dyte para Cloudflare RealtimeKit.

#### D. Background Jobs e Listeners (47 arquivos)
- `app/jobs/automation_rules/delayed_execution_job.rb` (Novo): Execução de regras de automação com atraso configurado.
- `app/jobs/data_import/intercom_import_job.rb` (Novo): Pipeline assíncrono de importação de dados.
- `app/jobs/whatsapp/sync_templates_job.rb` e `fetch_phone_number_health_job.rb` (Novos): Rotinas de manutenção do WhatsApp.
- `app/listeners/unread_counts_listener.rb` (Novo): Disparo de recálculo de não-lidos em eventos do ActionCable.

---

### 3.2. Database Migrations (66 arquivos / 65 novas migrations)

Abaixo está o inventário cronológico completo das 65 migrations adicionadas pelo upstream entre `v4.12.1` e `v4.17.1`:

| Data/Timestamp | Arquivo de Migration Upstream | Propósito Técnico |
|---|---|---|
| 20260324070820 | `add_secret_to_agent_bots.rb` | Adiciona coluna `secret` para assinatura HMAC em bots de agentes |
| 20260324070828 | `add_secret_to_channel_api.rb` | Adiciona coluna `secret` para assinatura HMAC em canais de API |
| 20260324070835 | `backfill_agent_bot_and_channel_api_secrets.rb` | Gera segredos criptográficos retroativos |
| 20260324102005 | `repurpose_response_bot_flag_for_custom_tools.rb` | Reutiliza bit de flag para habilitar Custom Tools no Captain |
| 20260326120000 | `add_voice_to_channel_twilio_sms.rb` | Adiciona colunas de configuração de voz ao canal Twilio SMS |
| 20260326120001 | `drop_channel_voice.rb` | Remove a tabela legada e redundante `channel_voice` |
| 20260327065119 | `create_platform_banners.rb` | Tabela de avisos globais do sistema e notificações de status |
| 20260408170902 | `create_calls.rb` | Tabela centralizada para rastreamento de chamadas de voz |
| 20260409091202 | `enable_assignment_v2_for_new_accounts.rb` | Ativa a versão 2 do motor de auto-atribuição de conversas |
| 20260410092751 | `add_edited_to_captain_assistant_responses.rb` | Rastreia se resposta de IA foi editada por agente humano |
| 20260410092752 | `add_sync_columns_to_captain_documents.rb` | Colunas de periodicidade e status de auto-sync de documentos |
| 20260410092753 | `backfill_edited_on_captain_assistant_responses.rb` | Popula flags existentes em respostas de assistentes |
| 20260422133000 | `add_additional_attributes_to_companies.rb` | Expande campos personalizados no model Company |
| 20260426011444 | `repurpose_twilio_content_templates_flag_for_captain_document_auto_sync.rb` | Reutiliza flag para auto-sync de documentos |
| 20260427094500 | `rename_company_condition_key_in_automation_rules.rb` | Padroniza chave de condição de empresa para `company_name` |
| 20260428120000 | `backfill_captain_document_sync_metadata.rb` | Popula metadados de sincronização de documentos |
| 20260429043000 | `add_sync_stats_index_to_captain_documents.rb` | Adiciona índice em status e timestamp de sync em documentos |
| 20260430114500 | `repurpose_report_v4_flag_for_captain_v1_action_classifier.rb` | Reutiliza flag de relatórios para o classificador de ações do Captain |
| 20260507000000 | `add_imap_authentication_to_channel_email.rb` | Adiciona suporte a métodos de autenticação IMAP customizados |
| 20260508000000 | `repurpose_channel_twitter_flag_for_conversation_unread_counts.rb` | Reutiliza flag legado do Twitter para o recurso de unread counts |
| 20260515000000 | `enqueue_validate_openai_hooks_job.rb` | Valida credenciais armazenadas de integrações OpenAI |
| 20260525093000 | `change_captain_document_external_link_to_text.rb` | Converte link externo de string para tipo text |
| 20260604000000 | `add_provider_config_to_channel_twilio_sms.rb` | Armazena configurações adicionais de provedor no Twilio |
| 20260610000000 | `add_icon_color_to_categories.rb` | Adiciona suporte a cores de ícone em categorias do Help Center |
| 20260611184600 | `create_user_sessions.rb` | Tabela para gerenciar sessões de login de usuários |
| 20260616120000 | `add_icon_to_teams.rb` | Adiciona campo de ícone visual para equipes |
| 20260617000000 | `add_exclude_older_than_hours_to_assignment_policies.rb` | Limita auto-atribuição excluindo conversas antigas |
| 20260618000000 | `backfill_rejected_call_status.rb` | Backfill de status para chamadas de voz recusadas |
| 20260620000000 | `create_captain_message_reports.rb` | Tabela para denúncia/feedback de mensagens geradas por IA |
| 20260622000000 | `add_account_created_at_index_to_calls.rb` | Índice composto em `calls (account_id, created_at)` |
| 20260623000000 | `add_draft_columns_to_articles.rb` | Suporte a rascunho de artigos no Help Center |
| 20260629000000 | `repurpose_quoted_email_reply_flag_for_unread_count_for_filters.rb` | Reutiliza flag para contadores não lidos em filtros |
| 20260630000000 | `add_sender_created_index_to_messages.rb` | Índice de performance em `messages (sender_type, sender_id, created_at)` |
| 20260702000000 | `expand_data_imports_for_intercom_imports.rb` | Adiciona colunas para importação do Intercom |
| 20260702000001 | `create_data_import_items.rb` | Itens granulares de importação de dados |
| 20260702000002 | `create_data_import_mappings.rb` | Mapeamento de campos entre plataformas externas e Chatwoot |
| 20260702000003 | `create_data_import_errors.rb` | Log de erros de importação |
| 20260706000000 | `add_inbox_scope_to_email_templates.rb` | Escopo de templates de e-mail por caixa de entrada |
| 20260706000001 | `repurpose_insert_article_in_reply_for_branded_email_templates.rb` | Reutiliza flag para layouts de e-mail com marca própria |
| 20260706215758 | `add_feature_flags_ext_2_to_accounts.rb` | Adiciona coluna inteira para expansão de feature flags (bitmask) |
| 20260709060000 | `add_execution_delay_to_automation_rules.rb` | Adiciona atraso configurável em automações (em minutos/horas) |
| 20260709060100 | `add_status_changed_at_to_conversations.rb` | Timestamp do momento da última transição de status |
| 20260709060200 | `create_automation_rule_pending_executions.rb` | Tabela para execuções agendadas de automações |
| 20260709091147 | `create_agent_sessions.rb` | Tabela para rastreamento de interações do Captain v2 |
| 20260710000000 | `change_captain_assistant_description_to_text.rb` | Expande tamanho da descrição dos assistentes |
| 20260713184351 | `create_captain_faq_suggestions.rb` | Sugestões automáticas de FAQ derivadas do histórico |
| 20260714123000 | `purge_pending_captain_assistant_responses.rb` | Limpeza de respostas em estado inconsistente |
| 20260715000000 | `add_completed_at_to_applied_slas.rb` | Timestamp de conclusão de SLAs |
| 20260718000000 | `add_phone_number_health_to_channel_whatsapp.rb` | Métricas de status/reputação do WhatsApp |
| 20260724000100 | `add_index_to_conversations_created_at.rb` | Índice para aceleração de consultas temporais |
| 20260728000001 | `add_business_management_token_to_channel_whatsapp.rb` | Token para gestão de templates em nuvem do WhatsApp |
| 20260729051500 | `add_status_updated_at_index_to_automation_rule_pending_executions.rb` | Índice para worker de execução de automações |
| 20260731140853 | `create_conversation_outcomes.rb` | Desfechos de conversa (resolvida por IA, transferida, etc.) |
| 20260803000000 | `enqueue_copy_captain_auto_resolve_mode_to_assistants_job.rb` | Migração assíncrona de modo de auto-resolução |
| 20260803130000 | `add_episode_grain_to_conversation_outcomes.rb` | Granularidade por episódio de atendimento em desfechos |
| 20260804000000 | `add_cited_document_ids_to_agent_sessions.rb` | Rastreia documentos da base de conhecimento citados pela IA |
| 20260804000001 | `add_index_on_agent_sessions_cited_document_ids.rb` | Índice GIN em IDs de documentos citados |
| 20260804000002 | `add_used_faq_ids_to_agent_sessions.rb` | Rastreia FAQs utilizados nas respostas do assistente |
| 20260804000003 | `add_index_on_agent_sessions_used_faq_ids.rb` | Índice GIN em IDs de FAQs utilizados |
| 20260806000000 | `add_index_on_agent_sessions_document_ids.rb` | Índice adicional de documentos em sessões |
| 20260807101420 | `add_account_status_created_at_index_to_conversations.rb` | Índice composto otimizando listagem de conversas |
| 20260807133000 | `create_campaign_recipients.rb` | Tabela para controle granular de destinatários de campanhas |
| 20260811000000 | `add_ai_assignee_type_to_conversations.rb` | Suporte polimórfico a atribuição para agentes de IA |
| 20260814000000 | `add_associated_created_at_index_to_audits.rb` | Aceleração de busca e paginação de auditoria |

---

### 3.3. Frontend (2.745 arquivos)

- **Dashboard App (`app/javascript/dashboard` - 2.495 arquivos):**
  - **i18n (1.629 arquivos):** Atualizações nas strings de tradução em ~50 idiomas. No ChusteRM, conforme diretrizes, apenas `pt_BR` e `en` são estritamente mantidos.
  - **Rotas (239 arquivos):** Novos fluxos para `branded-email-layouts`, `inbox-onboarding`, `user-sessions`, `captain-assistant-stats`, `faq-suggestions` e `calls`.
  - **Componentes (81 arquivos):** Adição de Side Drawer genérico (`CW-7757`), visualizador de templates de mensagem com suporte a variáveis, cards de referência de anúncios Click-to-WhatsApp (CTWA), editor redimensionável e filtros aprimorados.
  - **Store Pinia / Vuex (73 arquivos):** Criação do módulo `unreadCounts`, refatoração do módulo `captain` e atualização da reatividade de presença de usuários.
  - **Visualização de Dados:** Remoção completa de `chart.js` e `vue-chartjs`, migrando gráficos analíticos para a nova biblioteca interna `@chatwoot/viz`.
- **Widget do Chat (`app/javascript/widget` - 87 arquivos):**
  - Validação estrita de consentimento em caixas de seleção obrigatórias.
  - Rate-limit e proteção contra abusos no download do histórico de transcrição de conversa.
  - Melhorias de contraste e opções em modo escuro nativo.
  - Componente de áudio gravador com codificação Opus/OGG.
- **Autenticação v3 (`app/javascript/v3` - 7 arquivos):**
  - Seletor de sessão em login simultâneo (`ConcurrentSessionsModal`).
  - Reenvio de e-mail de confirmação diretamente na tela de login.
  - Persistência segura de sessões 2FA/MFA entre reinícios do navegador.

---

### 3.4. Dependências (Gemfile, package.json)

| Dependência | Versão Upstream v4.12.1 | Versão Upstream v4.17.1 | Impacto / Ação Necessária |
|---|---|---|---|
| **Rails** | `~> 7.1` | `7.2.3.1` | **Crítico:** Exige compatibilidade do Rails 7.2 (o ChusteRM já adotou `~> 7.2.3` no `core/Gemfile`). |
| **Puma** | `~> 6.0` | `~> 7.2.1` | Melhoria de concorrência e correções de segurança. |
| **Sidekiq / Sidekiq-cron** | `7.3.1` / `1.12.0` | `7.3.10` / `2.4.0` | Compatibilidade de jobs com Rails 7.2 e correções de auditoria de gems. |
| **RubyLLM / ai-agents** | `>= 1.8.2` / `0.9.1` | `>= 1.14.1` / `0.12.0` | Atualização do motor interno de LLM do Chatwoot upstream. |
| **ssrf_filter** | *Não existia* | `~> 1.5` | Nova gem de proteção obrigatória para chamadas HTTP externas. |
| **Vite** | `5.4.21` | `6.4.2` | **Crítico:** Migração para Vite 6 (o ChusteRM já atualizou para `6.4.3` com sucesso). |
| **@chatwoot/viz** | *Não existia* | `^0.1.5` | Nova dependência gráfica que substitui `chart.js` e `vue-chartjs`. |
| **@hotwired/turbo-rails** | *Não existia* | `^8.0.13` | Substitui o pacote legado `turbolinks`. |
| **DOMPurify** | `3.3.2` | `3.4.13` | Correção contra vetores de mXSS e sanitização de HTML. |
| **msgpack** | `1.7.2` | `1.7.5+` | Correção de vulnerabilidade CVE-2026-54522. |

---

### 3.5. Enterprise Overlay (`enterprise/` - 330 arquivos)

O upstream modificou e adicionou recursos proprietários da versão Enterprise:
1. **Métricas Avançadas de IA (Captain Analytics):**
   - Builders em `enterprise/app/builders/captain/`: `assistant_drilldown_builder.rb`, `assistant_overview_stats_builder.rb`, `assistant_resolution_flow_builder.rb`, `conversation_usage_builder.rb`.
   - Novos controllers: `agent_sessions_controller.rb`, `assistant_stats_controller.rb`, `faq_suggestions_controller.rb`, `message_reports_controller.rb`.
2. **Gestão de Empresas (B2B CRM Light):**
   - Controllers para notas, contatos e conversas associados a empresas (`enterprise/app/controllers/api/v1/accounts/companies/*`).
3. **Chamadas de Voz Corporativas:**
   - `enterprise/app/controllers/api/v1/accounts/calls_controller.rb` com controle de permissão e gravação de áudio.
4. **Auditoria e Segurança:**
   - Enriquecimento de logs de auditoria com resolução de localização IP e filtros avançados.

---

## 4. Análise Crítica de Riscos de Colisão com Customizações ChusteRM

| Subsistema Proprietário ChusteRM | Arquivos e Componentes ChusteRM | Alterações no Upstream | Nível de Risco | Mitigação / Requisitos de Isolamento |
|---|---|---|:---:|---|
| **1. CRM Conversacional Nativo** | 15+ models (`crm_*`: `CrmPipeline`, `CrmDeal`, `CrmActivity`, `CrmBoardView`, `CrmCadence`, etc.), rotas `/api/v1/accounts/crm/*`, policies e services. | Alterações nos models `Contact`, `Conversation`, `Account`, `Label`, `CustomAttributeDefinition`. | **MÉDIO-ALTO** | O CRM do ChusteRM utiliza namespace próprio (`crm_*` e `Crm::*`). Não sobrescrever os modelos centrais de `Contact` e `Conversation`. Manter os includes e concerns do ChusteRM intactos. |
| **2. Frontend do Kanban e CRM** | Rotas em `dashboard/routes/dashboard/crm`, componentes em `components/crm/`, store `modules/crm.js`, helpers `crmCardSignals.js`, `crmBoardFilters.js`. | Alterações no `dashboard.routes.js`, menu lateral (`Sidebar.vue`), Tailwind styling, migração `@chatwoot/viz`. | **MÉDIO** | Proteger o registro de rotas do CRM em `dashboard.routes.js` e o item de menu do CRM na sidebar. Testes unitários do frontend (`crmBoardFilters.spec.js` e `crmCardSignals.spec.js`) já estão validados e verdes. |
| **3. Integração Evolution API (WhatsApp Baileys)** | `evolution_api_configurations`, `evolution_instances`, `evolution_webhook_events`, `Evolution::*` services, provider customizado em `Channel::Whatsapp`. | Extensa refatoração em `Channel::Whatsapp`, `Whatsapp::*` services, webhook controllers, suporte a BSUID e Coexistence. | **CRÍTICO** | **Ponto mais sensível:** O upstream alterou drasticamente `app/models/channel/whatsapp.rb` e os controllers de webhook. O driver do Evolution API do ChusteRM não pode ser sobrescrito cegamente. Recomenda-se aplicar os patches de segurança do WhatsApp mantendo a ramificação do provider `evolution`. |
| **4. Orquestrador de IA e Microsserviços** | `services/orchestrator`, `services/crm-service`, `services/identity-bridge`, `captain_conversation_states`, `captain_flows`. | Captain v2: novos models (`AgentSession`, `ConversationOutcome`, `FaqSuggestion`), atualização `ruby_llm` 1.14.1 e `ai-agents` 0.12.0. | **ALTO** | Os microsserviços do ChusteRM funcionam externamente ao Rails core, mas compartilham estados no Postgres. Garantir que as migrations do Captain v2 upstream não colidam com as tabelas customizadas `captain_conversation_states` e `captain_flows`. |
| **5. Design System Obsidian Kinetic e UI/UX** | Tema Midnight Indigo, Dark Mode tokens, novo login `/v3`, Super Admin, layout glass, assets em `core/public/brand-assets/`. | Mudança de tokens CSS, layouts de helpcenter, novos drawers, substituição de `chart.js` por `@chatwoot/viz`. | **ALTO** | Impedir que merges automáticos restaurem a UI padrão do Chatwoot (cores azuis legadas, logos antigas). Preservar os componentes estilizados de layout, header, login e dashboard. |
| **6. Overlay Enterprise e Extensões** | `enterprise/app/services/captain/tools/copilot/get_crm_context_service.rb`, `deterministic_crm_actions_service.rb`. | Upstream adicionou 330 arquivos no `enterprise/` (novos builders, controllers e analytics). | **MÉDIO** | Incorporar os novos endpoints enterprise de analytics e auditoria, mantendo os extension points (`prepend_mod_with`) onde o ChusteRM injeta contexto de CRM. |

---

## 5. Auditoria de Segurança e Patches Críticos do Upstream

Recomenda-se a adoção prioritária dos seguintes patches de segurança e correções essenciais do upstream:

1. **Correção de SSRF com `SafeFetch` e `ssrf_filter` (Commits `c8e551820b`, `661608c0b1`, `3dfb5061e1`):**
   - Implementa bloqueio rigoroso contra requisições direcionadas à rede local ou metadados de nuvem (AWS/GCP) em webhooks, importação de avatares e ferramentas de IA.
2. **Sanitização de XSS em Labels de Identidade (Commit `5157407a92`):**
   - Força a renderização de labels como texto plano, prevenindo injeção de scripts maliciosos.
3. **Validação Criptográfica HMAC em Webhooks (Commits `95463230cb`, `a9ac1c633d`):**
   - Assinatura SHA-256 no payload de webhooks para canais de API, AgentBots, WhatsApp e Instagram.
4. **Correção de Autorização e Escopos (Commits `5c6ea78ce6`, `49c442751d`, `8aee518149`):**
   - Restrição de endpoints sensíveis (Custom Attribute Definitions, Dashboard Apps, Hooks) exclusivamente a administradores de conta.
5. **Atualização de Vulnerabilidade CVE-2026-54522 em `msgpack` (Commit `9caceea858`):**
   - Previne estouro de buffer e execução de código em serialização binária.

---

## 6. Recomendações e Roadmap de Sincronização em 5 Fases

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ROADMAP DE ATUALIZAÇÃO SEGURA                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  FASE 1: Dependências e Hardening de Segurança (SSRF, HMAC, CVEs)            │
│  FASE 2: Migrations de Banco e Core Backend (com proteção do Evolution API) │
│  FASE 3: Sincronização do Enterprise Overlay e Subsistema Unread Counts     │
│  FASE 4: Frontend e Visualizações (mantendo Obsidian Kinetic e Kanban CRM)  │
│  FASE 5: Bateria Completa de Testes, Lints e Validação em QA                │
└─────────────────────────────────────────────────────────────────────────────┘
```

1. **Fase 1 — Dependências e Segurança:**
   - Adicionar a gem `ssrf_filter` (~> 1.5) e utilitário `SafeFetch`.
   - Atualizar dependências com avisos de segurança (`msgpack`, `dompurify` 3.4.13, `puma` 7.2+).
2. **Fase 2 — Banco de Dados e Backend:**
   - Executar as 65 migrations do upstream em ambiente de homologação.
   - Sincronizar melhorias em `Conversation`, `Contact`, `AutomationRule` e `AppliedSla`.
   - **Trava de Segurança:** Proteger integralmente o arquivo `core/app/models/channel/whatsapp.rb` e `app/controllers/webhooks/whatsapp_controller.rb` para preservar os handlers do Evolution API.
3. **Fase 3 — Enterprise Overlay:**
   - Integrar os novos controllers de `AgentSession` e `CaptainStats`.
   - Manter os decorators e ferramentas de CRM (`get_crm_context_service.rb`).
4. **Fase 4 — Frontend e Design System:**
   - Incorporar a biblioteca `@chatwoot/viz` para renderização de gráficos.
   - Preservar os temas, tokens escuros e componentes Obsidian Kinetic.
   - Garantir a integridade das rotas do CRM em `dashboard.routes.js`.
5. **Fase 5 — Validação e Homologação:**
   - Executar suíte de testes do core (`pnpm test`, `bundle exec rspec`).
   - Validar testes dos microsserviços (`npm test` no orchestrator, crm-service e identity-bridge).
   - Executar verificações de lint (`pnpm eslint`, `bundle exec rubocop`).
