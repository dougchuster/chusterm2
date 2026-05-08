# Plano de Melhorias — CRM + Captain AI + Chat

**Data:** 2026-05-01
**Status:** Planejamento
**Autor:** ChusteRM Engineering

---

## Sumario Executivo

O CRM do ChusteRM ja possui uma base solida (11 tabelas, 40+ endpoints, scoring configuravel, automation builder, checklists, cadencias). Porem, existem **lacunas criticas** na experiencia do usuario e na integracao entre os 3 pilares do sistema: **Atendimento (Chat)**, **Captain (IA)** e **CRM (Pipeline)**.

Este documento mapeia todos os problemas encontrados e propoe um plano de melhorias organizado por prioridade.

---

## 1. DIAGNOSTICO — Problemas Identificados

### 1.1 Pipeline — Falta opcao de DELETAR (critico)

**Problema:** Na pagina `/app/accounts/:id/crm` (CrmIndex.vue) e na pagina de configuracao (`PipelineSettings.vue`), **nao existe opcao de deletar pipelines ou etapas**. O usuario so consegue "Arquivar" (`archivePipeline` / `archiveStage`), o que faz soft-delete (`archived_at`). Porem:

- **Pipelines criados incorretamente** ficam para sempre no sistema
- **Etapas iniciais de exemplo** (como "Novo lead", "Em qualificacao") nao podem ser removidas
- O `confirm()` nativo do browser e usado para arquivar, mas nao para deletar
- Nao ha painel de "arquivados" para restaurar itens arquivados

**Arquivos envolvidos:**
- `core/app/javascript/dashboard/routes/dashboard/crm/pages/PipelineSettings.vue` (linhas 139-151, 288-300)
- `core/app/javascript/dashboard/api/crm.js` (metodo `archivePipeline`, `archivePipelineStage`)
- `core/app/controllers/api/v1/accounts/crm/pipelines_controller.rb`
- `core/app/controllers/api/v1/accounts/crm/pipeline_stages_controller.rb`

### 1.2 Pipeline — Nao ha visao de "Arquivados" (alto)

**Problema:** Itens arquivados desaparecem completamente. O usuario nao consegue:
- Ver pipelines/etapas arquivadas
- Restaurar itens arquivados
- Deletar permanentemente itens ja arquivados

### 1.3 CRM ↔ Conversas — Link fraco (alto)

**Problema:** A conexao entre conversas do chat e deals do CRM e feita apenas via `CrmDeal.conversation_id` (opcional) e `CaptainConversationState.crm_deal_id` (FK virtual). Porem:

- **Na UI de conversa**, o sidebar do CRM (`CRMSidebarCard.vue`) nao mostra o deal vinculado de forma clara
- **Na UI do CRM**, ao clicar em um deal, nao ha link direto para a conversa original
- **Captain nao cria deals automaticamente** quando `ai_mode != 'auto'` — apenas em modo auto-reply
- **Triage manual** exige chamar API separada — nao ha botao na UI da conversa

### 1.4 Captain ↔ CRM — Integracao incompleta (alto)

**Problema:** O Captain (IA) e o CRM operam em silos:

- `CaptainConversationState` tem `crm_deal_id` mas o model **nao declara `belongs_to :crm_deal`**
- Quando Captain faz handoff, o deal associado **nao recebe notificacao** nem atualizacao de status
- Captain nao tem acesso ao historico de deals do contato para personalizar respostas
- Fluxos de Captain (`captain_flows`) nao tem integracao com estagios do pipeline
- Nao ha "Captain Pipeline Aware" — a IA nao sabe em qual estagio o deal esta

### 1.5 UI/UX — Paginas CRM desconectadas (medio)

**Problema:**
- A rota `/crm` nao tem sub-rotas para Deals, Atividades, etc. — tudo e carregado via API no CrmIndex
- Nao ha pagina dedicada para ver um deal individual com historico completo
- O `CRMDealDrawer` e um drawer lateral limitado — nao substitui uma pagina de detalhes
- Filtros do Kanban (area juridica, urgencia) nao persistem entre navegacoes
- Nao ha busca global de deals

### 1.6 Pipeline Settings — Sem protecao (medio)

**Problema:**
- Criar pipeline com slug duplicado causa erro 500 sem mensagem amigavel
- Nao ha validacao de nome vazio antes de enviar ao backend
- Scoring config exige soma exata de 100, mas o erro nao e claro
- Nao ha historico de mudancas no scoring

---

## 2. PLANO DE MELHORIAS

### FASE 1 — Correcoes Criticas (Sprint 1)

#### 2.1.1 Adicionar DELETE de Pipelines e Etapas

**Escopo:** Permitir exclusao permanente de pipelines e etapas com protecao.

**Backend:**
- [ ] Adicionar action `destroy` em `Crm::PipelinesController`
  - Verificar se pipeline tem deals associados antes de deletar
  - Se tiver deals, forcar usuario a move-los ou deleta-los primeiro
  - Deletar cascata: stages -> automation_rules -> scoring_config
- [ ] Adicionar action `destroy` em `Crm::PipelineStagesController`
  - Verificar se stage tem deals associados
  - Se tiver deals, impedir delecao e informar quantidade
  - Deletar cascata: automation_rules

**Frontend:**
- [ ] Adicionar botao "Deletar" em `PipelineSettings.vue` ao lado de "Arquivar"
  - Modal de confirmacao com nome do pipeline digitado para confirmar
  - Se tiver deals, mostrar aviso com quantidade e impedir
- [ ] Adicionar botao "Deletar etapa" com mesma logica
- [ ] Adicionar metodo `deletePipeline` e `deletePipelineStage` em `crm.js`

**Estimativa:** 2-3 dias

#### 2.1.2 Adicionar visao de Itens Arquivados

**Escopo:** Painel para visualizar e restaurar pipelines/etapas arquivados.

**Backend:**
- [ ] Adicionar scope `archived` nos controllers de pipelines e stages
- [ ] Adicionar action `unarchive` (restore) nos controllers
- [ ] Endpoint `GET /crm/pipelines?status=archived`

**Frontend:**
- [ ] Tab "Arquivados" em `PipelineSettings.vue`
- [ ] Botao "Restaurar" em cada item arquivado
- [ ] Botao "Deletar permanentemente" com confirmacao

**Estimativa:** 1-2 dias

---

### FASE 2 — Integracao CRM ↔ Chat (Sprint 2)

#### 2.2.1 Sidebar CRM na Conversa

**Escopo:** Mostrar deal vinculado no sidebar da conversa com acoes rapidas.

**Frontend:**
- [ ] Melhorar `CRMSidebarCard.vue` para mostrar:
  - Deal atual (nome, estagio, score, valor)
  - Link para abrir deal no CRM
  - Botao "Criar deal" se nao houver deal vinculado
  - Botao "Triar conversa" (chama Captain triage manual)
  - Indicador visual de score (cor por classificacao)
- [ ] Adicionar secao "CRM" no sidebar da conversa com:
  - Pipeline + estagio atual
  - Atividades pendentes do deal
  - Ultimo contato registrado

**Backend:**
- [ ] Endpoint `GET /crm/deals?conversation_id=:id` para buscar deal da conversa
- [ ] Incluir `captain_conversation_state` no serializer da conversa

**Estimativa:** 3-4 dias

#### 2.2.2 Link Bidirecional Deal ↔ Conversa

**Escopo:** Facilitar navegacao entre deal e conversa em ambas as direcoes.

**Frontend:**
- [ ] Em `CRMDealDrawer.vue`, adicionar secao "Conversa" com:
  - Link direto para a conversa (abre no chat)
  - Preview das ultimas 3 mensagens
  - Status da conversa (open/pending/resolved)
- [ ] Em `CRMDealCard.vue`, adicionar icone de conversa quando deal tem `conversation_id`

**Backend:**
- [ ] Incluir `conversation` no serializer do deal (com eager loading)
- [ ] Endpoint para buscar mensagens recentes da conversa do deal

**Estimativa:** 2-3 dias

#### 2.2.3 Triage Manual via UI

**Escopo:** Botao na conversa para executar triagem do Captain no CRM.

**Frontend:**
- [ ] Botao "Triar no CRM" no header da conversa ou no sidebar
- [ ] Feedback visual: loading, sucesso, erro
- [ ] Apos triagem: atualizar sidebar com deal criado/atualizado

**Backend:**
- [ ] Ja existe `POST /crm/triage/from_conversation` — apenas conectar ao frontend
- [ ] Garantir que triagem manual funcione mesmo com `ai_mode != 'auto'`

**Estimativa:** 1-2 dias

---

### FASE 3 — Captain Pipeline-Aware (Sprint 3)

#### 2.3.1 Captain com Contexto de Deal

**Escopo:** Captain (IA) tem acesso ao deal do contato para personalizar respostas.

**Backend:**
- [ ] Declarar `belongs_to :crm_deal, optional: true` em `CaptainConversationState`
- [ ] Em `ResponseBuilderJob#collect_previous_messages`, incluir contexto do deal:
  ```
  [SYSTEM] O contato tem um deal no pipeline: {deal.title}
  Estagio atual: {stage.name} | Score: {score_total} | Classificacao: {classification}
  Area juridica: {legal_area} | Urgencia: {urgency_level}
  ```
- [ ] Em `TriageFromConversation`, sincronizar `CaptainConversationState.crm_deal_id` apos criar/encontrar deal

**Frontend:**
- [ ] Na configuracao do Captain (inbox), mostrar se ha deal associado a conversa atual

**Estimativa:** 3-4 dias

#### 2.3.2 Handoff Inteligente

**Escopo:** Quando Captain faz handoff, atualizar deal automaticamente.

**Backend:**
- [ ] Em `ResponseBuilderJob#process_action('handoff')`:
  - Atualizar `captain_conversation_state` com `handoff_reason`
  - Se deal existir: criar atividade automatica "Handoff IA → Humano" no deal
  - Se deal existir: mover para estagio de "Atendimento Humano" (se configurado)
- [ ] Em `CaptainConversationState#apply_ai_mode!`:
  - Logar no `CrmAuditEvent` quando handoff ocorrer
  - Atualizar `deal.custom_fields['last_handoff_reason']`

**Estimativa:** 2-3 dias

#### 2.3.3 Fluxos de Captain vinculados a Estagios

**Escopo:** Quando deal muda de estagio, disparar acao no Captain (e vice-versa).

**Backend:**
- [ ] Em `Crm::DealMover`, apos mover deal:
  - Se deal tem `conversation_id` e `captain_conversation_state`:
    - Atualizar `ai_mode` baseado na configuracao do estagio
    - Se stage tiver automacao `captain_action`, executar
- [ ] Adicionar `captain_ai_mode` como campo opcional em `CrmAutomationRule.action_config`
  - Opcoes: `auto`, `supervised`, `paused`, `human_only`
- [ ] Em `Crm::StageAutomation`, suportar novo action_type `set_captain_mode`

**Estimativa:** 3-4 dias

---

### FASE 4 — UX/UI do Pipeline (Sprint 4)

#### 2.4.1 Pagina de Detalhes do Deal

**Escopo:** Substituir o drawer por uma pagina dedicada com historico completo.

**Frontend:**
- [ ] Criar rota `/crm/deals/:dealId`
- [ ] Pagina com:
  - Header: titulo, estagio (editavel), score, valor, status
  - Abas: Atividades | Intake | Historico | Conversa | Documentos
  - Timeline de todas as mudancas (audit events)
  - Formulario de edicao inline
  - Acoes: mover estagio, marcar ganho/perdido, reabrir

**Backend:**
- [ ] Endpoint `GET /crm/deals/:id` com includes completos
- [ ] Endpoint `GET /crm/audit_events?target_type=CrmDeal&target_id=:id`

**Estimativa:** 4-5 dias

#### 2.4.2 Melhorias no Kanban Board

**Escopo:** Tornar o board do pipeline mais usavel.

**Frontend:**
- [ ] Persistir filtros na URL (query params) para compartilhamento
- [ ] Adicionar filtro por "responsavel" (owner)
- [ ] Adicionar filtro por "score" (faixa)
- [ ] Adicionar ordenacao por score, data de criacao, urgencia
- [ ] WIP limit por coluna (maximo de deals por estagio)
- [ ] Indicador de deals stale (sem atividade ha X dias) com badge vermelha
- [ ] Drag & drop com feedback visual melhorado (sombras, animacao)

**Estimativa:** 3-4 dias

#### 2.4.3 Dashboard CRM Completo

**Escopo:** Melhorar a pagina de reports com metricas uteis.

**Frontend:**
- [ ] Melhorar `Reports.vue` com:
  - Grafico de funil (deals por estagio) — `CRMFunnelChart.vue` ja existe
  - Taxa de conversao entre estagios
  - Tempo medio por estagio
  - Deals ganhos vs perdidos (por periodo)
  - Score medio por pipeline
  - Receita real vs forecast ponderado
  - Top motivos de perda
  - Performance por responsavel

**Backend:**
- [ ] Endpoint `GET /crm/dashboard/metrics` com agregacoes
- [ ] Cache com Redis (TTL 5 min)

**Estimativa:** 3-4 dias

---

### FASE 5 — Cadencias e Automacao Avancada (Sprint 5)

#### 2.5.1 Executor de Cadencias

**Escopo:** O modelo de dados de cadencias ja existe, mas falta o executor.

**Backend:**
- [ ] Criar `Crm::CadenceExecutorJob` (Sidekiq, periodic)
  - Buscar deals elegiveis (`audience_filter`)
  - Para cada deal, executar o step atual da cadencia
  - Steps `send_message`: enviar template via WhatsApp/Email
  - Steps `create_activity`: criar atividade no deal
  - Steps `wait`: aguardar N horas antes do proximo step
- [ ] Criar `Crm::CadenceEnrollerJob` (Sidekiq, periodic)
  - Auto-inscrever deals novos em cadencias ativas
- [ ] Log de execucao em `CrmAuditEvent`

**Estimativa:** 5-7 dias

#### 2.5.2 Automacao Avancada

**Escopo:** Expandir as automation rules alem de `create_activity`.

**Backend:**
- [ ] Novos `action_type` em `CrmAutomationRule`:
  - `send_whatsapp_message`: enviar template WhatsApp ao contato
  - `assign_owner`: atribuir responsavel ao deal
  - `move_to_stage`: mover deal para outro estagio
  - `set_captain_mode`: alterar modo do Captain
  - `create_deal`: criar deal em outro pipeline (cross-pipeline)
  - `webhook`: chamar URL externa
- [ ] Novos `trigger_event`:
  - `deal_created`: quando deal e criado
  - `score_changed`: quando score muda de faixa
  - `stale_detected`: quando deal fica sem atividade
  - `handoff`: quando Captain faz handoff
  - `message_received`: quando nova mensagem chega na conversa

**Estimativa:** 5-7 dias

---

## 3. ARQUITETURA — Diagrama de Integracao

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CHUSTERM PLATFORM                            │
│                                                                     │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────┐    │
│  │    CHAT       │     │   CAPTAIN    │     │      CRM         │    │
│  │  (Atendimento)│     │   (IA Bot)   │     │   (Pipeline)     │    │
│  │              │     │              │     │                  │    │
│  │ Conversations │     │ Assistants   │     │ Pipelines        │    │
│  │ Messages      │     │ Flows        │     │ Stages           │    │
│  │ Contacts      │     │ Responses    │     │ Deals            │    │
│  │ Inboxes       │     │ Handoffs     │     │ Activities       │    │
│  └──────┬───────┘     └──────┬───────┘     │ Scores           │    │
│         │                    │              │ Cadences         │    │
│         │                    │              │ Automation Rules │    │
│         │                    │              └────────┬─────────┘    │
│         │                    │                       │              │
│         └────────────────────┼───────────────────────┘              │
│                              │                                      │
│                    ┌─────────┴──────────┐                           │
│                    │  BRIDGE TABLES     │                           │
│                    │                    │                           │
│                    │ CaptainConvState   │                           │
│                    │   - conversation_id│                           │
│                    │   - crm_deal_id ◄──┼── FASE 3                 │
│                    │   - ai_mode        │                           │
│                    │   - score_total    │                           │
│                    │                    │                           │
│                    │ CrmDeal            │                           │
│                    │   - conversation_id│◄── FASE 2                │
│                    │   - contact_id     │                           │
│                    └────────────────────┘                           │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    SERVICOS                                │    │
│  │                                                            │    │
│  │  TriageFromConversation ──── Cria deal a partir de chat    │    │
│  │  LeadScoreCalculator ────── Calcula score do deal          │    │
│  │  DealMover ─────────────── Move deal + trigger automacoes  │    │
│  │  StageAutomation ───────── Executa rules ao entrar stage   │    │
│  │  CadenceExecutor ───────── Executa steps de cadencia ◄─F5  │    │
│  │  ResponseBuilderJob ────── Captain gera resposta + deal ◄─F3│    │
│  │  StaleDetectorJob ──────── Detecta deals inativos          │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. FLUXOS DE INTEGRACAO PROPOSTOS

### 4.1 Fluxo: Conversa → Deal Automatico (Captain Auto)

```
1. Contato envia WhatsApp → Conversation criada
2. Captain inbox em modo "auto" → ResponseBuilderJob executado
3. CaptainTriageJob disparado → TriageFromConversation
4. Deal criado no pipeline (estagio "Novo lead")
5. LeadScoreCalculator → score calculado
6. Deal movido automaticamente (score >= 60 → "Em qualificacao")
7. StageAutomation → atividade "Retorno cliente" criada
8. Captain responde ao contato com contexto do deal
```

### 4.2 Fluxo: Handoff → Atendimento Humano

```
1. Captain detecta que precisa de humano (erro/intencao/score alto)
2. mark_ai_handoff! → CaptainConversationState atualizado
3. FASE 3: Deal recebe atividade "Handoff IA → Humano"
4. FASE 3: Deal pode mover para estagio "Atendimento Humano"
5. Agente humano ve a conversa no painel "Atribuidas a mim"
6. Sidebar mostra deal + score + historico de triagem
```

### 4.3 Fluxo: Cadencia de Follow-up

```
1. Deal criado no estagio "Novo lead" (FASE 5)
2. CadenceEnrollerJob → inscreve deal em cadencia "Follow-up WhatsApp"
3. Step 1 (imediato): enviar mensagem "Ola, recebemos seu contato..."
4. Step 2 (24h): criar atividade "Ligar para o contato"
5. Step 3 (48h): enviar mensagem "Conseguiu analisar a proposta?"
6. Step 4 (72h): se deal nao moveu → criar atividade "Urgencia: reengajamento"
7. Se deal moveu de estagio → cancelar cadencia restante
```

### 4.4 Fluxo: Deal Stale → Acao Automatica

```
1. StaleDetectorJob roda diariamente
2. Deal no estagio "Proposta" ha 5 dias sem atividade
3. Cria atividade "Retomada: deal parado ha 5 dias"
4. FASE 5: Dispara automation rule "send_whatsapp_message"
5. Mensagem enviada: "Oi! Passando para saber se teve chance de avaliar..."
6. Cria CrmAuditEvent: stale_detected
```

---

## 5. PRIORIZACAO

| Fase | Descricao | Prioridade | Estimativa | Impacto |
|------|-----------|------------|------------|---------|
| **1** | Delete de pipelines/etapas + visao arquivados | **Critica** | 3-5 dias | Resolve problema imediato do usuario |
| **2** | CRM ↔ Chat: sidebar, links, triage manual | **Alta** | 6-9 dias | Conecta os 2 sistemas visivelmente |
| **3** | Captain pipeline-aware + handoff inteligente | **Alta** | 8-11 dias | IA com contexto completo |
| **4** | UX do pipeline: detalhes do deal, kanban, dashboard | **Media** | 10-13 dias | Experiencia profissional |
| **5** | Cadencias + automacao avancada | **Media** | 10-14 dias | Operacao comercial automatizada |

**Total estimado:** 37-52 dias de desenvolvimento

---

## 6. TABELAS DO BANCO ENVOLVIDAS

| Tabela | Fases | Mudancas Necessarias |
|--------|-------|---------------------|
| `crm_pipelines` | 1 | Nenhuma (ja tem `archived_at`) |
| `crm_pipeline_stages` | 1 | Nenhuma (ja tem `archived_at`) |
| `crm_deals` | 2,3 | Nenhuma (ja tem `conversation_id`, `contact_id`) |
| `captain_conversation_states` | 3 | Adicionar `belongs_to :crm_deal` no model |
| `crm_automation_rules` | 3,5 | Expandir `trigger_event` e `action_type` enums |
| `crm_cadences` | 5 | Nenhuma (modelo ja existe) |
| `crm_cadence_steps` | 5 | Nenhuma (modelo ja existe) |
| `crm_activities` | 2,3,5 | Nenhuma |
| `crm_audit_events` | 3,5 | Nenhuma (ja suporta todos os tipos) |

---

## 7. ENDPOINTS A CRIAR/MODIFICAR

### Novos Endpoints
| Metodo | Rota | Descricao | Fase |
|--------|------|-----------|------|
| DELETE | `/crm/pipelines/:id` | Deletar pipeline permanentemente | 1 |
| DELETE | `/crm/pipelines/:id/stages/:id` | Deletar etapa permanentemente | 1 |
| PATCH | `/crm/pipelines/:id/unarchive` | Restaurar pipeline arquivado | 1 |
| PATCH | `/crm/pipelines/:id/stages/:id/unarchive` | Restaurar etapa arquivada | 1 |
| GET | `/crm/pipelines?status=archived` | Listar pipelines arquivados | 1 |
| GET | `/crm/deals?conversation_id=:id` | Buscar deal da conversa | 2 |
| GET | `/crm/deals/:id/messages` | Mensagens recentes da conversa do deal | 2 |
| GET | `/crm/dashboard/metrics` | Metricas agregadas do CRM | 4 |

### Endpoints Existentes (sem mudanca)
| Metodo | Rota | Descricao |
|--------|------|-----------|
| POST | `/crm/triage/from_conversation` | Triage manual (ja existe) |
| POST | `/crm/deals/:id/move` | Mover deal (ja existe) |
| GET | `/crm/deals/:id/lead_score` | Ver score (ja existe) |
| POST | `/crm/deals/:id/recompute_score` | Recalcular score (ja existe) |

---

## 8. CHECKLIST DE VALIDACAO

### Fase 1 — Concluida quando:
- [ ] Usuario pode deletar pipeline (com confirmacao de seguranca)
- [ ] Usuario pode deletar etapa (apenas se sem deals)
- [ ] Usuario pode ver pipelines/etapas arquivados
- [ ] Usuario pode restaurar itens arquivados
- [ ] Delecao de pipeline com deals mostra erro claro

### Fase 2 — Concluida quando:
- [ ] Sidebar da conversa mostra deal vinculado (ou botao para criar)
- [ ] Deal no CRM tem link clicavel para a conversa
- [ ] Botao "Triar no CRM" funciona na conversa
- [ ] Triage manual cria deal mesmo com Captain em modo supervised

### Fase 3 — Concluida quando:
- [ ] Captain recebe contexto do deal nas respostas
- [ ] Handoff cria atividade automatica no deal
- [ ] Mudanca de estagio pode alterar ai_mode do Captain
- [ ] CaptainConversationState declarado com `belongs_to :crm_deal`

### Fase 4 — Concluida quando:
- [ ] Pagina de detalhes do deal funcional com historico
- [ ] Kanban com filtros persistentes na URL
- [ ] Dashboard com metricas de funil e conversao

### Fase 5 — Concluida quando:
- [ ] Cadencias executam steps automaticamente
- [ ] Deals sao auto-inscritos em cadencias
- [ ] Automation rules suportam novos action_types
- [ ] Novos trigger_events funcionais

---

## 9. RISCOS E MITIGACOES

| Risco | Impacto | Mitigacao |
|-------|---------|-----------|
| Delecao de pipeline com deals ativos | Alto | Bloquear delecao, mostrar quantidade de deals |
| Captain com deal context gera respostas incorretas | Medio | Incluir contexto como SYSTEM message separada, nao no historico |
| Cadencia executor sobrecarrega WhatsApp | Alto | Rate limit por inbox, fila unica por contato |
| Migration de dados existentes | Baixo | Nenhuma migration necessaria — tabelas ja existem |
| Regressao em specs existentes | Medio | Rodar suite completa apos cada fase |

---

## 10. REFERENCIAS

### Arquivos-Chave do CRM
- **API Client:** `core/app/javascript/dashboard/api/crm.js`
- **Kanban Board:** `core/app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndex.vue`
- **Pipeline Settings:** `core/app/javascript/routes/dashboard/crm/pages/PipelineSettings.vue`
- **Deal Drawer:** `core/app/javascript/dashboard/components/crm/CRMDealDrawer.vue`
- **Deal Card:** `core/app/javascript/dashboard/components/crm/CRMDealCard.vue`
- **Sidebar Card:** `core/app/javascript/dashboard/components/crm/CRMSidebarCard.vue`

### Arquivos-Chave do Captain
- **Response Builder:** `core/enterprise/app/jobs/captain/conversation/response_builder_job.rb`
- **Conversation State:** `core/app/models/captain_conversation_state.rb`
- **Captain Inbox:** `core/enterprise/app/models/captain_inbox.rb`
- **Triage Service:** `core/app/services/crm/triage_from_conversation.rb`
- **Flow Router:** `core/enterprise/app/services/captain/flow_router.rb`

### Arquivos-Chave dos Controllers
- **Pipelines:** `core/app/controllers/api/v1/accounts/crm/pipelines_controller.rb`
- **Stages:** `core/app/controllers/api/v1/accounts/crm/pipeline_stages_controller.rb`
- **Deals:** `core/app/controllers/api/v1/accounts/crm/deals_controller.rb`
- **Triage:** `core/app/controllers/api/v1/accounts/crm/triage_controller.rb`

### Migrations
- `000001_create_crm_pipelines.rb`
- `000002_create_crm_pipeline_stages.rb`
- `000003_create_crm_deals.rb`
- `000004_create_crm_activities.rb`
- `000006_create_crm_lead_scores.rb`
- `000003_create_crm_automation_rules.rb` (30/04)
- `000004_create_crm_cadences.rb` (30/04)
- `000005_create_crm_cadence_steps.rb` (30/04)
- `000006_create_captain_conversation_states.rb` (30/04)
