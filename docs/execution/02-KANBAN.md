# Fase 2 — Kanban Executável — ChusteRM

**Data:** 2026-09-14 · **Fonte de máquina:** `docs/execution/kanban.json` · **Regra:** nada de XL; P0 antes de feature; todo épico tem card "QA do épico".

Colunas: `Backlog → Priorizado → Em andamento → Em revisão → QA → Concluído`

## Épicos

- **E1 — Confiança & Automação:** o produto diz a verdade sobre o que executou
- **E2 — Performance:** primeiro load e interação rápidos
- **E3 — QA & Segurança:** invariantes provados em CI/execução
- **E4 — UX & Design System:** refinamento uniforme nas 161 rotas
- **E5 — Plataforma & Governança:** upstream sync, serviços mortos, LGPD, multi-perfil IA

## Board

| ID | Título | Tipo | P | Esf. | Épico | Coluna | Depende de | Risco upstream |
|---|---|---|---|---|---|---|---|---|
| CRM-001 | Unificar atribuição de dono em `Crm::DealOwnerAssigner` (B-01) | refactor | P1 | M | E1 | Concluído | — | 🟢 |
| CRM-002 | Auditoria verdadeira de automação: não logar `executed` em no-op (B-03) | bug | P1 | S | E1 | Concluído | — | 🟢 |
| CRM-003 | Criar `crm_automation_runs` (migration + model + escrita no StageAutomation) | feature | P1 | M | E1 | Concluído | — | 🟢 |
| CRM-004 | Listar runs de automação por deal/regra na UI | feature | P1 | M | E1 | Backlog | CRM-003 | 🟢 |
| CRM-005 | QA do épico E1: specs + passagem manual de automações | débito | P1 | S | E1 | Backlog | CRM-001..004 | 🟢 |
| CRM-010 | Investigar e quebrar chunk `DashboardIcon` de 11 MB | infra | P0 | S | E2 | Concluído | — | 🟡 |
| CRM-011 | Baseline autenticado: p95 dos 10 endpoints + queries/request | infra | P1 | S | E2 | Concluído | — | 🟢 |
| CRM-012 | Deal rotting + soma de valor no topo da coluna Kanban | feature | P1 | S | E2 | Backlog | — | 🟢 |
| CRM-013 | QA do épico E2: medir LCP das 5 telas e comparar bundle | débito | P1 | S | E2 | Backlog | CRM-010,011 | 🟢 |
| CRM-020 | Spec de invariante cross-account (ler/escrever deal de outra conta → 404/403) (TENANCY-P0) | infra | P0 | S | E3 | Concluído | — | 🟢 |
| CRM-021 | Verificar/remover `captain_triage` de `custom_fields` nos strong params | bug | P1 | XS | E3 | Concluído | — | 🟢 |
| CRM-022 | E2E jornada Inbox → IA → CRM (E2E-P0-00) | infra | P1 | M | E3 | Backlog | — | 🟡 |
| CRM-023 | Kanban 201+ deals: localizar 201º e reconciliar soma (CRM-201-01) | infra | P1 | S | E3 | Backlog | — | 🟢 |
| CRM-024 | Revalidar `time_in_stage`/`stale_deals` (mismatch + N+1 do audit) | bug | P2 | XS | E3 | Backlog | — | 🟢 |
| CRM-025 | Passagem visual das 161 rotas (VISUAL-F0, 5 viewports × light/dark) | design | P2 | L→2×M | E3 | Backlog | CRM-040 | 🟡 |
| CRM-026 | QA do épico E3: matriz atualizada + evidências sanitizadas | débito | P1 | S | E3 | Backlog | CRM-020..025 | 🟢 |
| CRM-030 | Expandir Obsidian+Mineral aos módulos CRM secundários (plano ativo) | design | P1 | M | E4 | Concluído | — | 🟡 |
| CRM-031 | Toggle de densidade compacta/confortável persistido | feature | P2 | M | E4 | Backlog | — | 🟡 |
| CRM-032 | Painéis laterais redimensionáveis com largura persistida | feature | P2 | M | E4 | Backlog | — | 🟡 |
| CRM-033 | Estados vazio/erro/offline/permissão auditados em todas as telas CRM | design | P2 | M | E4 | Backlog | — | 🟢 |
| CRM-034 | ⌘K unificado: busca global (contatos+conversas+deals) + ações | feature | P2 | M | E4 | Backlog | — | 🟡 |
| CRM-035 | QA do épico E4: axe zero critical nas telas tocadas + antes/depois | débito | P2 | S | E4 | Backlog | CRM-030..034 | 🟢 |
| CRM-040 | Deletar `services/crm-service` e `services/identity-bridge` + docs | infra | P2 | XS | E5 | Priorizado | dúvida #3 | 🟢 |
| CRM-041 | Alinhar Node local ao alvo 24 | infra | P3 | XS | E5 | Backlog | — | 🟢 |
| CRM-042 | Remover lock OpenRouter-only do `llm/client.ts` | refactor | P3 | XS | E5 | Backlog | — | 🟢 |
| CRM-043 | Agente multi-perfil no orchestrator (sair do hardcode dr-paula-matos) | feature | P2 | L→3×M | E5 | Backlog | dúvida #5 | 🟢 |
| CRM-044 | Playbook de sync upstream quinzenal + checklist de regressão | infra | P2 | S | E5 | Backlog | — | 🟡 |
| CRM-045 | Export/exclusão LGPD do titular self-service | feature | P2 | M | E5 | Backlog | — | 🟢 |
| CRM-046 | Transcrição de áudio WhatsApp: verificar pipeline upstream e ativar | feature | P2 | S | E5 | Backlog | — | 🟡 |
| CRM-047 | Estado do orchestrator fora de memória (Redis) p/ multi-réplica | refactor | P2 | M | E5 | Backlog | dúvida #2 | 🟢 |
| CRM-048 | QA do épico E5: revisão de governança + restore drill | débito | P2 | S | E5 | Backlog | CRM-040..047 | 🟢 |

**Legenda esforço:** XS<2h · S=meio dia · M=1-2d · L→quebrado em filhos.

## Formato de card (obrigatório ao puxar para "Em andamento")

Cada card aberto vira: **Problema** (1 frase) · **Critérios de aceite** (Dado/Quando/Então) · **Arquivos afetados** · **Como testar** (manual + automatizado) · **Plano de rollback**.

---

# Roadmap — 4 ondas

## Onda 1 — Confiança (valor: o produto passa a dizer a verdade)
CRM-020, CRM-021, CRM-001, CRM-002, CRM-003, CRM-010, CRM-011, CRM-023, CRM-040*
*CRM-040 condicionado à dúvida #3.
**Entrega sozinha:** tenancy provada, automação auditável, bundle de entrada saneado.

## Onda 2 — Velocidade & Acabamento
CRM-012, CRM-030, CRM-031, CRM-032, CRM-033, CRM-034, CRM-004, CRM-005, CRM-013, CRM-035
**Entrega sozinha:** operador sente o produto "refinado e detalhado" — a reclamação original do dono.

## Onda 3 — Prova & Escala
CRM-022, CRM-024, CRM-025 (quebrada em 2×M), CRM-016→026, CRM-044, CRM-047, CRM-048
**Entrega sozinha:** matriz QA verde, sync upstream virou rotina, orchestrator pronto p/ réplica.

## Onda 4 — Expansão (backlog de produto)
CRM-043 (multi-perfil IA), CRM-045, CRM-046, construtor visual de workflows, previsão de receita, empresas↔contatos 360º, segmentos dinâmicos, relatórios salvos, teto de gasto IA/conta, agendamento de envio/assinaturas.

**Fora de escopo:** rewrite, `enterprise/`, modelo de licenciamento por seat, mobile nativo.
