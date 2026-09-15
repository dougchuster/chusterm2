# Relatório Final — Reformulação ChusteRM CRM

Data: 2026-09-15. Escopo: execução completa do Kanban v2 (31 cards, épicos E1–E5)
sobre o fork Chatwoot, sem reescrita do sistema.

## Resultado

- **31/31 cards concluídos** (`docs/execution/kanban.json`).
- Stack local saudável: `core` :8086, `orchestrator` :4001 (Node 24.21.0),
  `evolution` :8085, `mailhog` :8025 — todos HTTP 200.

## Evidência de testes por camada

| Camada | Comando | Resultado |
|---|---|---|
| Backend CRM | `bundle exec rspec spec/controllers/api/v1/accounts/crm spec/services/crm spec/jobs/crm ...` | 316/316 |
| Multi-tenant invariant | `crm/*_controller_spec.rb` (CRM-020) | 8/8 — cross-account 401/404 provado |
| LGPD (CRM-045) | `contacts_controller_spec.rb` | 65/65 — export + erasure auditado |
| Métricas (bug) | `metrics_controller_spec.rb` | 10/10 — payloads reais, sem `null` |
| Frontend CRM | `vitest run routes/dashboard/crm components/crm` | 238/238 |
| Composables E3 | density/panel-width/hotkeys | 13/13 |
| Orchestrator | `npm test` + `test:vitest` | 40/40 + 10/10 |
| Transcrição áudio | `spec/enterprise/...audio_transcription_*` | 10/10 |
| E2E jornada | `qa/e2e inbox-ai-crm-journey.spec.ts` | 9/9 |
| Varredura visual | `visual-sweep.spec.ts` | 10/10, 170 rotas, 0 overflow, 0 erros console |

## Bugs reais encontrados e corrigidos pelo QA

1. **`crm/audit-events` nunca filtrou** — `params[:action]` é o nome da action
   Rails; filtros passaram a ler `request.query_parameters` (CRM-005).
2. **Métricas retornavam `null`** — bloco de cache ligado ao `render`, não ao
   helper `cached` (CRM-025, `1c64a9f8a2`).
3. **`stale_deals` HTTP 500** — `.or` entre relações incompatíveis; reescrito
   com agregação por ids (CRM-025).
4. **Deep-link `?deal_id=` inerte** — `CrmIndexOperational` não consumia o
   parâmetro; filtros de query não aplicados no `loadCrm` inicial (CRM-022).
5. **AiCenter 401 no browser** — axios cru sem headers; novo client
   `api/captain/aiCenter.js` (CRM-025).
6. **Player de áudio quebrava** em URLs relativas/ref nulo (CRM-025).
7. **Orchestrator rodava Node 20** apesar do Dockerfile Node 24 — imagem
   rebuildada no QA do E4 (CRM-035).

## Entregas estruturais por épico

- **E1 Automação**: `DealOwnerAssigner` único (3 call sites), runs de automação
  persistidos (`crm_automation_runs` + UI por deal e por regra), auditoria sem
  falsos `executed`.
- **E2 Performance**: locales i18n lazy (JS inicial ~14,9 MB → ~4,5 MB), baseline
  autenticado documentado (`00-BASELINE-METRICAS.md`), débito de serialização
  de `crm/activities` registrado.
- **E3 Interface operacional**: densidade adaptativa, drawer redimensionável
  persistido, ⌘K unificado com contatos/deals, auditoria de estados
  (`CRM-033-STATES-AUDIT.md`), AiCenter no design system.
- **E4 Orchestrator**: Node 24, LLM multi-gateway, dedup de webhook em Redis
  (sobrevive restart/réplicas), registry `AgentProfile` multi-perfil.
- **E5 Governança**: serviços legados removidos, playbook de sync upstream
  (`04-UPSTREAM-SYNC-PLAYBOOK.md`), LGPD self-service
  (`data_export`/`data_erasure` com `lgpd_erasure` audit event), transcrição de
  áudio WhatsApp verificada ponta a ponta (pipeline Enterprise já existente).

## Limitações conhecidas

- LCP real depende de medição em dispositivo/rede — não coberto pelo harness.
- `crm/activities` ~520 ms: custo de serialização por registro, sem N+1;
  otimização fica como débito futuro.
- Transcrição exige `CAPTAIN_AUDIO_TRANSCRIPTION_MODEL` + chave OpenRouter;
  sem configuração o attachment fica `skipped` (comportamento intencional).
- Novos perfis de agente hoje resolvem via `custom_attributes.agent_profile`
  na conversa — provisionamento por inbox fica como próximo passo.
- 38 rotas puladas na varredura por falta de parâmetros de fixture — cobertura
  explícita em `MATRIZ-COBERTURA.md`.

## Rollback

Cada card foi commitado isoladamente (Conventional Commits com ID do card);
rollback = revert do commit correspondente. Serviços legados removidos em
`1472daafb8`; assets de frontend são repopulados no boot a partir de
`/app/public/vite-image`.
