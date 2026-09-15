# Changelog do Projeto — Reformulação do CRM

Memória executável do programa. Uma entrada por card/fechamento, com evidência.
(O prompt pedia `docs/CHANGELOG-PROJETO.md`; `docs/*` é ignorado no .gitignore,
então o arquivo vive em `docs/execution/` como os demais entregáveis.)

## 2026-07 — Sessão de diagnóstico + primeiros cards

### Documentação do programa (fases 0–3)

- `00-DIAGNOSTICO.md` — arquitetura real, inventário de rotas/telas, débito
  técnico com evidência, mapa de risco de merge com upstream v4.17.1,
  reconciliação dos audits históricos (achados já corrigidos não reaparecem
  como bugs atuais) e as 10 dores ordenadas por impacto.
- `00-BASELINE-METRICAS.md` — bundle Vite (~53,7 MB; `DashboardIcon` ~11 MB),
  latência dos endpoints medida via curl, contagens de rotas/specs, runtime.
- `01-BENCHMARK.md` — matriz temos/não-temos, top-25 RICE, 5 padrões de UX a
  adotar, vereditos das candidatas do prompt.
- `02-KANBAN.md` + `kanban.json` — board com 40+ cards, RICE, dependências e
  roadmap em 4 ondas.
- `03-DESIGN-SYSTEM.md` — estado real do Obsidian + Mineral (tokens `--ds-*` +
  `operationalTokens`), gaps de aplicação e regras de uso.

### Cards executados

- **CRM-001 (P1, E1)** — `Crm::DealOwnerAssigner` unifica os três caminhos de
  atribuição de dono (roteador, bulk action, automação de estágio) com flags
  explícitas `sync_assignee`/`sync_contact`. A ação em lote passa a auditar a
  mudança de dono do contato via `assign_crm_owner!` e o payload do evento
  `deal_owner_assigned` deixa de referenciar variável inexistente.
  Evidência: `rspec spec/controllers/api/v1/accounts/crm/deals_controller_spec.rb
  spec/services/crm/stage_automation_spec.rb spec/services/crm/deal_owner_assigner_spec.rb`
  → 54 exemplos, 0 falhas; rubocop 6 arquivos sem ofensas.
  Rollback: revert do commit `752c11b`; call sites voltam ao inline.
- **CRM-020 (P0, E3)** — spec de invariante cross-account
  (`spec/controllers/api/v1/accounts/crm/tenancy_spec.rb`): não-membro da
  conta da URL → 401; membro acessando id estrangeiro → 404 sem mutação,
  inclusive bulk_action com id estrangeiro; audit-events admin-only e sem
  vazamento entre contas. Evidência: 8 exemplos, 0 falhas.
  Rollback: n/a (só spec).
- **CRM-010 (P0, E2)** — o "chunk de 11 MB" era artefato de builds antigas; o
  peso real era `i18n-locales` (14,6 MB minificado) com as 56 traduções no load
  inicial. `dashboard/i18n` agora embute só `en` + `pt_BR` e carrega os demais
  sob demanda via `setI18nLocale` (App.vue, settings/account/Index.vue,
  v3/App.vue); removida a regra `manualChunks` que agrupava os locales; o dir
  parcial `locale/zh` (index.js sem JSONs, nunca servido) fica fora do glob.
  Evidência: `vite build` — `i18n-locales` eliminado, 51 chunks de idioma
  assíncronos (~250-440 kB cada), JS inicial ~14,9 MB → ~4,5 MB. eslint limpo.
  Rollback: revert do commit; volta o bundle único de traduções.
- **CRM-021 (P1, E3)** — verificado: `sanitize_custom_fields` já remove a chave
  reservada `captain_triage` nos params de create e update do deals_controller,
  e specs já cobrem os dois caminhos (`deals_controller_spec.rb:146,197`).
  Nenhuma mudança de código necessária — card fechado com evidência existente.
- **CRM-002 (P1, E1)** — auditoria verdadeira em `Crm::StageAutomation`: cada
  executor devolve `:executed` ou o motivo do skip (`duplicate_activity`,
  `no_conversation`, `no_captain_state`, `invalid_ai_mode`,
  `blank_stage_slug`, `stage_not_found`, `same_stage`, `max_depth`,
  `invalid_owner`) e o loop só grava `automation_executed_*` quando a regra
  realmente agiu — antes, todo caminho logava `executed` mesmo em no-op.
  Evidência: 14 exemplos, 0 falhas em stage_automation_spec; rubocop limpo.
  Rollback: revert do commit.
- **CRM-011 (P1, E2)** — baseline autenticado medido na conta 115 (2.000
  deals): 9 de 10 endpoints abaixo de ~110 ms; `crm/activities` é outlier a
  ~0,53 s por custo de serialização (7 queries, sem N+1). Seção nova em
  `00-BASELINE-METRICAS.md` §7 com tabela e baseline pós-CRM-010.
  Rollback: n/a (medida).
- **CRM-003 (P1, E1)** — nova tabela/model `crm_automation_runs`: cada
  avaliação de regra de estágio persiste status (`executed`/`skipped`/
  `failed`), `skip_reason` (vem dos motivos do CRM-002), `error`,
  `started_at`/`finished_at` e payload com stage_slug+action_type. Falha do
  executor é gravada antes de propagar; falha ao gravar o run nunca derruba
  a automação. `has_many` em `CrmDeal` e `CrmAutomationRule`, validação
  same-account. Evidência: 62 exemplos, 0 falhas; rubocop limpo; migration
  aplicada e reversível. Rollback: `rails db:rollback` + revert.
- **CRM-030 (P1, E4)** — auditoria dos módulos CRM secundários: páginas
  operacionais (Reports, LossReasons, ChecklistTemplates, AutomationRules,
  ScoringConfig, Cadences, CrmMetrics, AnalyticsCenter, PageTemplatesGallery)
  já estavam no design system; `AiCenter.vue` era a exceção — zero
  componentes DS, strings pt-BR hardcoded e paleta `n-slate` legada.
  Reescrita completa com `DsPageHeader`/`DsCard`/`DsBadge`/`DsButton`/
  `DsSkeleton`, tokens semânticos `ui-*` e i18n integral — novo namespace
  `CRM.AI_CENTER` em `en` e `pt_BR` (título, métricas, estados, ações,
  modos de IA e motivos de handoff). Comportamento preservado: summary,
  métricas, media status, conversas pausadas, abrir/retomar IA.
  Spec existente atualizada: seletor do botão "Retomar IA" passa a usar o
  ícone (`i-lucide-play-circle`) em vez do texto hardcoded.
  Evidência: vitest 2/2, eslint limpo, `vite build` ok (AiCenter 8,5 kB).
  Rollback: revert do commit; a página volta à versão anterior.
- **CRM-040 (P2, E5)** — remoção definitiva de `services/crm-service` e
  `services/identity-bridge` (45 arquivos). Os dois já estavam aposentados
  (ARQ-02/ARQ-03): sem serviço nos compose, sem consumidor no Core, CI só
  referencia o orchestrator. Limpeza: `scripts/seed.ts` perde a seção CRM
  (importava o schema do serviço morto — resta o seed de knowledge do
  orchestrator); `setup.sh` perde install/migrate/seed/health-checks dos
  dois; `POSTGRES_MULTIPLE_DATABASES` deixa de criar `chusterm_crm`/
  `chusterm_identity` em instalações novas (volumes antigos preservam os
  bancos para consulta histórica); `.env.example` perde `CRM_PORT`,
  `CRM_DB_URL`, `CRM_REDIS_URL`, `IDENTITY_BRIDGE_PORT`; comentários do
  orchestrator passam a documentar o formato JWT como legado (iss/aud
  `chusterm:identity-bridge`/`chusterm:internal` mantidos por
  compatibilidade com tokens emitidos). Evidência: vitest do orchestrator
  10/10; compose sem referências ativas. Rollback: `git revert` restaura
  os diretórios.
- **CRM-004 (P1, E1)** — runs de automação visíveis na UI. Novo endpoint
  `GET /crm/automation-runs` (`AutomationRunsController` + policy +
  `Account#has_many`), filtros `deal_id`/`automation_rule_id`/`status`,
  serializer com nome da regra e título do deal, escopo `Current.account`.
  Front: `CrmAPI.getAutomationRuns`; aba "Automações" na ficha do negócio
  (`DealDetailsOperational`) com status/skip_reason/erro/duração por run;
  botão "Execuções" por regra em `AutomationRules` expandindo lista sob
  demanda. Chaves `CARD.RUNS*` em `en/crm.json` (pt_BR usa fallback, como
  as demais chaves de AUTOMATION_RULES). Evidência: request spec 5/5
  (filtros, isolamento cross-account, não-membro→401); vitest
  AutomationRules 8/8 e DealDetails 18/18; rubocop+eslint limpos.
  Rollback: revert do commit.
- **CRM-005 (P1, E1 — QA do épico)** — suíte CRM completa
  (`spec/services/crm` + `spec/controllers/api/v1/accounts/crm`):
  316 exemplos, 0 falhas. O QA expôs e corrigiu dois débitos
  preexistentes fora dos cards do épico:
  - `channel_pipeline_provisioner_spec`: spec esperava slugs antigos
    (`novo-atendimento`/`qualificado`) — desde o AccountInitializer toda
    conta ganha pipeline default com os slugs universais, e o provisioner
    copia os estágios da fonte default. Spec reescrita para o contrato
    real (cópia por slug + fallback para o primeiro estágio quando o slug
    não existe no pipeline do canal).
  - `audit_events#index` **nunca funcionou**: `params[:action]` colide
    com o nome da action Rails (`'index'`), então `where(action: 'index')`
    esvaziava a listagem em 100% dos requests. Filtros agora lidos de
    `request.query_parameters`; spec ganhou exemplo de regressão do
    filtro `?action=` e `created_at` explícito no helper (o model tem
    `record_timestamps = false`).
  Evidência: rspec 316/0; rubocop limpo. Rollback: revert do commit.
- **CRM-012 (P1, E2)** — verificado, já implementado: cabeçalho de coluna
  mostra contagem do servidor + soma `sum_value_cents` (BRL) + valor
  ponderado + média de dias na etapa + WIP; cards envelhecem via
  `rottingSignal` (warning ≥80% do `expected_duration_hours`, late >100%,
  badge "STALE" + borda âmbar/vermelha). Evidência: vitest
  crmCardSignals 16 + CRMBoardColumn 14 + CRMDealCard 31 = 61 verdes.
  Nenhuma mudança de código.
- **CRM-013 (P1, E2 — QA do épico)** — re-medição de bundle pós-cards:
  orçamento mantido (JS inicial ~4,5 MB, nenhum chunk inicial novo >1 MB,
  51 idiomas assíncronos). `crm/activities` ~530 ms confirmado como custo
  de serialização sem N+1 — fica como débito de produto registrado em
  `00-BASELINE-METRICAS.md` §8. LCP das 5 telas fica pendente de passagem
  manual autenticada (registrado na seção e no board — CRM-025 cobre a
  passagem visual completa).
- **CRM-024 (P2, E3)** — verificado, já correto: `MetricsService#time_in_stage`
  lê `deal_stage_changed` + payload `to_stage_id` (mesmos identificadores do
  audit logger); `#stale_deals` usa uma agregação de `MAX(updated_at)` por
  deal e exclui quem tem atividade dentro do cutoff. Specs de
  `metrics_service_spec` cobrem os dois contratos (stage timing, stale com
  atividade recente/antiga/ausente). Nenhuma mudança de código.
- **CRM-023 (P1, E3)** — verificado com evidência ao vivo na conta 115
  (pipeline 37, estágio "Novo" com **1996 deals**):
  - Board: `per_column=25` devolve `count=1996` + `loaded=25` + agregados
    calculados no escopo completo (`sum_value_cents`, `open_count`,
    `avg_days_in_stage`), não só nos cards carregados.
  - Paginação: `GET /crm/deals?stage_id=200&order=board` percorre 40
    páginas × 50 = **1996 ids distintos, zero duplicatas** — o 201º deal
    (id 2183) é alcançável; `order=board` estabiliza a ordenação
    (`position ASC NULLS LAST, created_at DESC`).
  - Reconciliação: `sum_value_cents=219858900` no header bate **exato**
    com a soma dos `value_estimate_cents` dos 1996 deals paginados.
  - UI: `CRMBoardColumn` renderiza `column.count` (não `deals.length`) e
    emite `loadMore` no scroll via `getColumnPage(stage, page)`.
  Nenhuma mudança de código.
