# CRM-033 — Auditoria de estados: vazio / erro / offline / permissão

**Data:** 2026-09-15 · **Escopo:** superfícies CRM (`/app/accounts/:id/crm/*`)

## Resultado por tela

| Tela | Vazio | Erro | Loading | Permissão |
| --- | --- | --- | --- | --- |
| Board (`crm/`) | `emptyTitle` + prop `empty` no board | `error` + retry implícito | skeleton colunas | rota aberta a admin/agent |
| Leads/listas | `DsEmptyState` | `error` | skeleton | idem |
| Deal details | `DsEmptyState`/`error` | `error.value` banner | skeleton | idem |
| Métricas | `DsEmptyState` | error catch | skeleton | admin-only via `meta.permissions` |
| AI Center | `DsEmptyState` (pausadas) | `error` com i18n | skeleton | admin-only |
| Regras de automação | `DsEmptyState` | `error` | skeleton | admin-only |
| Scoring/Cadências/Checklist/Reports | `DsEmptyState` | `error` | skeleton | admin-only |

## Gaps encontrados e tratamento

1. **Offline** — não é por-tela: o `NetworkNotification` global (escuta
   `navigator.onLine`) cobre toda a área autenticada. Suficiente para o
   escopo do card; não duplicar por página.
2. **Permissão** — gating via `meta.permissions: ['administrator']` nas
   rotas administrativas (`crm.routes.js`). Rotas operacionais aceitam
   `agent` por desenho.
3. **`crm/deals/:id` 404** — antes do fix do sweep, a aba de automações
   chamava endpoint inexistente na imagem antiga do container; com o
   backend sincronizado o 404 desapareceu. Estado de erro já exibia
   banner — contrato ok.

## Veredito

Estados cobertos em todas as telas CRM principais. Único débito real era
o bug de métricas (`null`) e o axios sem auth no AI Center — ambos
corrigidos no CRM-025 e verificados no sweep final (1 console 404
restante, param de fixture, não produto).
