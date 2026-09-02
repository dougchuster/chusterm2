# Worktree Ledger — F0-WT-01

**Data do snapshot:** 2026-07-10

**Branch/HEAD:** `main` / `f5f0dde`

**Status:** 🟡 classificado; validação e fracionamento ainda pendentes

**Regra:** este ledger descreve o estado encontrado. Ele não autoriza reset, checkout global, descarte, stage adicional ou commit das mudanças do usuário.

## 1. Resumo

- 76 arquivos rastreados possuem mudanças unstaged.
- 1 exclusão já estava staged antes desta execução: `core/app/controllers/api/v1/accounts/crm_controller.rb`.
- 42 entradas não rastreadas foram encontradas pelo Git, incluindo documentos do plano, código CRM/CAPITÃO e o repositório auxiliar `everything-claude-code/`.
- O Docker Desktop estava desligado; containers, banco, filas e restore não puderam ser verificados nesta sessão.
- O repositório auxiliar `everything-claude-code/` está em `841beea` e possui locks próprios alterados. Ele não integra o produto e não será modificado.

## 2. Classes e decisões

| Classe | Escopo | Origem/decisão atual | Validação antes de commit | Rollback |
|---|---|---|---|---|
| WT-DOC | `prompt-reformulacao-crm.md`, plano, auditorias, ADRs, setup e `docs/audit/` | artefatos aceitos do plano CRM vigente; preservar | hashes, links, consistência e atualização por gate | remover somente artefato explicitamente substituído |
| WT-CRM | controllers/models/services/jobs/views/specs e frontend sob CRM, Inbox e Captain | melhorias do plano CRM atual, majoritariamente implementadas e não validadas | specs focados, tenancy A/B, E2E e revisão Core/Enterprise | feature flag/contrato anterior; sem migration destrutiva |
| WT-INFRA | envs, Dockerfiles, Compose, deploy, backup e dependências | estabilização do runtime e aposentadoria de serviços; preservar | build, compose config, backup/restore e CI | imagens/configuração anteriores + backup |
| WT-ORCH | `services/orchestrator/` | contrato/testes do Orchestrator vigente; segurança interna ainda pendente | test/build, autenticação de serviço e tenant | desativar integração/voltar imagem |
| WT-MEDIA | jobs/services Enterprise de áudio/mídia, Gemini, eventos e erro transitório | mudança adjacente preexistente; origem exata não comprovada | specs Enterprise, provider sandbox e revisão de PII | manter caminho anterior por configuração |
| WT-REMOVE-CRM-PROXY | exclusão staged de `crm_controller.rb` | coerente com aposentadoria do `crm-service`, mas staging preexistente será preservado | rotas sem referência, request specs e smoke | restaurar somente com autorização se serviço ainda for necessário |
| WT-OLD-DOC | exclusão de `docs/system-audit-report.md` | limpeza histórica incerta; preservar a exclusão até comparar conteúdo | confirmar que achados estão nas auditorias atuais | restaurar documento se houver evidência única |
| WT-SNAPSHOT | snapshots DateSeparator/Spinner | alteração incerta e possivelmente incidental | executar specs e justificar diff | regravar somente por mudança intencional |
| WT-I18N | novos índices/JSON `en` e `pt_BR` | copy CRM preexistente; preservar. Novos trabalhos seguirão `core/AGENTS.md` | build, lint e decisão sobre PT-BR local | aliases/chaves anteriores |
| WT-EXTERNAL | `everything-claude-code/` | checkout auxiliar do usuário, fora do produto | nenhuma validação de produto; excluir de commits ChusteRM | não tocar |

## 3. Regras de classificação por caminho

1. Documentos raiz do plano e `docs/audit/**` → WT-DOC.
2. `core/app/**crm**`, `core/app/**captain**`, helpers CRM/ID, migrations `20260703*` e respectivos specs → WT-CRM.
3. `.env*`, `core/Dockerfile`, `docker-compose*.yml`, `infra/**`, `scripts/backup.ps1`, package manifests e lockfiles → WT-INFRA; os manifests do Orchestrator também recebem WT-ORCH.
4. `services/orchestrator/src/**` e `services/orchestrator/test/**` → WT-ORCH.
5. `core/enterprise/app/**messages/**`, `core/lib/llm/**`, `message_templates/hook_execution_service.rb`, eventos e specs correspondentes → WT-MEDIA.
6. As duas exclusões e os dois snapshots usam suas classes explícitas acima.
7. Qualquer arquivo que não se encaixe de forma inequívoca permanece `INCERTO — PRESERVAR` até revisão individual.

## 4. Pontos que impedem o fechamento de F0-WT-01/F0-BKP-01

- [ ] Docker disponível e runtime novamente inspecionado.
- [ ] Backup do PostgreSQL, `core-storage` e volumes Evolution criado e restaurado em cópia descartável.
- [ ] Exclusão staged do proxy CRM validada contra rotas e referências.
- [ ] Exclusão do relatório antigo comparada com as auditorias atuais.
- [ ] Snapshots compartilhados explicados por testes.
- [ ] Mudanças WT-MEDIA confirmadas como parte do escopo ou separadas sem descarte.
- [ ] Worktree fracionado em lotes temáticos somente após evidência; nenhum commit automático será feito neste estado misto.

## 5. Evidências

### 5.1 Diff unstaged

```text
 .env.example                                       |  15 +-
 .env.prod.example                                  |   9 +-
 .gitignore                                         |   7 +-
 core/Dockerfile                                    |  18 +-
 .../captain/conversation_states_controller.rb      |  12 +-
 .../api/v1/accounts/crm/activities_controller.rb   |  42 +-
 .../api/v1/accounts/crm/base_controller.rb         |  17 +
 .../api/v1/accounts/crm/deals_controller.rb        | 189 +++----
 .../v1/accounts/crm/pipeline_stages_controller.rb  |  12 +-
 .../crm/triage/from_conversation_controller.rb     |  28 +-
 .../dashboard/api/captain/conversationState.js     |   4 +-
 core/app/javascript/dashboard/api/crm.js           |  17 +-
 .../captain/CaptainConversationStateCard.vue       |  12 +-
 .../dashboard/components/crm/CRMDealCard.vue       | 103 +++-
 .../dashboard/components/crm/CRMDealDrawer.vue     | 141 ++++-
 .../dashboard/components/crm/CRMExportButton.vue   |  35 +-
 .../components/crm/CRMKanbanChatDrawer.spec.js     | 117 +++-
 .../components/crm/CRMKanbanChatDrawer.vue         | 190 ++++++-
 .../dashboard/components/crm/CRMLegalAreaBadge.vue |  25 +-
 .../dashboard/components/crm/CRMSidebarCard.vue    |  24 +-
 .../widgets/conversation/ConversationSidebar.vue   |   9 +-
 .../app/javascript/dashboard/helper/actionCable.js |  12 +-
 .../javascript/dashboard/i18n/locale/en/index.js   |   2 +
 .../dashboard/i18n/locale/pt_BR/index.js           |   2 +
 .../routes/dashboard/captain/score/Index.vue       |   7 +-
 .../routes/dashboard/conversation/ContactPanel.vue |  11 +-
 .../dashboard/routes/dashboard/crm/crm.routes.js   |  37 +-
 .../routes/dashboard/crm/pages/Agenda.vue          |  32 +-
 .../routes/dashboard/crm/pages/AllLeads.vue        |  73 +--
 .../routes/dashboard/crm/pages/CrmIndex.vue        | 387 +++++++++----
 .../routes/dashboard/crm/pages/DealDetails.vue     | 143 +++--
 .../routes/dashboard/crm/pages/LossReasons.vue     |  20 +-
 .../routes/dashboard/crm/pages/Reports.vue         |  38 +-
 core/app/jobs/crm/health_check_job.rb              |   2 +
 core/app/listeners/action_cable_listener.rb        |  20 +
 .../account_notification_mailer.rb                 |   5 +
 core/app/models/account.rb                         |   1 +
 core/app/models/captain_conversation_state.rb      |  35 +-
 core/app/models/crm_activity.rb                    |   2 +
 core/app/models/crm_deal.rb                        |  55 +-
 .../conversations/event_data_presenter.rb          |   2 +-
 core/app/services/crm/deal_creator.rb              |  37 +-
 core/app/services/crm/health_check_service.rb      |  53 +-
 .../message_templates/hook_execution_service.rb    |   7 +-
 .../_conversation_search_result.json.jbuilder      |   2 +
 .../v1/accounts/search/conversations.json.jbuilder |   2 +
 .../partials/_conversation.json.jbuilder           |   2 +
 .../api/v1/models/_conversation.json.jbuilder      |   2 +
 core/config/routes.rb                              |   5 +-
 core/db/schema.rb                                  |  10 +-
 .../app/jobs/messages/audio_transcription_job.rb   |  10 +
 .../app/jobs/messages/media_understanding_job.rb   |  10 +
 .../messages/audio_transcription_service.rb        |  10 +
 .../messages/media_understanding_service.rb        |  10 +
 core/lib/events/types.rb                           |   5 +
 core/lib/llm/gemini_multimodal_service.rb          |  62 ++-
 core/package.json                                  |   8 +-
 core/pnpm-lock.yaml                                |  58 +-
 .../v1/accounts/conversations_controller_spec.rb   |   8 +-
 .../accounts/crm/agenda_events_controller_spec.rb  |   9 +
 .../api/v1/accounts/crm/deals_controller_spec.rb   | 198 +++++++
 .../messages/audio_transcription_service_spec.rb   |  31 +-
 .../conversations/event_data_presenter_spec.rb     |   2 +
 core/swagger/definitions/resource/conversation.yml |   8 +-
 docker-compose.dev.yml                             |  52 +-
 docker-compose.prod.yml                            |  93 ++--
 docker-compose.yml                                 |  56 +-
 docs/system-audit-report.md                        | 296 ----------
 infra/deploy.sh                                    |  12 +-
 scripts/backup.ps1                                 |  18 +-
 services/orchestrator/Dockerfile                   |  12 +-
 services/orchestrator/package-lock.json            | 617 +++++++++++++--------
 services/orchestrator/package.json                 |  12 +-
 services/orchestrator/src/app.ts                   |  23 +-
 services/orchestrator/src/queues/index.ts          |  10 +-
 services/orchestrator/src/routes/agent.ts          | 102 ++--
 76 files changed, 2438 insertions(+), 1326 deletions(-)
76
warning: in the working copy of 'core/app/listeners/action_cable_listener.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/presenters/conversations/event_data_presenter.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/views/api/v1/accounts/search/_conversation_search_result.json.jbuilder', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/views/api/v1/accounts/search/conversations.json.jbuilder', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/views/api/v1/models/_conversation.json.jbuilder', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/config/agents/tools.yml', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/db/schema.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/enterprise/app/jobs/messages/audio_transcription_job.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/lib/events/types.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/spec/controllers/api/v1/accounts/conversations_controller_spec.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/spec/enterprise/services/messages/audio_transcription_service_spec.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/spec/presenters/conversations/event_data_presenter_spec.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/swagger/definitions/resource/conversation.yml', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'scripts/backup.ps1', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'core/app/listeners/action_cable_listener.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/presenters/conversations/event_data_presenter.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/views/api/v1/accounts/search/_conversation_search_result.json.jbuilder', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/views/api/v1/accounts/search/conversations.json.jbuilder', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/app/views/api/v1/models/_conversation.json.jbuilder', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/config/agents/tools.yml', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/db/schema.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/enterprise/app/jobs/messages/audio_transcription_job.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/lib/events/types.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/spec/controllers/api/v1/accounts/conversations_controller_spec.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/spec/enterprise/services/messages/audio_transcription_service_spec.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/spec/presenters/conversations/event_data_presenter_spec.rb', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'core/swagger/definitions/resource/conversation.yml', CRLF will be replaced by LF the next time Git touches it
warning: in the working copy of 'scripts/backup.ps1', LF will be replaced by CRLF the next time Git touches it
```

### 5.2 Diff staged

```text
 .../controllers/api/v1/accounts/crm_controller.rb  | 82 ----------------------
 1 file changed, 82 deletions(-)
```

### 5.3 Repositório auxiliar

```text
841beea
 M package-lock.json
 M yarn.lock
```

### 5.4 Hashes das fontes

```text
prompt-reformulacao-crm.md E43BE28B2D88C03DC6A5F16C0DC3FB627ED98EC9C18905070A3E752A3FF50533
AUDITORIA.md 85F78FDB024C9E9D9089DD469531CF34327F7A3FF3D7CFB7715992295EF641A5
AUDITORIA-CSS.md 88B7749AB9DA2BB8F5122BB199BFB2F3DEE56CB8C1349676809B3769BD4DB655
AUDITORIA-FUNCIONAL.md E3E88F00CD880D117A00A098EED024A291ABBC945E8283094C1AD2D6E96119FB
DECISOES.md A9982251989E8AD5D61B831E688AB7416B6634B3589BFAA14D134B9FB0340A17
SETUP.md 30723CC3FF80A91D35568C1B50724402667C16F315B51ECF1BA2FA7C5B8863EA
docs\audit\INVENTARIO-ROTAS.md 4852241C23E289E4ED5EF08F82837BE107B835814A0FCEA172FB9B86FD01B6C5
```

## 6. Inventário bruto (`git status --short -uall`)

Cada entrada abaixo é coberta pelas regras da seção 3 ou permanece explicitamente incerta; nenhuma será removida silenciosamente.

```text
 M .env.example
 M .env.prod.example
 M .gitignore
 M core/Dockerfile
 M core/app/controllers/api/v1/accounts/captain/conversation_states_controller.rb
 M core/app/controllers/api/v1/accounts/crm/activities_controller.rb
 M core/app/controllers/api/v1/accounts/crm/base_controller.rb
 M core/app/controllers/api/v1/accounts/crm/deals_controller.rb
 M core/app/controllers/api/v1/accounts/crm/pipeline_stages_controller.rb
 M core/app/controllers/api/v1/accounts/crm/triage/from_conversation_controller.rb
D  core/app/controllers/api/v1/accounts/crm_controller.rb
 M core/app/javascript/dashboard/api/captain/conversationState.js
 M core/app/javascript/dashboard/api/crm.js
 M core/app/javascript/dashboard/components/captain/CaptainConversationStateCard.vue
 M core/app/javascript/dashboard/components/crm/CRMDealCard.vue
 M core/app/javascript/dashboard/components/crm/CRMDealDrawer.vue
 M core/app/javascript/dashboard/components/crm/CRMExportButton.vue
 M core/app/javascript/dashboard/components/crm/CRMKanbanChatDrawer.spec.js
 M core/app/javascript/dashboard/components/crm/CRMKanbanChatDrawer.vue
 M core/app/javascript/dashboard/components/crm/CRMLegalAreaBadge.vue
 M core/app/javascript/dashboard/components/crm/CRMSidebarCard.vue
 M core/app/javascript/dashboard/components/widgets/conversation/ConversationSidebar.vue
 M core/app/javascript/dashboard/helper/actionCable.js
 M core/app/javascript/dashboard/i18n/locale/en/index.js
 M core/app/javascript/dashboard/i18n/locale/pt_BR/index.js
 M core/app/javascript/dashboard/routes/dashboard/captain/score/Index.vue
 M core/app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue
 M core/app/javascript/dashboard/routes/dashboard/crm/crm.routes.js
 M core/app/javascript/dashboard/routes/dashboard/crm/pages/Agenda.vue
 M core/app/javascript/dashboard/routes/dashboard/crm/pages/AllLeads.vue
 M core/app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndex.vue
 M core/app/javascript/dashboard/routes/dashboard/crm/pages/DealDetails.vue
 M core/app/javascript/dashboard/routes/dashboard/crm/pages/LossReasons.vue
 M core/app/javascript/dashboard/routes/dashboard/crm/pages/Reports.vue
 M core/app/javascript/shared/components/specs/__snapshots__/DateSeparator.spec.js.snap
 M core/app/javascript/shared/components/specs/__snapshots__/Spinner.spec.js.snap
 M core/app/jobs/crm/health_check_job.rb
 M core/app/listeners/action_cable_listener.rb
 M core/app/mailers/administrator_notifications/account_notification_mailer.rb
 M core/app/models/account.rb
 M core/app/models/captain_conversation_state.rb
 M core/app/models/crm_activity.rb
 M core/app/models/crm_deal.rb
 M core/app/presenters/conversations/event_data_presenter.rb
 M core/app/services/crm/deal_creator.rb
 M core/app/services/crm/health_check_service.rb
 M core/app/services/message_templates/hook_execution_service.rb
 M core/app/views/api/v1/accounts/search/_conversation_search_result.json.jbuilder
 M core/app/views/api/v1/accounts/search/conversations.json.jbuilder
 M core/app/views/api/v1/conversations/partials/_conversation.json.jbuilder
 M core/app/views/api/v1/models/_conversation.json.jbuilder
 M core/config/agents/tools.yml
 M core/config/routes.rb
 M core/db/schema.rb
 M core/enterprise/app/jobs/messages/audio_transcription_job.rb
 M core/enterprise/app/jobs/messages/media_understanding_job.rb
 M core/enterprise/app/services/messages/audio_transcription_service.rb
 M core/enterprise/app/services/messages/media_understanding_service.rb
 M core/lib/events/types.rb
 M core/lib/llm/gemini_multimodal_service.rb
 M core/package.json
 M core/pnpm-lock.yaml
 M core/spec/controllers/api/v1/accounts/conversations_controller_spec.rb
 M core/spec/controllers/api/v1/accounts/crm/agenda_events_controller_spec.rb
 M core/spec/controllers/api/v1/accounts/crm/deals_controller_spec.rb
 M core/spec/enterprise/services/messages/audio_transcription_service_spec.rb
 M core/spec/presenters/conversations/event_data_presenter_spec.rb
 M core/swagger/definitions/resource/conversation.yml
 M docker-compose.dev.yml
 M docker-compose.prod.yml
 M docker-compose.yml
 D docs/system-audit-report.md
 M infra/deploy.sh
 M scripts/backup.ps1
 M services/orchestrator/Dockerfile
 M services/orchestrator/package-lock.json
 M services/orchestrator/package.json
 M services/orchestrator/src/app.ts
 M services/orchestrator/src/queues/index.ts
 M services/orchestrator/src/routes/agent.ts
?? AUDITORIA-CSS.md
?? AUDITORIA-FUNCIONAL.md
?? AUDITORIA.md
?? DECISOES.md
?? PLANO-REFORMULACAO-CRM.md
?? SETUP.md
?? core/app/controllers/api/v1/accounts/captain/ai_center_controller.rb
?? core/app/controllers/api/v1/accounts/crm/options_controller.rb
?? core/app/javascript/dashboard/components/crm/CRMConfirmDialog.vue
?? core/app/javascript/dashboard/components/crm/CRMDealOutcomeControl.spec.js
?? core/app/javascript/dashboard/components/crm/CRMDealOutcomeControl.vue
?? core/app/javascript/dashboard/helper/conversationIdentifier.js
?? core/app/javascript/dashboard/helper/crmMoney.js
?? core/app/javascript/dashboard/helper/crmOptions.js
?? core/app/javascript/dashboard/helper/specs/conversationIdentifier.spec.js
?? core/app/javascript/dashboard/helper/specs/crmMoney.spec.js
?? core/app/javascript/dashboard/i18n/locale/en/crm.json
?? core/app/javascript/dashboard/i18n/locale/pt_BR/crm.json
?? core/app/javascript/dashboard/routes/dashboard/crm/pages/AiCenter.spec.js
?? core/app/javascript/dashboard/routes/dashboard/crm/pages/AiCenter.vue
?? core/app/javascript/dashboard/routes/dashboard/crm/pages/crmDealsPagination.js
?? core/app/javascript/dashboard/routes/dashboard/crm/pages/crmDealsPagination.spec.js
?? core/app/jobs/crm/deals_export_job.rb
?? core/app/models/concerns/conversation_account_scoped.rb
?? core/app/services/crm/deal_filter_service.rb
?? core/app/services/crm/domain_options.rb
?? core/app/views/mailers/administrator_notifications/account_notification_mailer/crm_deals_export_complete.liquid
?? core/db/migrate/20260703000001_add_resume_tracking_to_captain_conversation_states.rb
?? core/db/migrate/20260703000002_add_handoff_reason_code_to_captain_conversation_states.rb
?? core/db/migrate/20260703000003_add_context_summary_tracking_to_captain_conversation_states.rb
?? core/lib/llm/transient_provider_error.rb
?? core/spec/controllers/api/v1/accounts/captain/ai_center_controller_spec.rb
?? core/spec/controllers/api/v1/accounts/captain/conversation_states_controller_spec.rb
?? core/spec/controllers/api/v1/accounts/crm/activities_controller_spec.rb
?? core/spec/controllers/api/v1/accounts/crm/triage/from_conversation_controller_spec.rb
?? core/spec/models/crm_conversation_tenancy_spec.rb
?? core/spec/services/crm/domain_options_spec.rb
?? docs/audit/INVENTARIO-ROTAS.md
?? everything-claude-code/
?? prompt-reformulacao-crm.md
?? services/orchestrator/src/routes/agentContract.ts
?? services/orchestrator/test/orchestrator.test.ts
```

## 7. Próxima revisão

Regerar este snapshot após cada lote aceito. Registrar para cada commit proposto: arquivos, classe, testes executados, resultado e mecanismo de rollback.

## 8. Revalidação de 2026-07-13

O snapshot bruto de 2026-07-10 não representa mais a quantidade atual de
arquivos. O worktree continua deliberadamente preservado e sem commit
automático. A revalidação encontrou 395 caminhos unstaged e uma exclusão
staged preexistente. O aumento inclui o trabalho acumulado de estabilização da
F0 e mudanças anteriores do usuário; ele não autoriza atribuir toda a autoria a
esta execução.

Novas classes de classificação:

| Classe | Escopo | Validação | Rollback |
|---|---|---|---|
| WT-DEPENDENCY | Rails 7.2.3.1, Devise 5, lockfile e compatibilidade Ruby | RSpec, Zeitwerk, audit e Brakeman | reverter apenas em lote temático e com novo audit |
| WT-TEST-HARDENING | fixtures/configurações determinísticas e compatibilidade Rails | suítes Core/Enterprise verdes | reverter junto do defeito correspondente |
| WT-CAPTAIN-SAFETY | fallback, FAQ JSON, handoff, resolução e plano | specs CAPITÃO/Enterprise | feature flag ou comportamento anterior documentado |
| WT-F0-EVIDENCE | CI, baseline, restore drill e documentos de execução | comandos e checksums registrados | substituir somente por evidência mais recente |

Evidências atuais:

- `F0-BACKEND-BASELINE.md`;
- `F0-FRONTEND-BASELINE.md`;
- `F0-RESTORE-DRILL-2026-07-13.md`;
- RuboCop em 2.632 arquivos sem ocorrências;
- Brakeman e Bundler Audit sem alertas ativos;
- todos os 181 arquivos de specs Enterprise exercitados sem falha.

Antes de qualquer commit, ainda é obrigatório gerar uma lista por lote e
separar mudanças do usuário, estabilização F0 e artefatos externos. Nenhum reset
global, descarte ou restage foi realizado.
