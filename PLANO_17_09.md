# PLANO_17_09 — Auditoria e Plano-Base Universal do ChusteRM

**CRM conversacional multi-vertical sobre Chatwoot** · Data: 2026-09-17 · Branch auditada: `refactor/crm-deal-owner-assigner` (HEAD `2203d380bc`) · Base upstream: Chatwoot CE `v4.12.1` (6.809 commits atrás de `upstream/develop`; último tag `v4.17.1`)

> **Premissa deste plano:** o ChusteRM é um produto **universal** — vendas B2B/B2C, serviços, clínicas, imobiliário, educação, jurídico etc. O escritório de advocacia atual (Coimbra & Ruas / Dra. Paula) é o **primeiro cliente** e vira o **primeiro pacote de vertical** ("pack jurídico"), não o produto. Tudo que hoje pressupõe direito/INSS/advogado passa a ser configuração carregável por conta.
>
> Este documento **não substitui** `PLANO-REFORMULACAO-CRM.md` (plano-mestre com gates de evidência) nem `PLANO-KANBAN-CRM-2026.md`. É uma auditoria independente + roadmap de produto que aponta o que aqueles planos não cobrem — em especial o **acoplamento à vertical jurídica**, que nenhum deles trata como problema estrutural.

---

## 0. Sumário executivo

**Veredito:** a fundação técnica do ChusteRM já está acima da média dos "CRM de WhatsApp" do mercado (kanban com posição fracionária e realtime, filtros server-side, visões salvas, auditoria, LGPD, cadências, scoring explicável). O que falta não é feature — é **coerência** (duas IAs, três telas de analytics, três sistemas de tokens, dois chats que não se comportam igual) e **universalidade**: o núcleo está soldado à vertical jurídica em **92 arquivos de backend e 41 de frontend**, no schema (`legal_area`, `case_type`, `conflict_check_status`, `kind: 'legal_intake'`), nos jobs, no scoring, na IA e nas telas. O maior risco não é técnico, é **jurídico/licenciamento** (A1).

### Os 13 achados que mais importam

| # | Achado | Severidade | Onde |
|---|---|---|---|
| A0 | **Vertical soldada no núcleo.** `crm_deals.legal_area`/`case_type`/`conflict_check_status`/`documents_status`; `crm_pipelines.kind` default `legal_intake`; `CrmActivity::KINDS` = `analise_documental`, `revisao_juridica`, `envio_contrato`…; `LeadScoreCalculator` pontua "fit" só se `legal_area` presente; `StaleDetectorJob` com thresholds por slug jurídico; `LegalTriageAnalyzer`, `LegalLabelSync`, `LegalLabelSeedService`; playbooks e checklists indexados por `legal_area`; sidebar "CRM jurídico"; analista responde "leads de INSS"; prompts da Dra. Paula em `enterprise/` e no orchestrator. Uma conta de clínica ou imobiliária hoje recebe tudo isso. | 🔴 CRÍTICO (produto) | 92 arquivos backend + 41 frontend (`grep -rli "legal_area\|LegalTriage\|juridic\|INSS"`) |
| A1 | **Toda a IA (Captain) roda em `core/enterprise/`**, sob *Chatwoot Enterprise License*, com o LICENSE re-brandado para "ChusteRM Inc". O README diz que a pasta "não deve ser usada". | 🔴 CRÍTICO (negócio) | `core/enterprise/LICENSE`, `core/lib/chatwoot_app.rb:14-18`, 20 commits do fork em `enterprise/` |
| A2 | **WhatsApp via Evolution/Baileys (não-oficial)** no cliente real. Risco de banimento; nenhuma tela avisa o operador. | 🔴 CRÍTICO (operação) | `core/app/models/channel/whatsapp.rb:28` |
| B1 | **Chat do Kanban não é realtime**: `CRMKanbanChatDrawer.vue` (2.198 linhas) reimplementa o chat — sem ActionCable, anexos, nota privada (`private: false` fixo), respostas rápidas, status de entrega, áudio. | 🔴 ALTO (UX central) | `CRMKanbanChatDrawer.vue:918,1406` |
| B2 | **Triagem "IA" é regex jurídico e quebra com acento** (`divórcio`, `pensão alimentícia`, `cartão`, `rescisão` não casam); áudios ignorados; para qualquer vertical não-jurídica o resultado é `insufficient data` sempre. | 🔴 ALTO (dados) | `legal_triage_analyzer.rb:2-9, 86-100` |
| B3 | **Métricas incoerentes**: funil mistura etapas de todos os funis; KPI "Total 3" ao lado de funil com 201; "50%" com 0/0; taxa de ganho por coorte de `created_at`. | 🔴 ALTO (confiança) | `metrics_service.rb:8-45` |
| B4 | Contador do board "28 negócio(s)" com 201 no funil (soma cards carregados). | 🟠 MÉDIO | `CRMBoardToolbar.vue:138` |
| C1 | **Qualquer agente vê todos os negócios da conta** (Chatwoot restringe por inbox; CRM não). | 🟠 ALTO (privacidade) | `crm_deal_policy.rb` |
| C2 | **Front recebe dados internos**: `content_for_llm`, `additional_attributes`/`custom_attributes` inteiros, `score_reason` bruto, `identifier`, slugs sem label. | 🟠 MÉDIO | `deals_controller.rb:530-626`, `CRMDealCard.vue:397` |
| D1 | **Um negócio por conversa, um funil por inbox** → o mesmo cliente em WhatsApp + Instagram vira dois negócios. | 🟠 ALTO (modelo) | `idx_crm_pipelines_account_inbox_unique`, `triage_from_conversation.rb:45-80` |
| E1 | **Duas IAs para a mesma persona** (Captain em Rails/enterprise + Orchestrator em Node); o core não referencia o orchestrator (0 ocorrências em `app/ lib/ config/`), mas o container roda em produção. | 🟠 MÉDIO | `services/orchestrator/`, `docker-compose.prod.yml:71` |
| F1 | **Design system fragmentado**: 32 arquivos CRM com `ui-*`, 12 com `n-slate-*`, 3 com `ds-*`; 19/44 componentes com i18n desligado; 18 strings sem acento. | 🟠 MÉDIO | `components/crm`, `routes/dashboard/crm` |
| G1 | **Fork 6.809 commits atrás do upstream** — perdeu Templates Hub, setup guiado WhatsApp, macros `#`, calls, Captain com audiência/horário, relatórios clicáveis, SLA comercial, automações com atraso, Rails 7.2.3 e correções SSRF/CVE. | 🟠 ALTO | `docs/audit/AUDITORIA-UPSTREAM-DIFF-*.md` |

### Ordem de execução recomendada

1. **Decisões (1 semana):** A1 (enterprise), A2 (WhatsApp oficial), A3 (identidade da IA), e **A0: nome do modelo universal** (ver §5.2 — `category`/`subcategory` ou custom objects).
2. **Sprint de credibilidade (2 semanas):** B2, B3, B4, C2 e os 10 bugs pequenos.
3. **Chat = CRM (4–6 semanas):** substituir o drawer por composição do `MessagesView`+`ReplyBox` upstream; card com canal, última mensagem, não lidas.
4. **Núcleo universal + packs (5–6 semanas):** desacoplar a vertical (A0) junto com "um contato = um negócio" (D1) e visibilidade por papel (C1) — é a mesma migração de modelo.
5. **Uma IA só, com mãos e sem vertical no código (4–5 semanas):** E1 + tools de CRM + triagem por LLM parametrizada pelo pack.
6. **Sync upstream 4.17 (6–8 semanas, em paralelo):** G1.

Estimativa: **~7 meses com 2 devs + designer meio período** (10–11 meses com 1 dev). O desacoplamento da vertical adiciona ~1 mês em relação ao plano anterior; sem ele, cada novo cliente de outro segmento custa um fork.

---

## 1. Como esta auditoria foi feita

| Fonte | O que foi feito |
|---|---|
| Código | Leitura integral de `deals_controller.rb`, `crm_deal.rb`, `crm_activity.rb`, `CrmIndexOperational.vue`, `CRMDealCard.vue`, `CRMKanbanChatDrawer.vue`, `CRMSidebarCard.vue`, `DealDetailsOperational.vue`, `metrics_service.rb`, `legal_triage_analyzer.rb`, `triage_from_conversation.rb`, `stale_detector_job.rb`, `lead_score_calculator.rb`, `account_initializer.rb`, `analyst_service.rb`, `legal_label_seed_service.rb`, `crm_context_builder.rb`, `crm_deal_policy.rb`, `domain_options.rb`, listeners, schema (16 tabelas `crm_*`, 12 `captain_*`), `Sidebar.vue`, `crm.routes.js`, tools em `enterprise/lib/captain/tools`, `services/orchestrator/src`. Inventário por `grep` do acoplamento à vertical. |
| Testes | Vitest CRM: **28 arquivos / 242 testes verdes**. RSpec CRM: **345 exemplos / 0 falhas** (Postgres do compose em `127.0.0.1:5436`). |
| Visual | Screenshots do harness `qa/e2e` de hoje (conta fixture, 201 negócios): kanban light/dark, leads, métricas, Captain, contatos, settings. |
| Documentos | `PLANO-REFORMULACAO-CRM.md`, `PLANO-KANBAN-CRM-2026.md`, `docs/execution/01-BENCHMARK.md`, `05-RELATORIO-FINAL.md`, `KANBAN-V2-BACKLOG.md`, `docs/audit/AUDITORIA-UPSTREAM-DIFF-*.md`, memória de sessões (identidade Dra. Paula, escopo full-service, VPS). |
| Mercado | Pesquisa web datada (set/2026): Kommo, Pipedrive, HubSpot Breeze, Attio, Twenty, Intercom Fin, Clio Grow AI, Chatwoot changelog 2026, RD Station/Agendor/SocialHub, CRMs verticais (jurídico, clínicas). Fontes no apêndice D. |

Limitação: não naveguei autenticado (não digito senhas); usei screenshots do harness. Drawer de chat e ficha 360 auditados por código.

---

## 2. Retrato do sistema hoje

### 2.1 Arquitetura real

```
Cliente (WhatsApp via Evolution/Baileys · Instagram · Messenger · webchat · API)
        │
        ▼
core/ (Chatwoot CE 4.12.1 + fork)
 ├─ Inbox upstream (ChatList, MessagesView, ReplyBox, ContactPanel + CRMSidebarCard "CRM jurídico")
 ├─ CRM próprio: 16 tabelas crm_*, 20 controllers, 48 services, 10 jobs, 63 arquivos Vue
 │    Kanban (board 1 req, realtime, posição fracionária, visões salvas, agrupamentos)
 │    Leads · Atividades · Agenda (Google) · Cadências · Automações + runs · Scoring auditável
 │    Checklists (por legal_area/case_type) · Motivos de perda · LGPD · Marketing (Meta/Google/GA4)
 │    3 telas de analytics + AiCenter
 ├─ Captain (enterprise/) = a IA que responde ao cliente (identidade Dra. Paula, handoff, tools genéricas)
 └─ Triagem = Crm::LegalTriageAnalyzer (regex jurídico) → LeadScoreCalculator → ContactOwnerRouter → LegalLabelSync

services/orchestrator (Node · Fastify · BullMQ · OpenRouter) — "Dra. Paula v2" + agent profile registry
   → container em produção, sem consumidor no core
```

### 2.2 O que está genuinamente bom (preservar e generalizar)

- Board endpoint único com agregados server-side e paginação por coluna; posição fracionária com lock; realtime com fila durante o drag.
- Filtros server-side → visões salvas compartilháveis.
- Score explicável (`factors`), auditoria em toda escrita, LGPD nativa.
- `DealFilterService` com allowlist única (board, lista, exportação).
- `Crm::AccountInitializer` **já cria um "Funil Comercial Padrão" genérico** (Novo Lead → Qualificação → Proposta → Negociação → Fechamento) e motivos de perda universais — sinal de que a intenção universal existe; o resto do código é que não acompanhou.
- `agent profile registry` no orchestrator (CRM-043) — a semente certa para "um agente por vertical".
- Comentários inline explicam o porquê das decisões — raro e valioso.

### 2.3 Números

| Métrica | Valor |
|---|---|
| Arquivos com acoplamento à vertical jurídica | 92 backend · 41 frontend |
| Colunas de schema específicas da vertical | `crm_deals.legal_area/case_type/conflict_check_status/documents_status`, `crm_pipelines.kind='legal_intake'`, `captain_playbooks.legal_area`, `crm_checklist_templates.legal_area/case_type` |
| Linhas Vue no CRM | ~20.800 em 63 arquivos; 6 componentes > 1.000 linhas |
| Controller mais longo | `deals_controller.rb` 883 linhas (serialização inline) |
| Specs | RSpec CRM 43 arquivos (345 ex.) · Captain 73 · Vitest CRM 32 (242 testes) |
| Distância do upstream | 6.809 commits · 5 minors · 65 migrations |
| Serviços sem consumidor | `services/orchestrator` (ativo), `crm-service` e `identity-bridge` (pastas órfãs) |

---

## 3. Auditoria detalhada — achados por área

Legenda: 🔴 crítico · 🟠 alto · 🟡 médio · ⚪ baixo. IDs referenciados no plano (§6).

### A. Estratégico, legal e de produto

**A0 · Vertical jurídica soldada no núcleo** 🔴 — inventário completo em §5.3. Consequência prática: para atender uma clínica ou imobiliária hoje seria preciso (a) ignorar campos que aparecem em cards, filtros, drawers e relatórios, (b) aceitar que a triagem devolve `insufficient` sempre, (c) aceitar que o score "fit" é 0 (depende de `legal_area`), (d) ver "CRM jurídico" na sidebar, (e) treinar a IA que se chama Dra. Paula. Correção: §5 (núcleo + packs).

**A1 · Captain em `enterprise/` (Chatwoot Enterprise License)** 🔴 — `chatwoot_app.rb:14-18` liga enterprise se a pasta existir; LICENSE com "Chatwoot" → "ChusteRM Inc"; README diz que não deve ser usada. Opções: (a) licença self-hosted enterprise; (b) clean-room em `app/` do que o fork usa (ResponsePolicy, HandoffPolicy, tools, `Captain::Assistant`, `captain_conversation_states`); (c) orchestrator (Node, MIT, já escrito, já multi-perfil) como **a** IA via `AgentBot` webhook. **Recomendo (c) + (b) parcial** — e isso casa com A0: o registry de perfis do orchestrator é exatamente "um agente por pack".

**A2 · WhatsApp não-oficial (Baileys)** 🔴 — risco de ban; no jurídico soma-se OAB Prov. 205 (postura passiva); em qualquer vertical, comparativos BR de 2026 tratam "API oficial" como critério nº 1. Manter Evolution como modo de entrada + aviso na inbox + caminho de migração para Cloud API (upstream 4.17 tem setup guiado e health).

**A3 · Identidade da IA** 🟠 — divergência VPS ("sou a Dra. Paula") vs local ("assistente da equipe"). Vira campo do pack/assistente (`public_identity: self | assistant_of | brand`) com disclosure obrigatório na primeira mensagem e teste que falha sem ele.

**A4 · `Crm::DomainOptions::LEGAL_AREAS` mistura segmentos de negócio ("Comercial / Vendas", "Tecnologia / SaaS", "Varejo") com áreas do direito** 🟠 — sintoma de A0: alguém tentou generalizar por dentro da lista jurídica. `familia`, `consumidor`, `criminal` (destino do alias `penal`) nem constam.

### B. Bugs funcionais confirmados

| ID | Bug | Evidência | Correção |
|---|---|---|---|
| B1 | Chat do kanban sem realtime, anexos, nota privada, canned, status, áudio; string fixa "WhatsApp / inbox conectado"; `min-width: 40rem` quebra mobile | `CRMKanbanChatDrawer.vue` (0 ocorrências de `cable`/`subscribe`; `sendDraft` com `private: false`; `<textarea>` puro L1406-1440) | Recompor com `MessagesView`+`ReplyBox` upstream (§6 F1). Paliativo: assinar `message.created` via `emitter` (2h). |
| B2 | Triagem regex jurídico sem transliteração; áudio ignorado; inútil fora do jurídico | `legal_triage_analyzer.rb:2-9` (`divorcio`, `pensao alimenticia`, `cartao`, `indenizacao`, `prisao`); `transcript_text` só usa `message.content` (L86-100). Verificado em Ruby: "quero pensão alimentícia" → família=false | `I18n.transliterate`; incluir `transcribed_text`/`ocr_text`; depois **classificador por LLM com taxonomia do pack** (§6 F3). |
| B3 | Métricas incoerentes | `metrics_service.rb#overview` filtra `created_at >= 30d`; `#stage_funnel` sem `pipeline_id` mistura funis; `win_rate` por coorte; 2 queries/etapa | `pipeline_id` obrigatório ou agrupar por funil; fechamento por `closed_at`; `GROUP BY`; specs de contrato |
| B4 | "28 negócio(s)" com 201 | `CRMBoardToolbar.vue:138` usa `totalVisible` | usar `filteredTotal` (`CrmIndexOperational.vue:285`) |
| B5 | `criminal`/`familia`/`consumidor` fora de `LEGAL_AREAS` → slug cru | `domain_options.rb:8-22,56` | resolvido por A0 (taxonomia por pack) |
| B6 | Categoria exibida como slug no card (`previdenciario`) | `CRMDealCard.vue:397` | serializar `category_label`; usar badge existente |
| B7 | `aria-label` do drag handle diz "Abrir ficha" | `CRMDealCard.vue:160` | "Arrastar {name}" |
| B8 | Sidebar faz `GET /crm/pipelines` a cada 30 s em toda aba + no `focus` | `Sidebar.vue:391` | carregar 1x + evento ActionCable |
| B9 | Badge "Abertos" (plural do filtro) por lead na lista | `ptbr-leads-v2.png` | label singular |
| B10 | Stale = "sem audit event há N dias" — ignora mensagens do cliente e `expected_duration_hours` da etapa; thresholds por slug jurídico; N+1 | `stale_detector_job.rb:32-56` | threshold da etapa; `conversation.last_activity_at`; 1 query |
| B11 | "Ganhos vs Perdidos" 50% com 0/0 | screenshot | guarda de divisão |
| B12 | `serialize_attachments_for` sem limite | `deals_controller.rb:628-634` | limit / aba sob demanda |
| B13 | `CapiDispatchJob` em todo save de deal, sem conexão Meta | `crm_deal.rb:59-63` | guard com cache |
| B14 | `bulk_action` + `select_all` síncrono na request | `deals_controller.rb:187-206` | job + progresso |
| B15 | Atalhos globais (`/`, `Ctrl+F`, `Esc`) concorrem com command bar e navegador | `CrmIndexOperational.vue:750`, drawer | `useCrmCommandHotKeys` |
| B16 | `AnalystService` responde "leads de INSS" para qualquer conta; sugestões de pergunta em `CrmMetrics.vue:83` são jurídicas | `analyst_service.rb:30,73` | perguntas sugeridas vêm do pack |

### C. Dados que o front recebe e não deveria

| ID | Dado | Onde | Correção |
|---|---|---|---|
| C1 | **Todos os negócios da conta** para qualquer agente (`index?/show? → true`) | `crm_deal_policy.rb`, `deals_controller#index` | `CrmDeal.visible_to(user)`: admin tudo; agente → inboxes dele ∪ owner ∪ assignee. Spec por papel. |
| C2 | `content_for_llm` de cada mensagem | `deals_controller.rb:616` | remover; transcrição como campo explícito |
| C3 | `additional_attributes`/`custom_attributes` inteiros do contato | L548-549 | allowlist |
| C4 | `score_reason` bruto | `CRMSidebarCard.vue:596` | fatores em chips; `reason` só no audit |
| C5 | `captain_ai_mode`/`handoff_reason_code` crus + 4 mapas de label duplicados | serializer L497-498; `CRMSidebarCard`, `DealDetailsOperational`, `CRMKanbanChatDrawer`, `crmOptions` | `GET /crm/options` como fonte única |
| C6 | Título automático "Atendimento #123" | `triage_from_conversation.rb:57` | contato + categoria |
| C7 | `identifier` do contato | L542 | remover |
| C8 | Mensagens `activity` na aba Mensagens | `serialize_messages_for` | filtrar/renderizar como evento |

### D. Modelo de dados e regras

| ID | Achado | Correção |
|---|---|---|
| D1 | Deal por **conversa**, funil por **inbox** → N negócios por cliente | Deal por **contato** no funil (índice único já existe); `crm_deal_conversations` N:N; funil-por-inbox vira regra de roteamento |
| D2 | `mark_won!/mark_lost!` não tiram o card da etapa | etapas terminais por funil / coluna "Fechados" |
| D3 | 4 campos de "dono" (`deal.owner_id`, `deal.assignee_id`, `contact.crm_owner_id`, `conversation.assignee_id`) | dono do relacionamento (contato) + dono do negócio; deprecar `deal.assignee_id` |
| D4 | `operational_status` (9) × `status` (4) × `lifecycle_stage` × `relationship_status` | `status` + `disposition` no deal; lifecycle no contato |
| D5 | `custom_fields.captain_triage` chave reservada sanitizada no controller | coluna `triage` jsonb própria |
| D6 | Cadência envia sem checar consentimento/janela | guard |
| D7 | **Campos da vertical como colunas fixas** (`legal_area`, `case_type`, `conflict_check_status`, `documents_status`, `urgency_level`) | §5.2: `category`/`subcategory` universais + **custom fields definidos pelo pack** (schema jsonb com definição em `crm_field_definitions`) |
| D8 | `CrmActivity::KINDS` fixo em 10 tipos jurídicos (`analise_documental`, `revisao_juridica`, `envio_contrato`…) | tipos base universais (`call`, `meeting`, `task`, `follow_up`, `email`, `message`) + tipos extras por pack |
| D9 | `crm_pipelines.kind` default `legal_intake` | default `sales`; `kind` vira `template_slug` do pack |
| D10 | Labels `area_*` semeadas por `LegalLabelSeedService` em toda conta | seed por pack |

### E. Integração chat ↔ CRM ↔ IA

Três superfícies, três comportamentos:

| Superfície | Responder | Anexo/áudio | Nota privada | Realtime | Mover etapa | IA on/off | Próxima ação |
|---|---|---|---|---|---|---|---|
| Inbox upstream + `CRMSidebarCard` | ✅ completo | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Drawer do Kanban | textarea | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| Ficha do negócio | ❌ (link) | lista | ❌ | ❌ | ✅ | ❌ | ✅ |

- E1 · Duas IAs sem consumidor para a segunda (A1).
- E2 · A IA **lê** o CRM (`CrmContextBuilder`) mas **não escreve** — nenhuma tool `update_deal`, `move_stage`, `create_activity`, `set_category`, `request_info`. A triagem é um job desacoplado do que a IA conversou.
- E3 · Handoff não entrega resumo ao atendente onde ele responde (`CrmHandoffSummaryBuilder` existe, drawer não usa).
- E4 · Card sem canal, última mensagem, não lidas, "cliente esperando há X" — a informação nº 1 de um CRM conversacional.
- E5 · Abrir conversa completa = trocar de rota e perder o board.
- E6 · Sem indicação de janela 24h (Cloud) nem de canal não-oficial (Evolution).
- E7 · Prompt, identidade, playbooks e perguntas de intake da IA são jurídicos no código (`enterprise/`, `drPaulaMatosProfile.ts`, `captain_playbooks.legal_area`) — ver A0.

### F. UI / UX / Design system

| ID | Achado |
|---|---|
| F1 | 3 famílias de tokens (`ui-*` 32 arquivos, `n-slate-*` 12, `ds-*` 3; 2 arquivos com os três) |
| F2 | 19/44 componentes CRM com `eslint-disable no-raw-text`; 18 strings sem acento vazando ("Nao foi possivel", "Situacao") |
| F3 | Shell inconsistente: CRM (`DsPageHeader`/breadcrumb) vs Captain (header upstream) vs Contatos (`components-next`) |
| F4 | Configuração de IA em 4 lugares (`Captain > Assistentes`, `CRM > AI Center`, `Automação e Inteligência`, `Scoring`) |
| F5 | 3 telas de relatório sem drill-down |
| F6 | Card sem canal/última interação; "Parado" em 100% dos cards do fixture (tudo vermelho = nada vermelho) |
| F7 | Toolbar com 3 refs legadas sincronizadas por `pull/syncLegacyFilterRefs` com o estado real `filters` |
| F8 | Drawer de chat `position: fixed; inset: 0; min-width: 40rem` — sem versão mobile |
| F9 | Lista de leads: 5 filtros em 2 linhas + botão "Buscar" (board aplica ao mudar) |
| F10 | 6 wrappers `*.vue` de 15 linhas (código morto pós-F2.1) |
| F11 | Widget flutuante compete com barra de ações em massa |
| F12 | Sem estado offline/reconectando |
| F13 | **Copy da vertical na UI**: "CRM jurídico" (sidebar/ContactPanel), "Solicitar documentos", "Análise documental", "Revisão jurídica", "Quantos leads INSS…", `CRMLegalAreaBadge` |

### G. Performance

| ID | Achado | Correção |
|---|---|---|
| G1 | Sidebar polling 30 s (B8) | evento |
| G2 | `serialize_deal` fora do board: 3 queries/deal (`show`, `move`, `update`, bulk) | agregados por request |
| G3 | `stage_funnel`/`score_by_stage`: 2 queries × N etapas | `GROUP BY` |
| G4 | `StaleDetectorJob`: 1 query/deal aberto (banco de 10 GB) | `MAX(created_at) GROUP BY` |
| G5 | Anexos sem limite (B12) | limit |
| G6 | bulk síncrono (B14) | job |

### H. Segurança / tenancy / permissões

| ID | Achado | Sev. | Correção |
|---|---|---|---|
| H1 | Visibilidade de deals não segue inbox membership (C1) | 🟠 | scope por papel |
| H2 | `move` entre funis — **verificado OK** (`deal_mover.rb:132-134`) | ✅ | — |
| H3 | `apply_label` em bulk escreve no contato e na conversa sem checar policy de contato | 🟡 | checar `contact_manage` |
| H4 | `purge_orphans`/destroy em massa sem confirmação forte | ⚪ | UX "digite o nome" |
| H5 | Segredos históricos (Evolution key, token) sem evidência de rotação; sem `gitleaks` no CI | 🟠 | rotacionar + gitleaks |
| H6 | `analyst/ask` (LLM) e `export` sem throttle por usuário | 🟡 | Rack::Attack |
| H7 | `HttpTool` do Captain sem `SafeFetch`/SSRF filter (upstream 4.14.2 tem) | 🟠 | sync ou backport |

### I. Qualidade de código

- I1 · `deals_controller.rb` 883 linhas com 12 serializadores inline → `Crm::DealSerializer` (`card`/`detail`).
- I2 · 6 componentes > 1.000 linhas; `CRMKanbanChatDrawer` deve deixar de existir, não ser fatiado.
- I3 · 5 mapas de label duplicados em 4 componentes; backend já serve `GET /crm/options`.
- I4 · Pastas `services/crm-service` e `identity-bridge` órfãs com `node_modules`.
- I5 · `docs/execution/*` fora do git (`.gitignore:92`) — decisões só existem localmente.
- I6 · Rails 7.1 com deprecations 8.0; sync para 7.2.3 resolve.
- I7 · Node local 25 vs alvo 24 → `.nvmrc`.

### J. Fork drift (upstream 2026 já resolveu)

| Upstream | Fork | Ação |
|---|---|---|
| Templates Hub, setup guiado WhatsApp + health (ago–set/26) | wizard Evolution próprio | adotar; Evolution = provider a mais |
| Macros `#`, pickers `/ @ {{ :` com preview (ago/26) | ReplyBox 4.12 | adotar (beneficia o board quando usar o ReplyBox) |
| Captain audiência/horário, FAQ sugerido, `ai_assignee`, `conversation_outcomes` (v4.17) | `captain_conversation_states` próprio | **conflito alto** — decidir antes da Fase 3 |
| Automações com atraso (v4.17) | cadências horárias próprias | avaliar migrar cadências simples |
| Relatórios clicáveis, ordenar por não lidas, SLA comercial (ago/26) | 3 telas sem drill-down | adotar |
| Voice/WhatsApp Calling (jun/26) | fix de call no Evolution | adotar com Cloud API |
| `SafeFetch`/SSRF, MFA, sessões, Rails 7.2.3, Vite 6 | Vite 6 ✅, resto ❌ | sync |

---

## 4. Benchmark de mercado (set/2026)

Seleção: líderes em CRM conversacional/WhatsApp, em UX de CRM moderno, em IA embutida, no upstream, e **um exemplo de vertical bem feita** (jurídico, clínicas) para aprender como eles empacotam — não para copiar o nicho.

### 4.1 Padrão observado → decisão

| Produto | Padrão que vale copiar | Decisão | Fase |
|---|---|---|---|
| **Kommo** | Card **é** a conversa; histórico de todos os canais do contato numa tela; Salesbot no-code com handoff; **templates de pipeline por segmento** (imobiliário, educação, clínicas…) na criação da conta | **adotar** — inclusive o onboarding "escolha seu segmento" (§5) | F1, F2 |
| **Pipedrive** | Pipeline guiado por próxima atividade, rotting por etapa, soma por coluna, **MCP server nativo** (jun/26), previsão ponderada, **campos e tipos de atividade customizáveis por conta** | 70% já temos; **adotar** MCP e campos/atividades configuráveis (D7, D8) | F2, F3, F5 |
| **HubSpot Breeze** (Agent Hub, jul/26) | Agentes especializados ligados ao CRM; Customer Agent em 9 canais; lifecycle separado de deal stage; **custom objects** e propriedades por objeto | **adaptar**: 1 agente com perfis por pack; lifecycle no contato; custom fields (não custom objects ainda) | F2, F3 |
| **Attio** | IA dentro do modelo de dados (agentes gravam no registro); inline edit otimista; objetos e atributos totalmente configuráveis | **adotar** "IA escreve no CRM via tools auditadas" e inline edit; **experimentar** atributos configuráveis | F3, F4 |
| **Twenty** (open source) | Um sistema de tokens; command palette; MCP; core pequeno feito muito bem; **objetos customizáveis pela UI** | **adotar** disciplina de DS e escopo | F4 |
| **Intercom Fin** | Handoff com resumo e raciocínio; Copilot lateral; outcomes | **adotar** resumo; **adaptar** outcomes (upstream v4.17) | F3 |
| **Clio Grow AI** (jurídico, ago/26) | Intake 24/7 que coleta o suficiente para a decisão de negócio (conflict check), score por padrão de casos ganhos, agenda consulta, follow-up de pendências | **adaptar como pack**: "intake por categoria" é universal (clínica: sintoma/convênio; imobiliária: bairro/faixa/finalidade); conflict check é um **item de checklist do pack jurídico** | F3 |
| **Chatwoot upstream 2026** | Templates Hub, setup guiado, macros, Captain audiência/horário, relatórios clicáveis, SLA comercial, calls | **adotar via sync** | F5 |
| **RD Station / Agendor / SocialHub** (BR) | Tarefa criada de dentro do WhatsApp; kanban + respostas rápidas + agendamento de mensagem como mínimo; R$99–197 como âncora | temos o mínimo; **adotar** agendamento de envio | F5 |
| **SabioAdv / Chat Jurídico / clínicas (BR)** | API oficial como critério nº 1; "IA que qualifica e agenda" como promessa central de qualquer vertical | **adotar** aviso de canal não-oficial; agendamento como tool universal | F0, F3 |

### 4.2 Padrões a rejeitar

- Kommo: limites de leads por usuário e rigidez para ciclos longos → manter API aberta e modelo flexível.
- HubSpot: configuração extensa antes do valor → conta nova deve ter funil operante em < 10 min (`AccountInitializer` já faz; o **pack** só troca os defaults).
- Salesforce/Zendesk: administração pesada → uma tela de IA, uma de campos, uma de funis.
- "IA que é a pessoa" → identidade declarada sempre (A3).
- Custom objects completos agora (Attio/HubSpot) → YAGNI; custom **fields** por pack resolvem 90% e cabem no schema atual (`custom_fields` jsonb já existe).

### 4.3 Onde o ChusteRM já é melhor

Board com agregados server-side e paginação por coluna; score auditável; LGPD nativa; cadências + automações com runs; custo de infra self-hosted.

---

## 5. Arquitetura-alvo universal: núcleo + packs de vertical

### 5.1 Princípios

1. **O núcleo não conhece nenhum segmento.** Nenhuma string "jurídico", "INSS", "advogado", "clínica" em `app/`, `lib/`, `enterprise/`, `services/` ou `components/`. Tudo isso vive em **packs**.
2. **Um pack é dado, não código.** Arquivo YAML/JSON versionado em `config/crm_packs/<slug>.yml` + tabela `crm_account_packs` (qual pack a conta instalou, com overrides). Instalar um pack = semear registros; o núcleo lê registros, nunca o YAML em runtime.
3. **Uma conversa, um contato, um negócio aberto por funil.** Canal é atributo da conversa (D1).
4. **Um único composer**, onde quer que o atendente responda (B1/E4/E5).
5. **A IA lê e escreve no CRM por tools auditadas, com prompt e taxonomia vindos do pack, sempre identificada** (E2/E3/E7/A3).
6. **Um design system, um shell, uma fonte de labels** (`GET /crm/options` passa a devolver os labels do pack instalado).

### 5.2 O que muda no modelo de dados

| Hoje (jurídico fixo) | Alvo (universal) | Migração |
|---|---|---|
| `crm_deals.legal_area` | `crm_deals.category` (slug) — taxonomia de nível 1 do pack | rename + backfill 1:1 |
| `crm_deals.case_type` | `crm_deals.subcategory` (slug) — nível 2 | rename |
| `crm_deals.urgency_level` | mantém (universal: `critical/high/medium/low`) — labels do pack | só labels |
| `crm_deals.conflict_check_status`, `documents_status` | **removidos do schema**; viram itens de checklist do pack jurídico (`crm_checklist_templates` já existe) ou `custom_fields` | migração move valores para `custom_fields.pack.*` |
| `crm_deals.custom_fields` (jsonb sem definição) | mantém + nova `crm_field_definitions` (`account_id, object='deal'/'contact', key, label, type, options, required, position, pack_slug`) — renderização genérica no drawer/lista/filtros | nova tabela; packs semeiam definições |
| `crm_pipelines.kind` default `legal_intake` | `template_slug` (ex.: `sales_default`, `legal_intake`, `clinic_intake`, `real_estate`) default `sales_default` | rename + default |
| `CrmActivity::KINDS` (10 tipos jurídicos) | tipos base `call, meeting, task, follow_up, email, message, visit` + `crm_activity_types` por conta (pack adiciona `document_request`, `legal_review`, `exam`, `property_visit`…) | tabela nova; backfill mapeando os slugs atuais |
| `captain_playbooks.legal_area` | `captain_playbooks.category` | rename |
| `crm_checklist_templates.legal_area/case_type` | `category/subcategory` | rename |
| Labels `area_*` semeadas para todos | seed por pack (`LegalLabelSeedService` → `Crm::PackInstaller`) | — |
| `StaleDetectorJob::STAGE_THRESHOLDS` por slug | `crm_pipeline_stages.expected_duration_hours` (já existe, hoje ignorado) | código |
| `LeadScoreCalculator` "fit" = `legal_area.present?` | fatores genéricos (`category_match`, `intent`, `engagement`, `value`, `data_completeness`) com **pesos no pack** (`crm_pipelines.scoring_config` já existe) | código |
| `LegalTriageAnalyzer` (regex) | `Crm::Classifier` — LLM com saída estruturada (`category`, `subcategory`, `urgency`, `intent`, `fields`) usando a taxonomia do pack; fallback: regras do pack (opcionais) | serviço novo |
| `Crm::DomainOptions::LEGAL_AREAS/LEAD_SOURCES` | `LEAD_SOURCES` universal (mantém); categorias vêm do pack | — |
| `AnalystService` com intents `inss_leads` | intents genéricos (`by_category`, `unassigned_hot`, `stalled`, `by_owner`) + perguntas sugeridas do pack | código |
| Prompt/identidade da IA no código | `captain_assistants.pack_slug` + `system_prompt` e `public_identity` editáveis; orchestrator `agent profile registry` carrega perfil do pack | — |

**Decisão pendente (A0):** nomenclatura `category/subcategory` vs `segment/type` vs manter `custom_fields` puro. Recomendo `category/subcategory` como colunas indexadas (são usadas em filtro, board `group_by`, relatório e score) e **tudo o mais** em `custom_fields` com definição.

### 5.3 Inventário do que sai do núcleo e vai para o pack jurídico

| Camada | Item | Destino |
|---|---|---|
| Schema | `legal_area`, `case_type`, `conflict_check_status`, `documents_status`, `kind='legal_intake'`, índices `*_legal_area` | rename/remoção (§5.2) |
| Services | `LegalTriageAnalyzer`, `LegalLabelSync`, `LegalLabelSeedService`, thresholds do `StaleDetectorJob`, "fit" do `LeadScoreCalculator`, intents do `AnalystService`, `DomainOptions::LEGAL_AREAS`, `ScheduleSuggestionService` (verificar copy) | `config/crm_packs/legal.yml` + código genérico |
| Jobs | `CaptainTriageJob` → `ClassifyConversationJob` | genérico |
| Captain/enterprise | `enforce_dra_paula_identity`, `IDENTITY_DISCLOSURE`, saudações, seções "ÁREAS DE ATUAÇÃO", `CrmContextBuilder#context_legal_area`, `playbooks.for_legal_area` | prompt do pack + campo `public_identity` |
| Orchestrator | `drPaulaMatos.ts`, `drPaulaMatosProfile.ts`, `drPaulaMatosKnowledge.ts`, `eval:dr-paula` | perfil `legal_coimbra_ruas` no registry; eval por perfil |
| Frontend | `CRMLegalAreaBadge`, "CRM jurídico" (`ContactPanel.vue:44`, `ContactDetails.vue:32`), `activityKinds` em `DealDetailsOperational.vue:104-113`, `urgencyLabels/lifecycleLabels/...` (4 componentes), exemplos do analista (`CrmMetrics.vue:83`), `AutomationFlowBuilder` condições por `legal_area`, filtros de contato por `legal_area` (`contactProvider.js`) | `GET /crm/options` + `crm_field_definitions` |
| i18n | chaves `CRM.LEGAL_AREA.*`, `CRM.ACTIVITY_KINDS.*` jurídicas | labels vêm do pack; i18n só para o núcleo |
| Fixtures/QA | `Qa::CanonicalFixture` com áreas jurídicas | fixture por pack (`legal`, `sales_default`) |

### 5.4 Packs iniciais (conteúdo de cada um)

Cada pack define: **categorias/subcategorias**, **template(s) de funil** (etapas, probabilidade, `expected_duration_hours`, cor), **tipos de atividade extras**, **campos customizados** (deal/contato), **checklists**, **motivos de perda extras**, **pesos de score**, **perguntas de intake** que a IA deve cobrir, **prompt base + identidade + playbooks** da IA, **perguntas sugeridas** do analista, **labels** a semear.

| Pack | Categorias (ex.) | Funil | Campos | IA cobre |
|---|---|---|---|---|
| `sales_default` (núcleo, sempre instalado) | produto/serviço de interesse | Novo → Qualificação → Proposta → Negociação → Fechamento (já existe no `AccountInitializer`) | valor, origem, empresa | necessidade, prazo, orçamento, decisor |
| `legal` (cliente atual) | previdenciário, trabalhista, família, consumidor, cível, criminal, tributário, empresarial, imobiliário | Novo atendimento → Triagem → Qualificado → Consulta → Documentos → Análise → Proposta → Contrato | urgência, documentos, conflito de interesses, base LGPD | área, urgência, prazo, documentos, já tem advogado? |
| `clinic` | consulta, exame, procedimento, retorno | Novo → Triagem → Agendado → Compareceu → Orçamento → Fechado | convênio, especialidade, data preferida | sintoma/objetivo, convênio, urgência, horário |
| `real_estate` | compra, venda, locação | Novo → Qualificado → Visita → Proposta → Documentação → Fechado | tipo de imóvel, bairro, faixa, finalidade, financiamento | finalidade, região, faixa, prazo, financiamento |
| `education` | curso/turma | Novo → Contato → Aula experimental → Matrícula | curso, turno, forma de pagamento | curso, disponibilidade, pagamento |

Onboarding: na criação da conta (ou em `Configurações > CRM > Segmento`), o admin escolhe o pack; `Crm::PackInstaller` semeia; troca posterior é aditiva (não apaga dados).

---

## 6. Plano de melhorias por fases

**E** = pessoa-semana (dev sênior) · **Aceite** = como provar. IDs referem-se à §3.

### Fase 0 — Decidir e estancar (2 semanas · E≈2,2)

| # | Item | IDs | E | Aceite |
|---|---|---|---|---|
| 0.1 | ADR A1 (enterprise vs clean-room vs orchestrator) | A1, E1 | 0.2 | ADR em `DECISOES.md` |
| 0.2 | ADR A2/A3 (WhatsApp oficial; identidade da IA) | A2, A3 | 0.2 | ADR + copy |
| 0.3 | **ADR A0**: nomenclatura universal (`category/subcategory` + `crm_field_definitions`) e lista de packs iniciais | A0, D7 | 0.3 | ADR + esboço `config/crm_packs/legal.yml` |
| 0.4 | Triagem: transliteração + transcrições/OCR no transcript + specs com acentos (paliativo até F3) | B2 | 0.5 | 20 frases acentuadas verdes |
| 0.5 | Métricas: `pipeline_id` no funil, fechamento por `closed_at`, guarda 0/0, `GROUP BY` | B3, B11, G3 | 0.5 | KPI == soma do funil no fixture |
| 0.6 | Contador do board; label singular; badge com label; aria do drag; polling → evento; sidebar "CRM jurídico" → "CRM" | B4, B6–B9, F13 | 0.4 | screenshots antes/depois |
| 0.7 | Payload limpo (`content_for_llm`, `identifier`, atributos inteiros, `activity`) | C2, C3, C7, C8 | 0.3 | spec de chaves do serializer |
| 0.8 | `gitleaks` no CI, rotação de segredos, throttle `analyst/ask`/`export` | H5, H6 | 0.3 | CI + Rack::Attack spec |
| 0.9 | Remover `services/crm-service`, `identity-bridge`; versionar `docs/execution`; `.nvmrc` | I4, I5, I7 | 0.1 | repo limpo |

**Gate:** 3 ADRs aceitos; RSpec + Vitest verdes; 0 strings "jurídico/INSS" visíveis fora de contas com pack `legal`.

### Fase 1 — Chat = CRM (4–6 semanas · E≈5)

| # | Item | IDs | E | Aceite |
|---|---|---|---|---|
| 1.1 | `CRMConversationPanel` compondo `MessagesView`+`ReplyBox`+`ConversationHeader` upstream (mesma store, mesmo cable); substitui `CRMKanbanChatDrawer`; painel redimensionável | B1, E4, E5, F8, I2 | 2.5 | anexo, áudio, nota privada, canned pelo board; msg recebida sem reload (E2E) |
| 1.2 | Barra de contexto CRM no painel: etapa, dono, próxima ação (1 clique), IA on/off + motivo, ganho/perdido, score — reusando `CRMDealOutcomeControl`, `CRMNextActionBox`, `CaptainConversationStateCard` | E1 | 1 | mover etapa reflete no card sem refetch |
| 1.3 | **Card v5**: ícone do canal, última mensagem ("Você:"/"Cliente:"), não lidas, "cliente esperando há Xh", janela 24h ou aviso "não-oficial". Backend: `last_message_preview`, `unread_count`, `last_incoming_at`, `channel_type` no board (1 query `DISTINCT ON`) | E4, E6, F6 | 1 | 4 sinais no card; ≤ 25 queries no board |
| 1.4 | Ordenação da coluna por "cliente esperando" (toggle) | E4 | 0.3 | — |
| 1.5 | Resumo de handoff no topo do painel (`CrmHandoffSummaryBuilder`) | E3 | 0.4 | — |
| 1.6 | Atalhos unificados em `useCrmCommandHotKeys` | B15 | 0.2 | — |

### Fase 2 — Núcleo universal + packs (5–6 semanas · E≈6)

É uma migração de modelo só, feita em uma branch com feature flag `crm_universal` por conta.

| # | Item | IDs | E | Aceite |
|---|---|---|---|---|
| 2.1 | Renomes de schema (`category`, `subcategory`, `template_slug`), remoção de `conflict_check_status`/`documents_status` para `custom_fields`, `crm_field_definitions`, `crm_activity_types`, `crm_account_packs` | A0, D7, D8, D9 | 1.5 | migrações reversíveis; backfill validado no dump de 10 GB (restore drill) |
| 2.2 | `Crm::PackInstaller` + `config/crm_packs/{sales_default,legal}.yml`; `AccountInitializer` instala `sales_default`; tela `Configurações > CRM > Segmento` | A0 | 1 | conta nova sem pack = 0 termos jurídicos; conta com `legal` = paridade com hoje |
| 2.3 | Núcleo genérico: `StaleDetector` por `expected_duration_hours`; `LeadScoreCalculator` com pesos do pack; `AnalystService` genérico + perguntas do pack; `DomainOptions` sem `LEGAL_AREAS`; `GET /crm/options` devolve labels do pack | B10, B16, D10 | 1 | specs por pack |
| 2.4 | Frontend genérico: renderização de `crm_field_definitions` em drawer/lista/filtros/board `group_by`; `CRMLegalAreaBadge` → `CRMCategoryBadge`; remover 5 mapas de label duplicados e `activityKinds` fixos | F13, I3, C5 | 1 | grep "jurid|INSS|legal_area" em `app/javascript` = 0 |
| 2.5 | Deal por contato: `crm_deal_conversations` N:N; conversas novas anexam ao deal aberto; funil-por-inbox vira regra de roteamento | D1 | 1 | contato WA+IG = 1 deal |
| 2.6 | Visibilidade por papel `CrmDeal.visible_to(user)` em board/index/show/activities/export/bulk | C1, H1 | 0.5 | agente sem inbox → 404 |
| 2.7 | Dono único (contato + negócio; deprecar `assignee_id`); lifecycle no contato + `disposition` no deal; título = contato + categoria; etapas terminais | D2–D4, C6 | 0.8 | — |
| 2.8 | Fixture QA por pack (`legal`, `sales_default`) e E2E de "conta de clínica não vê nada jurídico" | — | 0.3 | E2E verde |

### Fase 3 — Uma IA, com mãos, parametrizada pelo pack (4–5 semanas · E≈4,5)

Depende de 0.1. Escrito para o caminho recomendado (orchestrator = cérebro via AgentBot; estado e tools no Rails em `app/`).

| # | Item | IDs | E | Aceite |
|---|---|---|---|---|
| 3.1 | **Tools de CRM auditadas** (`actor_type: 'ai'`): `get_deal_context`, `set_category`, `set_urgency`, `set_field` (só campos do pack), `move_stage` (etapas permitidas), `create_activity`, `schedule_appointment`, `request_info`, `mark_qualified` | E2 | 1.5 | ficha mostra "IA classificou como X (motivo)" |
| 3.2 | `Crm::Classifier` por LLM com saída estruturada e taxonomia do pack; fallback a regras opcionais do pack; substitui `LegalTriageAnalyzer`; coluna `triage` jsonb | B2, D5 | 1 | ≥ 85% no set rotulado por pack (criar 200/pack) |
| 3.3 | Intake por categoria (perguntas do pack, `crm_intake_answers`); checklists do pack como gates de etapa (no `legal`: conflito de interesses) | benchmark | 1 | — |
| 3.4 | Uma tela de IA: assistente, identidade (`self/assistant_of/brand`), prompt do pack + overrides, audiência/horário (upstream), tools habilitadas, teto de gasto, avaliação por perfil | F4, A3, E7 | 0.7 | `Captain > Assistentes` e `AiCenter` fundidos |
| 3.5 | Desligar a IA redundante; remover container morto; perfis do orchestrator = packs | E1, A1 | 0.3 | 1 processo de IA |

### Fase 4 — Design system e UI (3–4 semanas · E≈3, com designer)

| # | Item | IDs | E |
|---|---|---|---|
| 4.1 | Tokens únicos `ui-*`; lint proibindo `n-slate`/`ds-` em `components/crm` | F1 | 1 |
| 4.2 | i18n sem `eslint-disable`; 18 strings sem acento; pt_BR fonte | F2 | 0.7 |
| 4.3 | Shell único (`DsPageHeader`) em Captain/Contatos/Marketing; remover 6 wrappers | F3, F10 | 0.5 |
| 4.4 | Lista de leads com filtros vivos e chips (mesma toolbar do board) | F9, F7 | 0.5 |
| 4.5 | Estado offline/reconectando; z-index widget vs ações em massa | F12, F11 | 0.3 |
| 4.6 | Inline edit otimista (etapa, dono, valor, categoria, campos do pack) | benchmark | 0.5 |

### Fase 5 — Plataforma e upstream (6–8 semanas · E≈6, paralelo desde a F1)

| # | Item | IDs | E |
|---|---|---|---|
| 5.1 | Sync upstream 4.12.1 → 4.17.x (`04-UPSTREAM-SYNC-PLAYBOOK.md`): Rails 7.2.3 + SSRF → inbox (macros/pickers/templates) → Captain v2 (resolver conflito com `captain_conversation_states`) → automações com atraso → calls. Canário na VPS Chuster. | G1, H7, I6, J | 4 |
| 5.2 | WhatsApp: wizard único (Cloud API oficial + Evolution como provider), health, Templates Hub, aviso de canal não-oficial com contador | A2, E6 | 1 |
| 5.3 | Cadências com guard de consentimento/janela; migrar cadências simples para automações com delay | D6 | 0.5 |
| 5.4 | API pública documentada (OpenAPI) + **MCP server** (`deals.search/move`, `activities.create`, `contacts.timeline`, `fields.list`) | benchmark | 0.5 |

### Fase 6 — Relatórios que não mentem (2–3 semanas · E≈2)

| # | Item | IDs | E |
|---|---|---|---|
| 6.1 | Uma tela de relatórios (fundir 3) com filtro funil/período/dono/categoria e drill-down para a lista | F5, B3 | 1.2 |
| 6.2 | Tempo até 1ª resposta humana; % < 15 min; leads sem resposta > 1h | benchmark | 0.4 |
| 6.3 | Previsão ponderada por funil; relatórios salvos | benchmark | 0.4 |

---

## 7. Backlog priorizado (RICE, top 25)

Score = R×I×C/E (R = % usuários, I = 0,5–3, C = %, E = pessoa-semana).

| # | Item | Fase | R | I | C | E | RICE |
|---|---|---|---|---|---|---|---|
| 1 | ADRs A0/A1/A2/A3 (0.1–0.3) | 0 | 100 | 3 | 70 | 0.7 | 300 |
| 2 | Triagem com acentos + áudio (0.4) | 0 | 90 | 3 | 90 | 0.5 | 486 |
| 3 | Payload limpo (0.7) | 0 | 100 | 1.5 | 90 | 0.3 | 450 |
| 4 | Métricas coerentes (0.5) | 0 | 60 | 3 | 90 | 0.5 | 324 |
| 5 | Bugs visuais + copy "jurídico" fora (0.6) | 0 | 100 | 1 | 95 | 0.4 | 238 |
| 6 | Card v5 canal/última msg/não lidas (1.3) | 1 | 100 | 3 | 90 | 1 | 270 |
| 7 | Resumo de handoff no painel (1.5) | 1 | 70 | 2 | 80 | 0.4 | 280 |
| 8 | Barra de contexto CRM (1.2) | 1 | 100 | 2 | 85 | 1 | 170 |
| 9 | Painel com ReplyBox upstream (1.1) | 1 | 100 | 3 | 85 | 2.5 | 102 |
| 10 | Núcleo genérico: stale/score/analyst/options (2.3) | 2 | 100 | 2.5 | 90 | 1 | 225 |
| 11 | Visibilidade por papel (2.6) | 2 | 60 | 3 | 90 | 0.5 | 324 |
| 12 | Etapas terminais / dono único / lifecycle (2.7) | 2 | 90 | 2 | 85 | 0.8 | 191 |
| 13 | PackInstaller + YAML + tela de segmento (2.2) | 2 | 100 | 3 | 80 | 1 | 240 |
| 14 | Frontend genérico por `field_definitions` (2.4) | 2 | 100 | 2.5 | 80 | 1 | 200 |
| 15 | Renomes de schema + novas tabelas (2.1) | 2 | 100 | 3 | 75 | 1.5 | 150 |
| 16 | Deal por contato (2.5) | 2 | 80 | 3 | 75 | 1 | 180 |
| 17 | Desligar IA redundante (3.5) | 3 | 100 | 1.5 | 90 | 0.3 | 450 |
| 18 | Classificador LLM por pack (3.2) | 3 | 90 | 3 | 70 | 1 | 189 |
| 19 | Tools de CRM para a IA (3.1) | 3 | 80 | 3 | 70 | 1.5 | 112 |
| 20 | Tela única de IA (3.4) | 3 | 40 | 2 | 85 | 0.7 | 97 |
| 21 | Tokens únicos + i18n (4.1, 4.2) | 4 | 100 | 1.5 | 90 | 1.7 | 79 |
| 22 | WhatsApp oficial + aviso (5.2) | 5 | 100 | 3 | 70 | 1 | 210 |
| 23 | Sync upstream 4.17 (5.1) | 5 | 100 | 3 | 60 | 4 | 45 |
| 24 | MCP/API pública (5.4) | 5 | 30 | 2 | 70 | 0.5 | 84 |
| 25 | 1ª resposta / < 15 min (6.2) | 6 | 70 | 2 | 90 | 0.4 | 315 |

---

## 8. Métricas de sucesso

| Métrica | Hoje | 90 dias | 180 dias |
|---|---|---|---|
| Arquivos com termos de vertical no núcleo (`grep -rli "legal_area\|juridic\|INSS\|advogad"` em `app/ lib/ services/`) | 92 + 41 | ≤ 20 (só migrações/packs) | 0 fora de `config/crm_packs/` |
| Conta nova de outro segmento operante sem ver nada jurídico | impossível | sim (pack `sales_default`) | 3 packs disponíveis |
| % de respostas enviadas sem sair do board | ~0 | 40% | 70% |
| Tempo até 1ª resposta humana pós-handoff | não medido | < 15 min em 60% | 80% |
| Negócios abertos sem próxima ação | ? | < 20% | < 10% |
| Acurácia de categoria na triagem (por pack) | baixa fora do previdenciário | ≥ 80% | ≥ 90% |
| Negócios duplicados por contato/funil | permitido entre canais | 0 | 0 |
| Componentes CRM > 800 linhas | 6 | 3 | 0 |
| Famílias de tokens em `components/crm` | 3 | 1 | 1 |
| Distância do upstream | 5 minors | ≤ 1 | ≤ 1 |
| Testes | RSpec 345 / Vitest 242 verdes | + E2E "responder pelo board" + E2E por pack | + E2E tenancy por papel |

---

## 9. Riscos

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Renomear `legal_area` quebra o cliente real (10 GB, VPS KVM4) | alta | alto | flag `crm_universal` por conta; migrações aditivas primeiro (colunas novas + backfill), remoção só depois de 2 releases; restore drill antes |
| A1 demora e trava a Fase 3 | alta | alto | Fases 0–2 não dependem; prazo de 1 semana |
| Sync upstream colide com `captain_conversation_states`, Evolution e marketing | alta | alto | branch por release, canário Chuster, playbook existente |
| Pack YAML vira "segundo código" difícil de testar | média | médio | schema JSON do pack validado em CI; spec que instala cada pack em conta vazia |
| Trocar o drawer quebra `captain-attendance-redesign.spec.ts` | alta | baixo | reescrever junto (aceite 1.1) |
| Ban do número Baileys antes da migração | média | crítico | aviso + limite diário já na F0 (copy); Cloud API na F5 |
| Over-engineering de custom objects | média | médio | só `field_definitions`; custom objects fora do escopo até haver 3 packs em produção |

---

## Apêndice A — Bugs para abrir como issues

| ID | Título | Sev. | Arquivo:linha |
|---|---|---|---|
| A0 | Vertical jurídica soldada no núcleo | 🔴 | 92 + 41 arquivos (§5.3) |
| B1 | Chat do kanban sem realtime/anexos/nota privada | 🔴 | `CRMKanbanChatDrawer.vue:918,1406` |
| B2 | Triagem regex ignora acentos e áudio; inútil fora do jurídico | 🔴 | `legal_triage_analyzer.rb:2-9,86` |
| B3 | Funil mistura funis; KPI ≠ funil | 🔴 | `metrics_service.rb:8-45` |
| B4 | Contador = cards carregados | 🟠 | `CRMBoardToolbar.vue:138` |
| B5 | Categorias faltantes / slug cru | 🟠 | `domain_options.rb:8-22,56` |
| B6 | Categoria como slug no card | 🟡 | `CRMDealCard.vue:397` |
| B7 | aria-label do drag | ⚪ | `CRMDealCard.vue:160` |
| B8 | Sidebar polling 30 s | 🟡 | `Sidebar.vue:391` |
| B9 | Badge "Abertos" plural | ⚪ | `AllLeadsOperational.vue` |
| B10 | Stale ignora conversa e etapa; thresholds jurídicos | 🟠 | `stale_detector_job.rb:32-56` |
| B11 | 50% com 0/0 | 🟡 | `CrmMetrics.vue` |
| B12 | Anexos sem limite | 🟡 | `deals_controller.rb:628` |
| B13 | CapiDispatchJob em todo save | 🟡 | `crm_deal.rb:59` |
| B14 | bulk síncrono | 🟡 | `deals_controller.rb:187` |
| B15 | Atalhos concorrentes | ⚪ | `CrmIndexOperational.vue:750` |
| B16 | Analista responde "INSS" para qualquer conta | 🟠 | `analyst_service.rb:30,73`, `CrmMetrics.vue:83` |
| C1 | Agente vê todos os deals | 🟠 | `crm_deal_policy.rb` |
| C2–C8 | Payload expõe dados internos | 🟡 | `deals_controller.rb:530-626` |
| D6 | Cadência sem guard de consentimento | 🟠 | `cadence_message_sender_job.rb` |
| F13 | "CRM jurídico" e copy jurídica na UI | 🟠 | `ContactPanel.vue:44`, `ContactDetails.vue:32`, `DealDetailsOperational.vue:104` |
| H5 | Segredos sem rotação/gitleaks | 🟠 | CI |
| H7 | HttpTool sem SSRF filter | 🟠 | `enterprise/lib/captain/tools/http_tool.rb` |

## Apêndice B — O que esta auditoria muda nos planos anteriores

- Nenhum plano anterior trata **A0 (vertical no núcleo)** como problema estrutural; `PLANO-REFORMULACAO-CRM.md` §4.2 fala em "posicionamento" mas o modelo conceitual (§6) ainda usa `legal_area`.
- `01-BENCHMARK.md` marca "Card↔conversa" como ✅ diferencial → rebaixado para 🟡 (B1).
- `01-BENCHMARK.md` #20 "Agente multi-perfil no orchestrator" deixa de ser opcional: é a base dos packs de IA (3.5).
- `PLANO-REFORMULACAO-CRM.md` §12.3 (tenancy) cobre cross-account; não cobre visibilidade intra-conta por inbox (C1).
- `KANBAN-V2-BACKLOG.md` B-12 entregue; B-08 permanece.

## Apêndice C — Evidência de testes desta sessão

- RSpec `spec/services/crm spec/controllers/api/v1/accounts/crm spec/models/crm_deal_position_spec.rb spec/models/crm_conversation_tenancy_spec.rb` → **345 examples, 0 failures** (1 min 39 s; Postgres do compose em `127.0.0.1:5436`, `RAILS_ENV=test`).
- Vitest (Node 24) `components/crm`, `routes/dashboard/crm`, `helper/crm` → **28 arquivos, 242 testes, 0 falhas**. Aviso "Missing ref owner context" em `DealDetailsDiscard.spec.js` (Teleport em `CRMConfirmDialog`) — corrigir na F4.
- B2 verificado em Ruby puro: `"quero pensão alimentícia" =~ /\b(divorcio|guarda|pensao alimenticia|...)\b/i` → `nil`.
- Inventário A0: `grep -rli "legal_area\|legal_intake\|LegalTriage\|LegalLabel\|juridic\|previdenci\|INSS\|advogad" app lib` → 92; em `app/javascript/dashboard` (`*.vue,*.js`, sem specs) → 41.
- Screenshots: `qa/e2e/test-results/ui-audit/{crm-ptbr,ptbr-leads-v2,light-crm_metrics,dark-crm,light-captain_assistants}.png` (17/09/2026).

## Apêndice D — Fontes (acessadas em 17/09/2026)

- Kommo: [Salesdorado review](https://salesdorado.com/en/crm/crm-software/review-kommo-crm/) · [folk: Kommo for WhatsApp](https://www.folk.app/articles/kommo-crm-for-whatsapp-review-features-alternatives-and-more) · [Capterra](https://www.capterra.com/p/120048/amoCRM/)
- Pipedrive: [Pipedrive AI (KB)](https://support.pipedrive.com/en/article/pipedrive-ai) · [Newsroom](https://www.pipedrive.com/en/newsroom) · [AI pipeline forecasting](https://www.coffee.ai/articles/pipedrive-ai-pipeline-forecasting)
- HubSpot Breeze: [Spring 2026 Spotlight](https://www.hubspot.com/spotlight) · [Breeze agents 2026](https://www.onthefuze.com/hubspot-insights-blog/hubspot-breeze-ai-agents-2026) · [eesel: Customer Agent](https://www.eesel.ai/blog/breeze-customer-agent)
- Attio: [Best AI CRMs 2026](https://attio.com/f/best-ai-crm) · [Call Intelligence](https://attio.com/platform/call-intelligence) · [Stacksync review](https://www.stacksync.com/blog/attio-crm-2025-review-features-pros-cons-pricing)
- Twenty: [Marmelab benchmark 2026](https://marmelab.com/blog/2026/01/09/open-source-crm-benchmark-2026.html) · [twenty.com](https://twenty.com/)
- Intercom Fin: [Fin outcomes](https://www.intercom.com/help/en/articles/8205718-fin-ai-agent-outcomes) · [Fini: copilots after handoff](https://www.usefini.com/guides/ai-copilots-helping-support-agents-after-handoff)
- Clio Grow AI: [LawSites, ago/2026](https://www.lawnext.com/2026/08/clio-grows-clio-grow-with-launch-of-grow-ai-providing-24-7-intake-agents.html) · [Clio legal CRM](https://www.clio.com/features/legal-crm-software/)
- Chatwoot: [Changelog](https://www.chatwoot.com/changelog) · [Releases](https://github.com/chatwoot/chatwoot/releases) · [Captain](https://www.chatwoot.com/captain)
- Brasil: [Agendor 2026](https://www.agendor.com.br/blog/crm-para-whatsapp/) · [Ploomes 2026](https://blog.ploomes.com/melhor-crm-com-whatsapp-no-brasil/) · [RD Station](https://www.rdstation.com/demonstracao/crm/whatsapp-no-crm/) · [SocialHub](https://www.socialhub.pro/blog/melhores-crms-whatsapp-integrado/)
- Verticais BR: [SabioAdv comparativo 2026](https://sabioadv.com.br/crm-para-advogados-com-api-oficial-do-whatsapp-comparativo-completo-2026/) · [Chat Jurídico](https://chatjuridico.com.br/crm-para-advogados/) · [ADVBOX integrações](https://advbox.com.br/blog/integracoes-advbox/)
- WhatsApp API: [Meta service messages](https://developers.facebook.com/documentation/business-messaging/whatsapp/messages/send-messages) · [ActiveCampaign 24h window](https://help.activecampaign.com/hc/en-us/articles/20679458055964-Understanding-the-24-hour-conversation-window-in-WhatsApp-messaging)
