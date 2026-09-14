# Fase 1 — Benchmark de Mercado — ChusteRM

**Data:** 2026-09-14 · **Método:** destilação dos benchmarks já analisados em `PLANO-KANBAN-CRM-2026.md` e `UI_UX_MASTER_PLAN_AND_ROADMAP.md` + confronto com o estado real do código.

> Conclusão central: **ninguém no conjunto tem omnichannel maduro + CRM profundo + IA governada junto** — esse é o espaço do ChusteRM. O gap não é de escopo; é de execução, confiança e acabamento.

## 1. O que cada categoria faz bem (e por que funciona)

### CRM / vendas

| Produto | Faz bem | Por que funciona |
|---|---|---|
| **Pipedrive** | Kanban como centro; deal rotting; soma de valor por coluna | vendedor vê "o que apodrece" sem relatório |
| **Attio** | Dados reativos, tabela-planilha com inline edit, sync contínuo | dados como objeto vivo, não formulário |
| **Folk** | Contatos leves, enriquecimento, listas flexíveis | baixa cerimônia para relacionamento |
| **Close** | Cockpit de execução (ligar/e-mail/SMS sem sair do lead) | reduz troca de contexto na hora de agir |
| **Twenty** (open) | ⌘K universal, saved views, objetos customizáveis | modelo de dados extensível sem código |
| **Frappe CRM** (open) | Página única do deal; List⇄Kanban⇄Group-by salvas | uma tela responde tudo do negócio |
| **HubSpot** | Ecossistema completo, relatórios ricos | cobre tudo — ao custo de peso |
| **Kommo** | Digital Pipeline: gatilhos entrar/sair etapa, Salesbot na etapa | automação onde o vendedor pensa: no funil |
| **DeskcommCRM** (MIT) | WHEN/IF/THEN, teto de gasto IA/org, RLS + invariantes em CI | IA com governança auditável |

### Atendimento / inbox

| Produto | Faz bem | Por que funciona |
|---|---|---|
| **Intercom** | Inbox + bot + help center no mesmo tecido | triagem automática visível ao agente |
| **Front** | Caixa compartilhada com cara de e-mail | zero treinamento para quem vive de inbox |
| **Missive** | Chat interno dentro da conversa | colaboração sem sair do contexto |
| **Respond.io** | Roteamento omnichannel + workflows | escala operação de chat em volume |
| **Linear** (adjacente) | <50ms, keyboard-first, triagem | velocidade como feature |

### Brasil (contexto do usuário final)

| Produto | Faz bem |
|---|---|
| **Kommo BR / Nexloo / Letalk / Senqo** | expectativa de mercado: **card = conversa**; abrir WhatsApp sem sair do board — ChusteRM já tem (`CRMKanbanChatDrawer`), é o maior diferencial e deve ser polido, não reconstruído |
| **Agendor/Ploomes/RD CRM** | funil simples, atividades com lembrete, relatórios de vendedor |
| **Take Blip/Zenvia** | bots de contato em escala no WhatsApp |

## 2. Matriz temos / não temos / temos pior

| Capacidade | Estado |
|---|---|
| Inbox omnichannel (WA/IG/Messenger/e-mail/webchat) | ✅ temos (upstream maduro + Evolution) |
| Kanban com drag&drop, multi-funil, motivos de perda, posição, realtime | ✅ temos (implementado F1-F2) |
| Card↔conversa (abrir WhatsApp no board) | ✅ temos — **diferencial** |
| Cadências/sequências, atividades, agenda + Google Calendar | ✅ temos |
| Scoring auditável + triagem IA + analista | ✅ temos |
| Auditoria, LGPD, multi-tenant, RBAC | ✅ temos |
| ⌘K / atalhos | 🟡 temos pior (ninja-keys + hotkeys parciais; não unificado) |
| Automação | 🟡 temos pior — motor WHEN/IF/THEN por etapa existe, mas sem runs visíveis (D-06) e auditoria mentirosa (B-03) |
| Construtor **visual** de workflows (nós) | ❌ não temos |
| Importação CSV com mapeamento+preview | 🟡 upstream tem importador de contatos; framework novo de import (v4.16+) chega no sync |
| Dashboards salvos por funil/agente | 🟡 métricas existem; relatórios salvos não |
| Segmentos dinâmicos de contatos | 🟡 filtros salvos de board existem (`board_views`); segmentos de contato parciais |
| Empresas ↔ contatos | 🟡 upstream tem `companies`; CRM não explora no deal |
| Transcrição de áudio | 🟡 upstream/Captain tem pipeline de áudio; verificar ativação |
| SLA com alerta | 🟡 upstream tem `applied_slas`; CRM não surfaca no card |
| Densidade compacta/confortável + painéis redimensionáveis | ❌ não temos (design prevê) |
| API pública documentada + webhooks com retry | 🟡 API herdada documentada; retry de webhook parcial |
| Update pela UI com rollback | ❌ não temos |

## 3. Top 25 oportunidades (RICE)

R=alcance (usuários/sessões), I=impacto (0.5-3), C=confiança %, E=esforço (pessoa-semana). Score = R·I·C/E.

| # | Oportunidade | R | I | C | E | RICE | Por que importa ao nosso usuário |
|---|---|---|---|---|---|---|---|
| 1 | Corrigir chunk 11 MB (DashboardIcon) | 100% | 2 | 90 | 0.5 | 360 | primeiro load rápido = operação diária |
| 2 | `crm_automation_runs` (status+erro por execução) | 80% | 3 | 90 | 2 | 108 | "por que a automação fez isso" respondido |
| 3 | Auditoria verdadeira de automação (B-03) | 80% | 2 | 95 | 0.5 | 304 | confiança no log = confiança no produto |
| 4 | `DealOwnerAssigner` único (B-01) | 60% | 2 | 90 | 1 | 108 | elimina divergência silenciosa de dono |
| 5 | Teste de invariante cross-account no CI (TENANCY-P0) | 100% | 3 | 80 | 1 | 240 | vazamento entre contas é fim de produto |
| 6 | ⌘K unificado (busca+ações+CRM) | 100% | 2 | 80 | 2 | 80 | velocidade percebida diária |
| 7 | E2E jornada Inbox→IA→CRM | 100% | 2 | 80 | 2 | 80 | protege o fluxo que vende o produto |
| 8 | SLA/deal rotting surfacado no card | 70% | 2 | 80 | 1 | 112 | "quem apodrece" sem relatório |
| 9 | Densidade compacta toggle | 90% | 1.5 | 80 | 1 | 108 | operador quer mais linhas na tela |
| 10 | Painéis laterais redimensionáveis persistidos | 80% | 1.5 | 80 | 1.5 | 64 | cockpit adaptável |
| 11 | Estados vazio/erro/offline auditados nas 161 rotas | 100% | 2 | 70 | 3 | 47 | acabamento = produto "refinado" |
| 12 | Resumo IA + sugestão de resposta visíveis no card | 70% | 2 | 70 | 2 | 49 | IA onde o trabalho acontece |
| 13 | Import CSV com mapeamento+preview (usar framework upstream v4.16) | 50% | 2 | 60 | 2 | 30 | onboarding de clientes com planilha |
| 14 | Segmentos dinâmicos de contato | 60% | 1.5 | 70 | 2 | 31 | listas vivas para campanhas |
| 15 | Empresa↔contato no deal 360º | 50% | 1.5 | 70 | 1.5 | 35 | B2B: ver conta, não pessoa solta |
| 16 | Transcrição de áudio WhatsApp | 80% | 2 | 60 | 2 | 48 | essencial no BR |
| 17 | Relatórios salvos por funil/agente | 50% | 1.5 | 80 | 2 | 30 | gestor revê o mesmo corte toda semana |
| 18 | Teto de gasto de IA por conta | 40% | 2 | 70 | 1 | 56 | governança = poder vender IA |
| 19 | Webhooks com retry/backoff padronizado | 40% | 2 | 80 | 1 | 64 | integrações não morrem em silêncio |
| 20 | Agente multi-perfil no orchestrator | 60% | 3 | 60 | 3 | 36 | desbloqueia vender IA a outros nichos |
| 21 | Deletar `crm-service`/`identity-bridge` mortos | 100% dev | 1 | 95 | 0.5 | 190 | clone menor, menos confusão |
| 22 | Split de componentes >1.000 linhas | 60% dev | 2 | 80 | 4 | 24 | velocidade de mudança futura |
| 23 | Playbook de sync upstream quinzenal | 100% | 2 | 80 | 1 | 160 | fork não apodrece |
| 24 | Export LGPD do titular (já há retenção; falta export/delete self-service) | 40% | 3 | 70 | 2 | 42 | conformidade vendável |
| 25 | Previsão de receita por funil | 50% | 1.5 | 60 | 2 | 22 | valor estimado × prob já existe no model |

## 4. Cinco padrões de UX que adotamos (comportamental, sem copiar telas)

1. **Comando-first (Linear/Twenty):** `⌘K` abre busca+ações; resultado executa sem sair do teclado; `J/K` navega listas, `E` arquiva/resolve, `R` responde.
2. **Card = conversa (mercado BR):** clicar no card abre o drawer da conversa à direita; negócio, próxima ação e score no mesmo painel; nunca leva a outra rota para responder.
3. **Rotting + soma por coluna (Pipedrive):** coluna mostra contagem + soma de valor; card fica visualmente "frio" após N dias na etapa — calibrado por `stage_entered_at` (já existe no schema).
4. **Inline edit otimista (Attio):** editar campo na lista/detalhe aplica na hora e reconcilia em background; falha reverte com toast e restaura foco.
5. **Automação legível (Kommo/Deskcomm):** toda regra é lida como frase — "QUANDO entrar em X, SE condição, ENTÃO ação" — e toda execução é listável com status e erro (requer `crm_automation_runs`).

## 5. Vereditos sobre a lista candidata do prompt

| Item | Veredito | Justificativa |
|---|---|---|
| Command palette ⌘K, atalhos, busca global | **Aprovar** | parcial hoje; unificar e estender ao CRM |
| Kanban DnD, multi-funis, motivos de perda, automação por etapa | **Já existe** | manter; endurecer execução (runs) |
| Previsão de receita | **Adiar** | dados já existem (valor×prob); depois das ondas 1-2 |
| Timeline unificada contato 360º | **Já existe** (parcial) | upstream dá mensagens+notas+atividades; estender com eventos CRM |
| Campos customizados, dedup/merge, tags | **Já existe** | upstream + crm |
| Empresas ↔ contatos | **Aprovar** | upstream tem companies; surfacar no CRM |
| Segmentos dinâmicos | **Aprovar** | estender `board_views`/filtros a contatos |
| Tarefas com lembrete, cadências, templates, respostas rápidas | **Já existe** | activities+cadences+canned+macros |
| Agendamento de envio, assinaturas | **Adiar** | upstream não tem nativo; esforço alto |
| Construtor visual de workflows (nós) | **Adiar** | motor existe; UI de nós é onda 3 |
| Roteamento, SLA com alerta, macros | **Já existe** (parcial) | SLA surfacar no card = onda 1 |
| Resumo IA, sugestão resposta, classificação, extração→campos | **Já existe** (parcial) | orchestrator+Captain; tornar visível no card |
| Transcrição de áudio | **Aprovar** | verificar pipeline upstream e ligar no WhatsApp BR |
| Rascunho de follow-up | **Aprovar** | skill `next-best-action` já sugere; renderizar como rascunho |
| Dashboards, relatórios salvos, export | **Aprovar** (parcial) | falta relatório salvo; export CSV ok |
| Import CSV mapeamento+preview | **Aprovar** | usar framework de import do upstream v4.16 |
| API documentada, webhooks retry, audit log, RBAC, multi-tenant | **Já existe** | endurecer retry de webhook e provar tenancy em CI |
