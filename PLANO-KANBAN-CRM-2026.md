# Plano de Reformulação — Kanban & CRM Conversacional

> **Escopo:** transformar o CRM do ChusteRM num "sistema operacional comercial" — Chatwoot (omnichannel) + Kommo (pipeline digital e automação) + Frappe/Twenty (UX de dados) + DeskcommCRM (governança de IA) — com o **Kanban como centro de gravidade** do produto.
>
> **Documento pai:** [PLANO-REFORMULACAO-CRM.md](PLANO-REFORMULACAO-CRM.md) — este plano é um recorte executável e **não** substitui o plano mestre. Onde houver conflito, este documento prevalece para o domínio Kanban/CRM.
>
> **Criado em:** 2026-08-28
> **Status:** proposto, aguardando aprovação
> **Branch alvo:** `refactor/crm-kanban-v2`

---

## 1. Sumário executivo

O backend do CRM do ChusteRM já é **mais profundo** que o de qualquer referência aberta analisada: 14 modelos de domínio, 9 jobs, 30+ serviços, cadências com matrícula, automações por etapa, scoring auditável, LGPD, Google Calendar e um analista de IA. O problema **não é falta de funcionalidade — é o Kanban não conseguir carregar esse backend**.

O Kanban atual:

- busca **todos** os deals do pipeline no front e filtra em JavaScript;
- **não escuta os eventos realtime** que o próprio backend já publica;
- **não tem ordenação dentro da coluna** (a tabela `crm_deals` não tem coluna `position`);
- **não tem visões salvas, limites de WIP, agregações de coluna nem virtualização**;
- carrega vocabulário jurídico fixo no código (`kind: "legal_intake"`), impedindo reuso;
- existe em **duas versões paralelas** (`CrmIndexLegacy.vue` com 2.538 linhas e `CrmIndexOperational.vue` com 599) atrás de feature flag.

Este plano corrige isso em **8 fases**, priorizando: (F1) fundação de dados e realtime → (F2) Kanban v2 → (F3) motor de automação WHEN/IF/THEN → (F4) IA governada → (F5) vocabulário/multi-nicho → (F6) governança e RLS → (F7) performance → (F8) hardening.

**Esforço estimado:** 10 a 14 semanas com 1 dev full-time. As Fases 1 e 2 sozinhas (≈4 semanas) entregam ~70% do valor percebido.

---

## 2. Benchmark — o que cada referência ensina

| Sistema | Base | O que copiar | O que **não** copiar |
| :--- | :--- | :--- | :--- |
| **DeskcommCRM** ([repo](https://github.com/melgarafael/DeskcommCRM), MIT, 706★) | Next.js 16 + Supabase, greenfield, WhatsApp-only | Radar, Flywheel, vocabulário configurável, WHEN/IF/THEN, teto de gasto de IA por org, RLS + testes de invariante no CI, update pela UI com rollback | A arquitetura inteira. É WhatsApp-only e jogaria fora Instagram, Messenger, webchat, e-mail e LINE que você já tem |
| **Kommo** ([digital pipeline](https://www.kommo.com/support/crm/pipeline-triggers/)) | SaaS, $15–45/user/mês | Digital Pipeline: gatilhos por *entrar/sair de etapa*, *lead criado*, *lead alterado*, *data atingida*; Salesbot como ação de automação dentro da etapa; ações ricas (enviar msg, criar tarefa, mover etapa, tag, trocar responsável) | Modelo de licenciamento por usuário; bot builder proprietário |
| **Frappe CRM** ([repo](https://github.com/frappe/crm), AGPL, Vue 3) | Frappe Framework + Frappe UI | Página única de deal (atividades + comentários + notas + tarefas no mesmo lugar); **visões customizadas** com filtro, ordenação e colunas salvas; alternância List ⇄ Kanban ⇄ Group-by | Framework Frappe (incompatível com Rails) |
| **Twenty** ([repo](https://github.com/twentyhq/twenty), AGPL, React) | NestJS + Postgres + Jotai | Command menu (⌘K), atalhos de teclado, saved views, objetos/campos customizados, workflows como cidadão de primeira classe | Monorepo Nx / stack React |
| **Pipedrive / Attio** | SaaS | Rotting visual por etapa, soma de valor no topo da coluna, drag com *ghost card* e otimismo, filtros como pills | — |
| **Mercado BR** ([SleekFlow](https://sleekflow.io/pt-br/blog/crm-kanban-whatsapp), [Letalk](https://letalk.com.br/blog/whatsapp-crm-novi/), [Nexloo](https://nexloohealth.com.br/crm-kanban-para-whatsapp/), Senqo/Plotado) | SaaS BR | Expectativa de mercado: **card = conversa**. Abrir o WhatsApp sem sair do board. Isso você já tem (`CRMKanbanChatDrawer`) e é seu maior diferencial — precisa ser polido, não reconstruído | Modelo de número único compartilhado |

**Conclusão do benchmark:** ninguém no conjunto tem *omnichannel maduro + CRM profundo + IA governada* junto. Esse é o espaço do ChusteRM. O gap é de **execução no Kanban**, não de escopo.

---

## 3. Diagnóstico do estado atual (com evidências)

### 3.1 O que já está pronto e é bom

| Camada | Evidência |
| :--- | :--- |
| Modelo de domínio | 14 modelos `crm_*` + `captain_*` — pipelines, stages, deals, activities, lead_scores, loss_reasons, cadences (+steps +enrollments), checklist_templates, automation_rules, audit_events, external_connections, intake_answers |
| API | 70+ métodos em [crm.js](core/app/javascript/dashboard/api/crm.js) — CRUD, move, won/lost/reopen/archive/discard, bulk, export, métricas (8 endpoints), analista de IA |
| Jobs | `cadence_executor`, `cadence_message_sender`, `captain_triage`, `create_follow_up_activity`, `deals_export`, `health_check`, `recompute_lead_score`, `stale_detector` |
| Performance backend | [deals_controller.rb:12-40](core/app/controllers/api/v1/accounts/crm/deals_controller.rb#L12-L40) já resolve N+1 com counts agregados (`pending_counts`, `stale_deal_ids`, `next_due_map`, `ai_state_map`) — **está correto** |
| Chat no board ⚠️ | [CRMKanbanChatDrawer.vue](core/app/javascript/dashboard/components/crm/CRMKanbanChatDrawer.vue) — 2.183 linhas, com busca na timeline, controle de modo da IA, envio de mensagem, troca de etapa. **Mas está fora do ar:** é importado só por `CrmIndexLegacy.vue`, e o board que renderiza é o Operational (F0.2, § D-04) |
| Eventos | [crm_deal.rb:191-203](core/app/models/crm_deal.rb#L191-L203) já despacha `CRM_DEAL_CREATED / UPDATED / DELETED` |

### 3.2 Lacunas críticas do Kanban

| # | Lacuna | Evidência | Impacto |
| :--- | :--- | :--- | :--- |
| **K-01** | **Carrega todos os deals e filtra no cliente** | `fetchAllCrmDeals()` pagina até esvaziar; `dealMatchesFilters()` filtra em JS ([CrmIndexOperational.vue:96-121](core/app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndexOperational.vue#L96-L121)) | Quebra em ~1.000 deals. Cada filtro = re-render total |
| **K-02** | **Sem realtime** | O dispatcher publica eventos, mas o front só tem `loadCrm({silent:true})` manual | Dois atendentes veem boards diferentes. Card movido por automação não aparece |
| **K-03** | **Sem ordenação dentro da coluna** | `crm_deals` não tem coluna `position`; index ordena `created_at: :desc` | Drag&drop só muda etapa. Não dá para priorizar a fila visualmente |
| **K-04** | **Sem virtualização** | `Draggable` renderiza todos os cards de todas as colunas | 500 cards = ~340k nós DOM (card tem 685 linhas de template) |
| **K-05** | **Sem visões salvas** | Filtros vivem só na query string (`pipeline_id`, `search`, `owner_id`, `priority`) | Cada atendente reconstrói o filtro todo dia |
| **K-06** | **Filtros pobres e hardcoded** | `priorityOptions` fixo em high/qualified/other por faixa de score | Não filtra por etapa, tag, valor, data, área, status operacional, estado da IA |
| **K-07** | **Sem agregação de coluna** | Colunas mostram só contagem | Não dá para ver R$ na etapa nem tempo médio |
| **K-08** | **Sem limite de WIP nem rotting configurável** | `stages.expected_duration_hours` existe no schema mas não é usado no board | `StaleDetectorJob` cria a atividade, o board não comunica urgência |
| **K-09** | **Duplicação legacy/operational** | `CrmIndexLegacy.vue` (2.538 loc) + `CrmIndexOperational.vue` (599) + o mesmo par em Deal, Agenda, Activities, AllLeads, PipelineSettings | 6 pares de arquivos = dívida de manutenção dobrada |
| **K-10** | **Vocabulário travado no jurídico** | `crm_pipelines.kind` default `"legal_intake"`; `CRMLegalAreaBadge.vue`; strings PT no código com `eslint-disable vue/no-bare-strings-in-template` | Impede vender o produto para outro nicho |
| **K-11** | **Sem command palette / atalhos** | — | Operação 100% no mouse |

### 3.3 Lacunas do motor de automação

| # | Lacuna | Evidência |
| :--- | :--- | :--- |
| **A-01** | Só existe **1 gatilho**: `stage_entered` | `crm_automation_rules.trigger_event` default `stage_entered`; `Crm::StageAutomation` só é chamado no move |
| **A-02** | Só **4 ações**: `create_activity`, `set_captain_mode`, `move_to_stage`, `assign_owner` | [stage_automation.rb:26-35](core/app/services/crm/stage_automation.rb#L26-L35). Faltam: enviar mensagem WhatsApp, aplicar tag, matricular em cadência, webhook de saída, atualizar campo, notificar |
| **A-03** | 🐛 **`assign_owner` é um no-op silencioso** | `execute_assign_owner` faz `@deal.update!(assigned_to_id:) if @deal.respond_to?(:assigned_to_id)` — mas o schema tem **`owner_id` e `assignee_id`**, não `assigned_to_id`. A guarda é sempre falsa: a regra roda, é auditada como executada e **não faz nada** |
| **A-04** | Regra presa a **uma** etapa | `crm_automation_rules.crm_pipeline_stage_id` é `null: false` — impossível criar regra de pipeline ou de conta |
| **A-05** | Sem simulação / dry-run | Não dá para testar uma regra antes de ativar |

### 3.4 Lacunas de governança

| # | Lacuna |
| :--- | :--- |
| **G-01** | Isolamento multi-tenant só por scoping de aplicação (padrão Chatwoot) — **sem RLS no Postgres** |
| **G-02** | **Sem teto de gasto de IA** por conta — custo de OpenRouter é ilimitado |
| **G-03** | Sem testes de invariante no CI (isolamento, RBAC, roteamento) |
| **G-04** | Sem Radar (visão de contatos em risco de não-resposta) |
| **G-05** | Sem Flywheel (conversa resolvida → conhecimento → sugestão de melhoria da IA) |

---

## 4. Matriz de decisão — copiar / adaptar / descartar

| Item da referência | Origem | Decisão | Fase |
| :--- | :--- | :--- | :--- |
| Digital Pipeline (gatilhos por etapa) | Kommo | ✅ **Copiar e superar** — mais gatilhos + condições + dry-run | F3 |
| Salesbot como ação de automação | Kommo | ✅ **Adaptar** — plugar `captain_flows` (já existe) como ação | F3/F4 |
| Vocabulário configurável do Kanban | DeskcommCRM | ✅ **Copiar** — `pipelines.vocabulary` jsonb | F5 |
| Radar (contatos em risco) | DeskcommCRM | ✅ **Adaptar** — estender `StaleDetectorJob` p/ visão dedicada | F4 |
| Flywheel (auto-melhoria da IA) | DeskcommCRM | ✅ **Copiar** — usa `captain_document_versions` que já existe | F4 |
| Teto de gasto de IA por conta | DeskcommCRM | ✅ **Copiar** — bloqueante | F6 |
| RLS no Postgres + invariantes no CI | DeskcommCRM | ✅ **Copiar** — em modo *defense-in-depth*, sem remover o scoping atual | F6 |
| Update pela UI com rollback | DeskcommCRM | ⚠️ **Adiar** — bom, mas fora do escopo Kanban | pós-F8 |
| Visões salvas (filtro+ordem+colunas) | Frappe / Twenty | ✅ **Copiar** | F2 |
| Alternância List ⇄ Kanban ⇄ Group-by | Frappe | ✅ **Copiar** | F2 |
| Página única do deal | Frappe | ✅ **Adaptar** — consolidar `DealDetails*` | F2 |
| Command menu ⌘K + atalhos | Twenty | ✅ **Copiar** | F2 |
| Campos customizados por objeto | Twenty | ⚠️ **Parcial** — `crm_deals.custom_fields` jsonb já existe; falta UI | F5 |
| Rotting + soma de valor na coluna | Pipedrive | ✅ **Copiar** | F2 |
| Card = conversa (chat no board) | Mercado BR | ⚠️ **Existe no código, não no ar** — `CRMKanbanChatDrawer` só é importado pelo board Legacy, que está desligado. Precisa ser portado para o Operational antes de polir | **F2.1-a**, depois F2.14 |
| Supabase / Next.js / RLS-first | DeskcommCRM | ❌ **Descartar** — migração custaria meses e perderia canais | — |
| WhatsApp-only | DeskcommCRM | ❌ **Descartar** | — |

---

## 5. Arquitetura alvo do Kanban

```
┌──────────────────────────────────────────────────────────────────┐
│  CrmBoard.vue  (arquivo único — legacy/operational unificados)   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ BoardToolbar: pipeline · visão salva · filtros (pills) ·    │  │
│  │               busca · agrupar por · List/Kanban · ⌘K        │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │ Column   │ │ Column   │ │ Column   │ │ Column   │            │
│  │ ┌──────┐ │ │          │ │          │ │          │            │
│  │ │ head │ │ │ 12 · R$… │ │ WIP 8/10 │ │          │            │
│  │ ├──────┤ │ │          │ │          │ │          │            │
│  │ │ virt │ │ │          │ │          │ │          │            │
│  │ │ list │ │ │          │ │          │ │          │            │
│  │ │ card │ │ │          │ │          │ │          │            │
│  │ │ card │ │ │          │ │          │ │          │            │
│  │ └──────┘ │ │          │ │          │ │          │            │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘            │
└──────────────────────────────────────────────────────────────────┘
        │                    │                      │
        ▼                    ▼                      ▼
 useCrmBoard()        useBoardRealtime()      CRMKanbanChatDrawer
 (estado + otimismo)  (ActionCable)           (WhatsApp inline)
        │                    │
        ▼                    ▼
 GET /crm/deals        CrmBoardChannel
 ?view_id | filtros    (CRM_DEAL_* → broadcast por conta)
 server-side           
```

### Princípios inegociáveis

1. **Filtro e ordenação são do servidor.** O front nunca recebe mais do que a coluna precisa mostrar.
2. **Toda mutação é otimista com rollback.** Mover card = UI muda na hora; erro = volta e mostra toast.
3. **Realtime é aditivo, não destrutivo.** Evento de outro usuário nunca sobrescreve edição local em andamento.
4. **Vocabulário vem do pipeline, nunca do código.**
5. **Cada card responde a uma pergunta: "qual é a próxima ação e quando?"** — princípio de *activity-based selling* que o código já persegue ([CRMDealCard.vue:82-96](core/app/javascript/dashboard/components/crm/CRMDealCard.vue#L82-L96)).

---

## 6. Fases

### Fase 0 — Preparação (2 dias)

| ID | Tarefa | Entregável | Status |
| :--- | :--- | :--- | :--- |
| F0.1 | Criar branch `refactor/crm-kanban-v2` a partir de `main` | branch | ⬜ pendente — o hotfix da F0.4 saiu em `fix/crm-assign-owner` |
| F0.2 | Congelar o par legacy/operational: inventariar as 6 duplas e marcar qual versão é a fonte de verdade | [`docs/execution/KANBAN-V2-INVENTARIO.md`](docs/execution/KANBAN-V2-INVENTARIO.md) | ✅ 2026-08-28 — fonte de verdade é `*Operational` nos 6; achado D-04 reescreve a F2.1 |
| F0.3 | Baseline de performance: medir TTI do board com 100 / 500 / 2.000 deals seedados | [`docs/qa/KANBAN-BASELINE.md`](docs/qa/KANBAN-BASELINE.md) | ✅ 2026-08-28 — harness em `qa/bench/` e `qa/e2e/tests/kanban-baseline.spec.ts`; metas da §10 recalibradas |
| F0.4 | 🐛 **Corrigir A-03 imediatamente** (`assign_owner` no-op) — é bug em produção, vai para `main` como hotfix | commit `fix(crm): assign_owner grava owner_id` | ✅ 2026-08-28 — branch local `fix/crm-assign-owner`; **falta subir e conferir regras salvas em produção** |

**DoD:** baseline registrado com números reais; hotfix A-03 em produção.

**Dívidas encontradas de passagem e não corrigidas:** [`docs/execution/KANBAN-V2-BACKLOG.md`](docs/execution/KANBAN-V2-BACKLOG.md) (B-01…B-05).

---

### Fase 1 — Fundação de dados e realtime (1,5 semana)

Sem isso, nada do Kanban v2 funciona.

| ID | Tarefa | Detalhe |
| :--- | :--- | :--- |
| F1.1 | ✅ **Migration: `crm_deals.position`** | `decimal(20,10)` **nullable** (o backfill da F1.2 preenche em lotes; `NOT NULL` só depois). Ordenação fracionária: inserir entre A e B = `(A+B)/2`. Index composto `(crm_pipeline_stage_id, position)` criado `concurrently` — a etapa já implica a conta, então `account_id` no índice não agrega. Migrations `20260828000001` e `20260828000002` |
| F1.2 | ✅ **Backfill de `position`** | `Crm::BackfillDealPositionsJob` (fila `async_database_migration`), disparado no deploy pela migration de dados `20260828000003`. Por etapa, em lotes, `ROW_NUMBER() * 1000` sobre `created_at DESC, id DESC` — a mesma ordem que o `DealsController#index` já renderiza, então **o backfill não muda o que o atendente vê**. Só toca linhas `NULL`, e o `WHERE` do `UPDATE` repete o predicado do CTE (`position IS NULL` + etapa) para que o READ COMMITTED descarte a linha que outra transação moveu no meio do statement. Lote = uma transação com `pg_try_advisory_xact_lock` por etapa: duas execuções simultâneas não leem o mesmo `base`. `UPDATE` em SQL cru de propósito, para não despejar 5.000 eventos de realtime pelos callbacks do `CrmDeal`. Medido: 5.000 negócios em 5 etapas → **682 ms**; segunda execução → **8 ms / 0 linhas**. Coberto por `spec/jobs/crm/backfill_deal_positions_job_spec.rb` (20 exemplos) |
| F1.3 | ✅ **`POST/PATCH /crm/deals/:id/move` aceita `before_id`/`after_id`** | `Crm::DealPositioner` calcula a posição no servidor a partir dos vizinhos que o cliente reporta — o cliente nunca manda um número. Convenção: `after_id` é o vizinho **acima** (posição menor), `before_id` o **abaixo**. Basta um dos dois; sem nenhum, o card vai para o topo da coluna. O teto é o **menor** entre o vizinho informado e o vizinho real no banco: sem isso, um cliente com a tela atrasada grava todo mundo no mesmo ponto médio (bench de 200 reordenações produziu **27 posições duplicadas** antes da correção, 0 depois). `Crm::DealMover` passou a distinguir troca de etapa de reordenação: **reordenar dentro da coluna não dispara `Crm::StageAutomation`, não audita `deal_stage_changed` e não valida `required_fields`** — arrastar um card três posições não é "entrar na etapa". Os quatro chamadores internos já barravam etapa igual, então nenhum regride. `position` passou a ser serializada. Rota aceita PATCH além de POST |
| F1.3-a | ✅ **Rebalanceamento da coluna** | Renumera a etapa com `ROW_NUMBER() * 1000` preservando a ordem, sob o **mesmo lock consultivo** do backfill da F1.2 (`Crm::StageAdvisoryLock`) — os dois renumeram a coluna e não podem rodar juntos. Só dispara no caso que realmente esgota a escala: bisseção entre dois vizinhos abaixo de `REBALANCE_THRESHOLD` (0,001). **Topo e fundo da coluna nunca bisseccionam, andam um gap inteiro** — bisseccionar o topo esgotava a escala em ~20 movimentos e fazia um "mover em massa" de 100 negócios disparar 4 rebalanceamentos de coluna dentro de uma requisição HTTP (medido). A posição pode ficar negativa, e tudo bem: a coluna não tem piso. Bench: bulk move de 100 → **0 rebalanceamentos, intervalo mínimo exatamente 1000**; 200 reordenações no mesmo ponto da fila → 0 duplicatas, ~8,5 ms por move |
| F1.4 | ✅ **Filtro server-side no `index`** | `Crm::DealFilterService` estendido, e ele passou a ser a **fonte de verdade da allowlist** — o controller pede as chaves permitidas em vez de manter cópia (a cópia já tinha divergido: filtrar o board por duas dispositions e exportar descartava a chave em silêncio). Todo filtro de igualdade aceita valor único ou lista. Novos: `value_min/max`, `created_after/before`, `stale`, `has_pending_activity` (aceita `false` de propósito — negócio aberto sem próxima ação é o estado mais alarmante do board), `ai_mode[]`, `label[]` (etiqueta não vive no negócio: o `LegalLabelSync` escreve na conversa e no contato, então filtra pelos dois), `q` como apelido de `search`, cobrindo também `legal_area` e `case_type`. `owner_id` aceita `__unassigned` misturado com donos reais. **Atividade e IA usam `EXISTS` correlacionado, não `IN`**: `crm_activities.crm_deal_id` é anulável e um único NULL faria `NOT IN` devolver board vazio. Número e data ilegíveis são ignorados em vez de calar o board. Subconsultas escopadas por conta (defesa em profundidade + não varrer `taggings` de todos os inquilinos). Medido com 5.000 negócios e 12 critérios simultâneos: **p95 3,0 ms** no filtro + contagem, **3,2 ms** na página de 50 (meta: < 300 ms). 4 testes de isolamento entre contas, embrião dos invariantes da F6.2 |
| F1.5 | ✅ **Endpoint de colunas** `GET /crm/pipelines/:id/board` | Devolve, por etapa ativa: `count`, `open_count`, `sum_value_cents`, `avg_days_in_stage`, `wip_limit`, `over_wip` e os primeiros 25 negócios (`per_column`, teto 100). **WIP e idade contam só negócios abertos**: `mark_won!`/`mark_lost!` não tiram o card da etapa, então um negócio ganho há três meses continua morando em "Qualificado" — contá-lo como trabalho em andamento fazia o teto disparar sozinho e o tempo médio virar ficção. Filtrar `status=open` no board inteiro seria pior: esvaziaria as colunas Ganho e Perdido de um funil que as tenha. Honra os filtros da F1.4, e os agregados respeitam o filtro. Cards ordenados por `position ASC NULLS LAST`, carregados em duas etapas (ids por coluna, depois **um** `includes` para o board todo). Medido com 8 etapas e 200 cards: **35 queries por requisição antes, 23 depois**. Roteado para o `DealsController` para reusar `serialize_deal` sem um refactor de 300 linhas no serializador de um sistema em produção. Migrations `20260828000004` (`wip_limit`, agora gravável pela API de etapas) e `20260828000005` (`stage_entered_at`, **sem backfill** — leitura usa `COALESCE(stage_entered_at, created_at)`). O `DealMover` só carimba `stage_entered_at` quando a etapa muda: reordenar não reinicia o relógio do rotting. Medido com 8 etapas: **548 ms com 2.000 negócios e 548 ms com 5.000** — o custo parou de crescer com o pipeline. O jeito antigo foi de 5.309 ms / 10 requisições para 13.358 ms / 25. Ressalva: **460 ms desse número é piso da bancada** (Windows, `RAILS_ENV=test`, sessão de integração); o custo próprio do endpoint é ~90 ms |
| F1.6 | ✅ **Paginação por coluna** `GET /crm/deals?stage_id=X&order=board&page=2` | O `index` ganhou `order`, com `board` (`position ASC NULLS LAST, created_at DESC`) e `recent`. Sem isso a página 2 voltava a ordenar por data e devolvia cards que a coluna já tinha mostrado — medido: pedir a página 2 de uma coluna de 30 trazia cinco repetidos da página 1. **O padrão continua sendo o mais recente primeiro**: `AllLeads`, a exportação e a query string existente dependem disso, e trocar o padrão não é trabalho desta fase. Ordenação desconhecida cai no padrão em vez de derrubar a requisição. `crm.js` ganhou `getBoard` e `getColumnPage`. Dívida registrada como **B-08**: offset não sobrevive a uma reordenação no meio da rolagem; o cursor de keyset entra na F2.2, quando a rolagem infinita for de fato ligada |
| F1.7 | ✅ **Realtime do board** — *reescrito em 2026-08-28: o plano contradizia o código* | O plano pedia um `CrmBoardChannel` novo. O transporte **já existe e roda**: `ActionCableListener#crm_deal_created/updated/deleted` → room `account_{id}` → `RoomChannel#ensure_stream` → `actionCable.js`, que já mapeia os três eventos. Criar um segundo canal seria duplicar o que está em produção (decidido com o dono do produto). O que faltava era o **conteúdo** do evento: sem `position` a outra sessão não sabe onde encaixar o card, e sem a etapa anterior não sabe de qual coluna tirá-lo — a única informação do evento que o receptor não tem como descobrir sozinho. `push_event_data` ganhou `position` e `stage_entered_at`; o evento de update ganhou `previous_stage_id`. Medido, 60 movimentações: **latência do servidor (escrita → evento pronto) p50 4,9 ms, p95 5,7 ms**. A metade do navegador só pode ser medida na F1.8, quando o board consumir o evento. Dívida: hoje todo evento de todo negócio chega ao socket de todo agente da conta, mesmo de pipelines que ele não abre — escopo por pipeline fica para a F7 |
| F1.8 | ⚠️ **Composable `useBoardRealtime()`** — código pronto, evidência de ponta a ponta pendente | `applyDealEvent` (puro, imutável) aplica o evento na lista de negócios; `createDealEventQueue` segura o evento enquanto o card está sendo arrastado e solta no `drop` — princípio 3 do plano: evento de outro usuário nunca sobrescreve edição local. Rajada guarda só o último estado por card, e exclusão vence atualização. Payload é **mesclado** sobre o card existente, não substitui: o evento é leve (F1.7) e sobrescrever apagaria contato, score e próxima ação. Pré-requisito descoberto na tarefa: `actionCable.js` mapeava os três eventos para o mesmo handler e **descartava o nome do evento** — sem isso não há como distinguir exclusão de atualização, e não há patch incremental possível. Ligado ao `CrmIndexOperational.vue`, que é o board no ar. **17 + 6 testes de unidade verdes.** O teste de duas sessões existe (`qa/e2e/tests/kanban-realtime.spec.ts`) mas **não foi executado**: o compose local serve assets pré-compilados e o container roda o frontend anterior a esta branch. Enquanto ele não rodar, o DoD da fase ("<1s entre dois navegadores") tem só a metade do servidor medida (p50 4,9 ms) |

**Migrations:** `20260828000001_add_position_to_crm_deals.rb`, `20260828000002_add_stage_position_index_to_crm_deals.rb`, `20260828000003_backfill_crm_deal_positions.rb` (dispara o job da F1.2) — ainda pendente: `add_wip_limit_to_crm_pipeline_stages` (F2.3)

**DoD:** dois navegadores lado a lado; mover card em um aparece no outro em <1s; filtro por 5 critérios retorna em <300ms com 5.000 deals seedados.

---

### Fase 2 — Kanban v2 (2,5 semanas) ⭐ núcleo do plano

| ID | Tarefa | Detalhe |
| :--- | :--- | :--- |
| F2.1 | ✅ **Unificar legacy/operational** — **fechada em 2026-08-28** | **Reescrito em 2026-08-28 pela F0.2** — ver [KANBAN-V2-INVENTARIO.md](docs/execution/KANBAN-V2-INVENTARIO.md). O `*Operational` é a fonte de verdade nos 6 pares (`crm_v2` está ligado, inclusive na conta real). Ordem obrigatória: ✅ **(a)** `PipelineSettings`, `Agenda`, `Activities` — **feito em 2026-08-28**: 8.435 linhas apagadas, wrappers de flag colapsados, `CrmUnifiedPages.spec.js` garante que renderizam o Operational mesmo com `crm_v2` desligado. Portada do Legacy uma correção que o Operational não tinha (placeholder do pipeline presumia Previdenciário — regra de produto 9); ✅ **(b)** `DealDetails` — **feito em 2026-08-28**, 1.780 linhas. Das duas lacunas que o inventário listou, só `discardDeal` era real: o `CRMDealDrawer` que a página já renderiza exclui o negócio, e o método do inventário (grep no arquivo da página) não enxergava componentes filhos. Descarte portado com os **quatro** motivos escolhíveis, em vez do motivo fixo diferente que cada superfície do Legacy usava (`invalid` na ficha, `no_lead` na lista, `spam` no board); ✅ **(c)** `AllLeads` — **feito em 2026-08-28**, 2.515 linhas. Pelo método corrigido eram **4** ações, não 7: `deleteDeal`, `markDealWon` e `updateDeal` já vinham do `CRMDealDrawer`. Portadas mover de etapa pela linha (otimista, com rollback), descartar (quatro motivos), cliente da base e recalcular score; ✅ **(d)** `CrmIndex` — **feito em 2026-08-28**, 2.538 linhas, depois da F2.1-a. Das 10 lacunas listadas, **3** eram reais (descartar, cliente da base, recalcular score) e foram portadas. `getActivities` não era lacuna: o board já lê `next_activity_due_at` do próprio negócio, e portar seria voltar a fazer uma requisição a mais. `CRMDealCard.vue` (685 linhas) foi apagado junto — era renderizado só pelo Legacy (achado D-05). **Zero `*Legacy.vue` no módulo CRM**. **Remove 15.268 linhas**, não ~4.000 |
| F2.1-a | ✅ **Chat no board Operational** | **Feito em 2026-08-28.** `CRMKanbanChatDrawer.vue` (2.183 linhas) era importado só pelo `CrmIndexLegacy`; o board no ar não abria o WhatsApp, e o item nº 2 do goal não existia na prática. Agora o card tem botão de atender, e o que acontece no chat (troca de etapa, modo da IA, ganho/perdido) é mesclado de volta no card **sem refetch do quadro** — recarregar a cada ação jogaria fora o ganho da F1.5. O chat cede a vez para a ficha quando o atendente pede editar. 7 testes
| F2.2 | ⚠️ **`CRMBoardColumn.vue`** — board consome o endpoint de colunas e rola dentro delas; virtualização em aberto | **Feito em 2026-08-28.** A lacuna K-01 continuava viva no board mesmo depois da F1.4/F1.5: ele chamava `fetchAllCrmDeals`, que pagina até esvaziar o pipeline. Agora: **uma requisição**, 25 cards por coluna, filtros como parâmetros, e os totais do cabeçalho vindos do servidor — não da contagem do que coube na tela. `CRMBoardColumn.vue` e `CRMDealCard.vue` extraídos (o board tinha passado de 800 linhas, regra 6; e a F2.4 estava sem componente para redesenhar, dívida B-11). A coluna pede a próxima página ao ser rolada, consumindo o `getColumnPage` que a F1.6 tinha construído sem consumidor (dívida B-12) — e descarta card repetido, porque o offset não sobrevive a uma reordenação no meio da rolagem (B-08). O card entra por **slot**, para servir também ao agrupar-por da F2.8 e à lista da F2.9. **Virtualização segue em aberto**: com 25 cards por coluna o DOM já é pequeno, e o número que decide (baseline F0.3: 34.634 nós) só existe servindo este frontend |
| F2.3 | ⚠️ **Cabeçalho de coluna rico** — parcial | Feito na F2.2 junto com o `CRMBoardColumn.vue`: nome, contagem **do servidor**, soma em R$, tempo médio na etapa e barra de WIP com estado (âmbar/vermelho quando estoura). Falta o menu da coluna (ordenar, selecionar todos, colapsar) |
| F2.4 | ⚠️ **Card redesenhado** — código pronto, falta screenshot | **Feito em 2026-08-28** segundo a §7. Hierarquia: nome do contato em peso máximo, referência do negócio **só quando diz algo que o nome não diz**, próxima ação logo abaixo. **Sem próxima ação virou bloco vermelho com botão de agendar em 1 clique** — é a meta de "<10% sem próxima ação" transformada em interface. Rotting pela borda (0–70% do prazo normal, 70–100% âmbar, acima vermelho) usando `expected_duration_hours` + o `stage_entered_at` da F1.5; borda esquerda com a cor da etapa. Máximo 2 badges + "+N". Três densidades persistidas no navegador do atendente. As regras viraram funções puras em `crmCardSignals.js` — "negócio aberto sem próxima ação é o estado mais alarmante" precisa de teste, não de CSS. **Zero `eslint-disable` de bare-string** (regra 7): 27 strings novas em `crm.json`, pt_BR e en. Falta o screenshot nos 4 breakpoints, que o gate exige |
| F2.5 | ✅ **Rotting visual** | Feito junto com a F2.4, que é onde o sinal aparece. `rottingSignal` em `crmCardSignals.js`: 0–70% do prazo da etapa é normal, 70–100% acende âmbar, acima do prazo fica vermelho com "parado há Xd". Sem `expected_duration_hours` configurado o card não acusa nada — inventar um padrão faria o board apontar etapas que ninguém definiu. Negócio fechado nunca apodrece |
| F2.6 | ⚠️ **Filtros como pills** — barra pronta, faltam os controles dos 12 critérios | **Feito em 2026-08-28.** `crmBoardFilters.js` é o contrato entre a barra e o endpoint: traduz estado de tela nos 12 parâmetros da F1.4 e traduz de volta em pill legível (id de etapa vira nome, centavos viram R$, faixa vira "60–79"). **`false` é um filtro, não uma ausência** — "sem próxima ação" é a pergunta que a meta de <10% faz, e é uma regra com teste, não um `if` no template. `CRMFilterPills.vue` mostra cada critério ativo com botão próprio de remover, "limpar tudo" e o contador de resultados somado dos totais que o servidor mandou por coluna. `aria-live` no contador. Fica ⚠️ porque a barra **mostra e remove** os 12, mas o toolbar só oferece controle para 3 (busca, responsável, faixa de score) — os outros 9 chegam pela query string ou pelas visões salvas da F2.7 |
| F2.7 | ⚠️ **Visões salvas** — completa, falta screenshot | **Feita em 2026-08-29.** Fecha a lacuna K-05 ("cada atendente reconstrói o filtro todo dia"). Backend: tabela `crm_board_views`, escopo `visible_to` (minhas + as que a equipe compartilhou, nunca a privada de outro nem de outra conta), CRUD em `/crm/board_views`. **A regra que o código protege não é CRUD, é posse**: visão compartilhada é da equipe para *usar* — editar e apagar respondem **404**, não 403, porque o cliente não precisa saber que existe visão de outra pessoa naquele id. `CRMViewsMenu.vue` separa "minhas" de "da equipe" e **não oferece** apagar nem compartilhar o que não é meu, em vez de deixar o servidor recusar depois; a visão da equipe mostra de quem é, que é o que faz o atendente confiar nela. Aplicar uma visão **substitui** o estado de filtro inteiro, não mescla — mesclar deixaria resto de filtro anterior pendurado. Mexer no filtro à mão limpa a visão ativa. Falhar em carregar as visões não derruba o board. 49 exemplos (29 backend + 20 frontend); `db:migrate` e `db:rollback` executados |
| F2.8 | ✅ **Agrupar por** | **Feito em 2026-08-29.** `stage` (padrão), `owner`, `score_band`, `legal_area`, `source`, `operational_status`, em `Crm::BoardGrouping`. A coluna deixou de ser sempre uma etapa: `column.id` virou **chave de balde em texto** (id de responsável, `hot`, `__unassigned`, nome de área) e a etapa passou a viver em `column.stage_id`, presente só no agrupamento por etapa — é ele que libera arrastar, paginar e criar. `meta.movable` diz ao front que arrastar entre faixas de score não salvaria nada, porque score é calculado e não escolhido. Colunas que não são etapa não recebem cor, teto de WIP nem prazo: inventar faria o cabeçalho mentir. Área e origem saem dos dados reais do pipeline (`distinct`), nunca de uma lista fixa — regra 9. **Três bugs pegos pela revisão e pelos testes:** criar negócio a partir de uma coluna de responsável mandava o id do usuário como `crm_pipeline_stage_id` e criava o negócio na etapa errada em silêncio quando os números coincidiam; o quadro inteiro caía no estado vazio fora do agrupamento por etapa (`:empty` olhava `stages`, que a F2.8 esvazia); e `moveDeal` passou a mandar a chave de texto no lugar da etapa. **Realtime:** um negócio **novo** não tem como ser posicionado fora do agrupamento por etapa — o cliente teria de repetir a regra do servidor —, então `isUnplaceable` manda o quadro perguntar de novo, com as rajadas fundidas num recarregamento só. A página passou de 800 linhas (regra 6) e foi quebrada em `CRMBoardToolbar.vue`, `CRMCreateDealDrawer.vue`, `useBoardViews`, `useBoardCards`, `useBoardDensity` e `useBoardDealActions` — 791 linhas agora. Dívidas novas: **B-18** (uma query por balde em `column_cards`) e **B-19** (controller em 860 linhas) |
| F2.9 | **Alternância Kanban ⇄ Lista** | Mesma visão salva, duas renderizações. Lista = tabela com colunas configuráveis, ordenação por header, seleção múltipla |
| F2.10 | **Drag&drop de verdade** | Reordenar dentro da coluna (F1.1) + mover entre colunas. *Ghost card*, drop zones destacadas, auto-scroll horizontal na borda, otimismo com rollback |
| F2.11 | **Ações em massa** | Barra flutuante ao selecionar: mover etapa, atribuir dono, aplicar tag, matricular em cadência, exportar, arquivar. Confirmação para >20 itens |
| F2.12 | **Command palette ⌘K** | Buscar deal/contato, ir para pipeline, aplicar visão, criar deal, ações no card selecionado |
| F2.13 | **Atalhos de teclado** | `j/k` navega cards, `Enter` abre drawer, `m` move, `a` atribui, `w` ganho, `l` perdido, `/` busca, `Esc` fecha |
| F2.14 | **Polir `CRMKanbanChatDrawer`** | É o diferencial. Garantir: envio confiável, indicador de digitando, respostas rápidas (canned responses do Chatwoot), anexos, alternância IA/humano com 1 clique, contexto do deal sempre visível |
| F2.15 | **Estados vazios e de erro desenhados** | Coluna vazia, board sem pipeline, filtro sem resultado, falha de rede com retry |

**Tabela nova:** `crm_board_views`

**DoD:** board com 2.000 deals arrasta a 60fps; visão salva restaura filtro+ordem+colunas; ⌘K abre em <100ms; zero `eslint-disable no-bare-strings` nos arquivos novos.

---

### Fase 3 — Motor de automação WHEN/IF/THEN (2 semanas)

Elevar `Crm::StageAutomation` a um Digital Pipeline no nível do Kommo.

| ID | Tarefa | Detalhe |
| :--- | :--- | :--- |
| F3.1 | **Migration: regra desacoplada da etapa** | `crm_pipeline_stage_id` vira nullable; adicionar `crm_pipeline_id` (nullable) e `scope` (`stage` / `pipeline` / `account`) |
| F3.2 | **Gatilhos (WHEN)** | `stage_entered` (existe), `stage_exited`, `deal_created`, `deal_updated` (com `changed_field`), `score_crossed` (limiar), `no_response_for` (N horas sem mensagem do contato), `activity_overdue`, `date_reached` (campo de data + offset), `inbound_message`, `cadence_finished` |
| F3.3 | **Condições (IF)** | Já existe `Crm::CadenceConditionEvaluator` — reusar. Estender para: score, valor, área, tag, dono, origem, status operacional, modo da IA, horário comercial, dias desde a criação |
| F3.4 | **Ações (THEN)** | Existentes: `create_activity`, `set_captain_mode`, `move_to_stage`, `assign_owner` (corrigida). **Novas:** `send_message` (template + variáveis, via Evolution), `apply_label`, `remove_label`, `enroll_in_cadence`, `run_captain_flow` (plugar `captain_flows` — o Salesbot do Kommo), `update_field`, `notify_user` (in-app + e-mail), `outbound_webhook`, `create_task` |
| F3.5 | **Encadeamento com guarda de loop** | Ação que dispara gatilho (ex.: `move_to_stage` → `stage_entered`) precisa de contador de profundidade (máx. 5) + detecção de ciclo, registrado no audit |
| F3.6 | **Dry-run / simulação** | "Testar regra" → roda contra os últimos 50 deals e mostra quem teria sido afetado e o quê. Não persiste |
| F3.7 | **Builder visual** | Reescrever `AutomationRules.vue` como editor WHEN → IF → THEN, com preview em linguagem natural: *"Quando um lead entra em Qualificação, se o score ≥ 60 e a área for Previdenciário, envie o template Boas-vindas e crie um follow-up para 24h"* |
| F3.8 | **Log de execução** | Nova tabela `crm_automation_runs` (`rule_id`, `deal_id`, `status`, `error`, `payload`, `duration_ms`). Aba "Execuções" com filtro por falha e **retry manual** |
| F3.9 | **Throttle e anti-flood** | Máx. N execuções por deal por regra por janela; respeitar janela de horário; jitter no envio de mensagem (anti-ban, ideia do DeskcommCRM) |

**Tabelas novas:** `crm_automation_runs`
**Migrations:** `20260915000001_generalize_crm_automation_rules.rb`, `20260915000002_create_crm_automation_runs.rb`

**DoD:** 10 gatilhos e 13 ações cobertos por teste; dry-run não persiste nada; loop de 6 níveis é interrompido e auditado; regra falha registra erro e permite retry.

---

### Fase 4 — IA no Kanban: Radar, Flywheel e handoff (1,5 semana)

| ID | Tarefa | Detalhe |
| :--- | :--- | :--- |
| F4.1 | **Radar** (do DeskcommCRM) | Visão dedicada: contatos com mensagem recebida sem resposta há > X (config por pipeline), ordenada por risco = f(tempo sem resposta, score, valor). Reusa `StaleDetectorJob`. Badge com contador no menu do CRM |
| F4.2 | **Sinal de IA no card** | O backend já entrega `ai_state` ([deals_controller.rb:32-34](core/app/controllers/api/v1/accounts/crm/deals_controller.rb#L32-L34)). Card mostra: 🤖 IA conduzindo / 👤 humano assumiu / ⏸ IA pausada + motivo do handoff. Clique alterna o modo |
| F4.3 | **Flywheel** (do DeskcommCRM) | Job noturno: conversas ganhas/resolvidas → extrai Q&A → propõe **nova versão** de documento do Captain (`captain_document_versions` já existe) → fila de aprovação humana no AI Center. Nada entra na base sem aprovação |
| F4.4 | **Próxima melhor ação no card** | `crm_deals.next_best_action` já existe e o orchestrator tem `nextBestAction.ts`. Expor no card em modo detalhado + botão "aplicar" que cria a atividade |
| F4.5 | **Análise de sentimento** | Guardar em `crm_deals.custom_fields.sentiment` na triagem. Vira filtro e sinal no card |
| F4.6 | **Handoff auditável** | Já existe (`handoff_reason_code`, `resume_tracking`). Falta: visão de auditoria de handoffs com motivo, tempo até resposta humana e taxa de retomada |

**DoD:** Radar lista os leads corretos contra dataset de teste; Flywheel nunca publica sem aprovação; alternar IA no card reflete em <1s no drawer de chat.

---

### Fase 5 — Vocabulário configurável e multi-nicho (1 semana)

Destrava vender o produto fora do jurídico.

| ID | Tarefa | Detalhe |
| :--- | :--- | :--- |
| F5.1 | **Migration: `crm_pipelines.vocabulary` jsonb** | `{ deal: "Caso", deal_plural: "Casos", contact: "Cliente", stage: "Fase", owner: "Advogado responsável", value: "Honorários" }` |
| F5.2 | **Presets por nicho** | `legal_intake` (atual), `sales`, `health`, `education`, `services`. Seed com etapas, motivos de perda e checklist sugeridos |
| F5.3 | **Composable `usePipelineVocabulary()`** | Todo texto do board passa por ele. Fallback para o preset |
| F5.4 | **Extrair strings hardcoded** | Remover todos os `eslint-disable vue/no-bare-strings-in-template` do módulo CRM. Popular `pt_BR/crm.json` e `en/crm.json` |
| F5.5 | **Generalizar `CRMLegalAreaBadge`** | Vira `CRMCategoryBadge`, dirigido por `pipelines.vocabulary.category_label` e por uma lista de categorias configurável |
| F5.6 | **UI de campos customizados** | `crm_deals.custom_fields` jsonb já existe. Adicionar `crm_pipelines.custom_field_schema` + editor em PipelineSettings + render no card/drawer/filtro |

**DoD:** criar pipeline "Vendas" com vocabulário próprio sem tocar em código; `grep -r "no-bare-strings" core/app/javascript/dashboard/routes/dashboard/crm` retorna vazio.

---

### Fase 6 — Governança: RLS, custo de IA e invariantes (1,5 semana)

| ID | Tarefa | Detalhe |
| :--- | :--- | :--- |
| F6.1 | **RLS nas tabelas `crm_*`** | *Defense-in-depth*: mantém o scoping Rails **e** ativa `ROW LEVEL SECURITY` por `account_id`, com a conta corrente definida por `SET LOCAL app.current_account_id` num `around_action`. Rollout tabela a tabela, atrás de flag |
| F6.2 | **Testes de invariante no CI** | Suite dedicada: (a) usuário da conta A **nunca** lê dado da conta B por nenhum endpoint CRM; (b) RBAC por papel; (c) automação não escapa da conta; (d) webhook não vaza. Gate obrigatório no merge |
| F6.3 | **Teto de gasto de IA por conta** | Nova tabela `captain_usage_ledger` (`account_id`, `period`, `tokens_in`, `tokens_out`, `cost_cents`, `model`). Config por conta: teto mensal + ação ao estourar (avisar / pausar IA). Gate no gateway OpenRouter |
| F6.4 | **Painel de custo de IA** | Custo por conta, por modelo, por skill, por dia. Projeção de fim de mês |
| F6.5 | **Auditoria navegável** | `crm_audit_events` já é populado. Falta UI: filtro por ator, ação, deal, período; export |

**Tabelas novas:** `captain_usage_ledger`

**DoD:** teste de isolamento falha propositalmente quando o scoping é removido (prova que o RLS pega); IA pausa automaticamente ao atingir o teto e registra no audit.

---

### Fase 7 — Performance e escala (1 semana)

| ID | Alvo | Meta |
| :--- | :--- | :--- |
| F7.1 | TTI do board (500 deals) | < 1,2s |
| F7.2 | TTI do board (5.000 deals no pipeline) | < 1,8s (só 25/coluna carregam) |
| F7.3 | `GET /crm/deals` com 10 filtros | p95 < 300ms |
| F7.4 | Drag&drop | 60fps sustentado com 2.000 cards no DOM virtual |
| F7.5 | Latência do realtime | p95 < 800ms |
| F7.6 | Bundle do módulo CRM | < 180kb gzip (lazy-load do drawer de chat e dos gráficos) |
| F7.7 | Índices | Revisar plano de query dos 12 filtros; adicionar índices parciais/compostos faltantes |
| F7.8 | Cache | Contadores de coluna em cache curto (30s) com invalidação por evento |

**DoD:** todas as metas medidas e registradas em `docs/qa/KANBAN-BASELINE.md` comparadas ao baseline da F0.3.

---

### Fase 8 — Hardening e aceite (1 semana)

| ID | Tarefa |
| :--- | :--- |
| F8.1 | Cobertura ≥ 80% no módulo CRM (RSpec + Vitest) |
| F8.2 | E2E Playwright: criar deal → mover → automação dispara → mensagem sai → IA assume → handoff → ganho |
| F8.3 | Regressão visual (320 / 768 / 1024 / 1440), tema claro e escuro |
| F8.4 | Acessibilidade: drag&drop operável por teclado, foco visível, ARIA nas colunas (`role="list"` / `listitem`), contraste AA |
| F8.5 | Reduced-motion respeitado nas animações do board |
| F8.6 | Revisão de segurança do módulo (agente `security-reviewer`) |
| F8.7 | Drill de rollback em staging |
| F8.8 | Documentação: `docs/execution/KANBAN-V2.md` + atualização do README |

---

## 7. Especificação do card (referência de design)

```
┌─────────────────────────────────────────────┐
│ ⬤ Maria Souza                        ⋯      │  ← nome do contato = peso máximo
│   Aposentadoria por idade                   │  ← ref. do deal (só se ≠ do nome)
│                                             │
│ ⚠ Ligar hoje · 14:00                        │  ← PRÓXIMA AÇÃO (vermelho se vencida,
│                                             │     âmbar se hoje, cinza se futura;
│                                             │     BLOCO VERMELHO se não existir)
│ ─────────────────────────────────────────── │
│  84  Previdenciário          R$ 12.400      │  ← score · categoria · valor
│                                             │
│  🤖  ⏱ 3d          [avatar do dono]         │  ← IA ativa · dias na etapa · dono
└─────────────────────────────────────────────┘
   ▲ borda esquerda: cor da etapa
   ▲ borda completa âmbar/vermelha = rotting
```

**Regras de hierarquia:**
1. O olho bate primeiro no **nome**, depois na **próxima ação**. Nada mais compete.
2. Deal aberto **sem próxima ação** é o estado mais alarmante do board — bloco vermelho "sem próxima ação", com botão de agendar em 1 clique.
3. Máximo 2 badges + "+N". O resto vive no drawer.
4. Densidade compacta esconde valor e categoria; detalhada adiciona `next_best_action` e último trecho da conversa.

---

## 8. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação |
| :--- | :--- | :--- | :--- |
| Remover `CrmIndexLegacy` quebra fluxo em produção | Média | Alto | F2.1 só entra depois de paridade funcional provada por E2E; feature flag por conta com rollback em 1 comando |
| Migration de `position` com backfill trava tabela grande | Baixa | Alto | Coluna nullable → backfill em batches por job → `NOT NULL` depois. Zero downtime |
| RLS quebra queries existentes | Média | Alto | Ativar tabela a tabela atrás de flag, com o scoping Rails intacto. Rollback = desativar a policy |
| Motor de automação entra em loop e dispara mensagens em massa | Média | **Crítico** | Guarda de profundidade (F3.5) + throttle (F3.9) + kill switch por conta + alerta em >50 execuções/min |
| Realtime causa "card pulando" durante edição | Alta | Médio | Fila de eventos aplicada no blur (F1.8); nunca sobrescrever campo em foco |
| Escopo do plano cresce e nada chega em produção | Alta | Alto | F1+F2 são um release fechado e entregável sozinho. F3–F8 são incrementos independentes |

---

## 9. Cronograma indicativo (1 dev full-time)

```
Semana  1  2  3  4  5  6  7  8  9 10 11 12 13 14
F0      █
F1      ▓  █  █
F2         ▓  █  █  █
F3                  ▓  █  █  █
F4                           ▓  █  █
F5                                 ▓  █
F6                                    ▓  █  █
F7                                          ▓  █
F8                                             ▓  █
                    ▲                             ▲
              RELEASE 1                     RELEASE 2
           (Kanban v2 utilizável)        (produto completo)
```

**Release 1 (semana 5):** Kanban v2 com realtime, filtros server-side, visões salvas, virtualização e chat polido. Já vale ir para produção.
**Release 2 (semana 14):** automação, IA governada, multi-nicho, RLS e performance.

---

## 10. Métricas de sucesso

> **Recalibrado em 2026-08-28 pela F0.3.** As metas originais foram escritas
> antes de qualquer medição e três delas estavam ancoradas em números errados.
> Baseline completo e metodologia: [docs/qa/KANBAN-BASELINE.md](docs/qa/KANBAN-BASELINE.md).
> Os valores originais ficam registrados na coluna "meta original" para rastro.

| Métrica | Baseline medido (F0.3) | Meta | Meta original |
| :--- | :--- | :--- | :--- |
| TTI do board (500 deals) | **1.720 ms** | < 1,2s | < 1,2s |
| TTI do board (2.000 deals) | **3.684 ms** | < 1,5s | — |
| TTI do board (5.000 deals) | não medido | < 1,8s | < 1,8s |
| `GET /crm/deals` com 10 filtros | **p95 53–72 ms** | manter p95 < 300ms | < 300ms |
| Carga completa do board, só rede (2.000) | **1.787 ms** | < 400ms (uma requisição por coluna) | — |
| **p95 do frame no drag** (2.000 cards) | **83–100 ms** | < 20ms | "60fps sustentado" ⚠️ |
| **max do frame no drag** (2.000 cards) | **133 ms** | < 50ms | — |
| Nós de DOM (2.000 cards) | **34.634** | < 5.000 (virtualizado) | — |
| Deals abertos **sem próxima ação** | não medido | < 10% | < 10% |
| Tempo médio até primeira resposta | não medido | −30% | −30% |
| Deals em rotting (> prazo da etapa) | não medido | < 15% | < 15% |
| Ações do board feitas sem sair do Kanban | ~0% | > 70% | > 70% |
| Linhas do módulo CRM front | **34.727** → **19.640** ✅ | < 20.000 após F2.1 | < 7.000 ⚠️ |
| Cobertura de teste do módulo CRM | não medida | ≥ 80% | ≥ 80% |
| Custo de IA por conta | ilimitado | com teto e visível | idem |

### Por que três metas mudaram

**Linhas do módulo CRM.** O plano dizia `~9.500`. O real é **34.727** (sem specs).
Nenhum recorte razoável do módulo chega a 9.500. Apagar os seis `*Legacy.vue`
inteiros remove **15.268** linhas — quase 4× as "~4.000" estimadas na F2.1 — e
ainda assim o módulo fica em 19.459. A meta `< 7.000` era inatingível por
construção; `< 20.000 após F2.1` é o alvo honesto.

**FPS do drag.** O medido contraria a premissa: a mediana já é 60 fps com 2.000
cards. O que degrada é a consistência — p95 do frame a ~90 ms e pior frame a
133 ms. "60 fps sustentado" já estaria batido na mediana e não capturaria o
engasgo real, então a meta passa a ser **p95 e max do frame**.

**Nós de DOM.** O plano estimava "500 cards = ~340k nós". O medido é **9.134 nós
para 500 cards** (~18 por card) e 34.634 para 2.000 — cerca de 30× menos. A
estimativa veio de `CRMDealCard.vue` (685 linhas), que só o board **Legacy** usa;
o board no ar é o Operational, com um `article` inline bem mais enxuto. A
virtualização (F2.2) continua justificada — pelos 34,6k nós e pelo p95 do frame,
não pelo motivo escrito originalmente.

---

## 11. Rastreabilidade

| Lacuna | Resolvida por | Release |
| :--- | :--- | :--- |
| K-01 filtro client-side | F1.4, F1.5, F1.6 | R1 |
| K-02 sem realtime | F1.7, F1.8 | R1 |
| K-03 sem ordenação | F1.1, F1.2, F1.3, **F1.3-a**, F2.10 | R1 |
| K-04 sem virtualização | F2.2 | R1 |
| K-05 sem visões salvas | F2.7 | R1 |
| K-06 filtros pobres | F1.4, F2.6 | R1 |
| K-07 sem agregação | F1.5, F2.3 | R1 |
| K-08 sem WIP/rotting | F2.3, F2.5 | R1 |
| K-09 duplicação legacy | F2.1 | R1 |
| K-10 vocabulário travado | F5.1–F5.5 | R2 |
| K-11 sem atalhos | F2.12, F2.13 | R1 |
| A-01 1 gatilho | F3.2 | R2 |
| A-02 4 ações | F3.4 | R2 |
| **A-03 `assign_owner` no-op** | **F0.4 (hotfix)** | **imediato** |
| A-04 regra presa à etapa | F3.1 | R2 |
| A-05 sem dry-run | F3.6 | R2 |
| G-01 sem RLS | F6.1 | R2 |
| G-02 sem teto de IA | F6.3, F6.4 | R2 |
| G-03 sem invariantes no CI | F6.2 | R2 |
| G-04 sem Radar | F4.1 | R2 |
| G-05 sem Flywheel | F4.3 | R2 |

---

## 12. Definition of Done global

Uma fase só fecha quando **todos** os itens abaixo são verdadeiros:

- [ ] Testes novos escritos **antes** da implementação (TDD), verdes
- [ ] Cobertura do escopo tocado ≥ 80%
- [ ] Zero `eslint-disable no-bare-strings` novo; strings em `crm.json`
- [ ] Nenhuma função > 50 linhas; nenhum arquivo > 800 linhas
- [ ] Migrations reversíveis e testadas em cópia do dump de produção
- [ ] Revisão pelo agente `code-reviewer`; CRITICAL e HIGH resolvidos
- [ ] Escopo com dado sensível revisado pelo `security-reviewer`
- [ ] E2E Playwright do fluxo afetado passando
- [ ] Regressão visual em 4 breakpoints, temas claro e escuro
- [ ] Métricas de performance medidas e comparadas ao baseline
- [ ] Feature flag e caminho de rollback documentados
- [ ] `docs/execution/KANBAN-V2.md` atualizado

---

## 13. Ordem prática para começar

**Atualizado em 2026-08-28.** A Fase 0 está fechada; F0.1 é o único item pendente.

1. ~~F0.4 — corrigir o `assign_owner` no-op.~~ ✅ Feito, em `fix/crm-assign-owner`.
   **Pendente:** subir para `main` e conferir se há regras `assign_owner` salvas
   em produção (`SELECT id, account_id, name, action_config FROM crm_automation_rules WHERE action_type = 'assign_owner';`).
2. ~~F0.3 (baseline)~~ ✅ e ~~F0.2 (inventário)~~ ✅ Feitos.
3. **Agora:** F1.1–F1.3 (`position` + move com ordenação).
4. **Depois:** F1.4–F1.8 (filtro server-side + realtime). A partir daqui o board
   vira outro produto — e é o que ataca o gargalo real medido na F0.3: os
   **1.787 ms de paginação sequencial** com 2.000 negócios. A API por requisição
   já está dentro da meta.
5. **Depois:** F2, começando por **F2.1-a** (levar o chat para o Operational),
   porque hoje o board no ar não responde WhatsApp, e só então a F2.1 na ordem
   (a)→(d) do inventário.

### O que a Fase 0 mudou no plano

| Achado | Efeito |
| :--- | :--- |
| D-01 · módulo tem 34.727 linhas, não ~9.500 | meta de linhas recalibrada (§10) |
| D-02 · F2.1 remove 15.268 linhas, não ~4.000 | dimensionamento da F2.1 |
| D-03 · 9.134 nós de DOM para 500 cards, não ~340k | justificativa da F2.2 corrigida |
| D-04 · chat no board está fora do ar | **F2.1 reescrita + nova F2.1-a** |
| A API já bate p95 < 300ms em todos os volumes | prioridade vai para F1.5/F1.6 (uma requisição por coluna), não para otimizar o endpoint |
| Drag: mediana 60fps, p95 do frame 83–100ms | meta da F7.4 passa a ser p95/max do frame |

---

## Referências

- [DeskcommCRM](https://github.com/melgarafael/DeskcommCRM) — MIT
- [Kommo — Digital Pipeline triggers](https://www.kommo.com/support/crm/pipeline-triggers/) · [Salesbot no Digital Pipeline](https://developers.kommo.com/docs/salesbot-dp) · [Configurar gatilhos do Salesbot](https://www.kommo.com/support/crm/configuring-the-salesbot-settings/)
- [Frappe CRM](https://github.com/frappe/crm) — AGPL
- [Twenty CRM](https://github.com/twentyhq/twenty) — AGPL
- [SleekFlow — CRM Kanban WhatsApp](https://sleekflow.io/pt-br/blog/crm-kanban-whatsapp) · [Letalk](https://letalk.com.br/blog/whatsapp-crm-novi/) · [Nexloo](https://nexloohealth.com.br/crm-kanban-para-whatsapp/) · [SocialHub](https://www.socialhub.pro/blog/crm-whatsapp-kanban-gestao-vendas/)
- Interno ativo: [PLANO-REFORMULACAO-CRM.md](PLANO-REFORMULACAO-CRM.md)
- Interno arquivado (histórico, ver [docs/archive/](docs/archive/)): [CRM-ROLLOUT-LOTE-1.md](docs/archive/CRM-ROLLOUT-LOTE-1.md), [CRM-ROLLOUT-LOTE-2.md](docs/archive/CRM-ROLLOUT-LOTE-2.md), [REDESIGN-ROLLOUT-FASES-4-A-8.md](docs/archive/REDESIGN-ROLLOUT-FASES-4-A-8.md), [DECISOES.md](docs/archive/DECISOES.md)
