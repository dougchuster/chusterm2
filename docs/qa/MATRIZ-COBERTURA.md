# Matriz de cobertura de QA

**Baseline:** F0 local — 2026-07-13  
**Ambiente:** Docker Compose, `http://localhost:8086`, namespace `f0`

| Requisito          | Rota/superfície         | Persona             | Browser/viewport            | Cenário                                                               | Resultado                 |
| ------------------ | ----------------------- | ------------------- | --------------------------- | --------------------------------------------------------------------- | ------------------------- |
| CORE-HEALTH-01     | `/health`               | anônimo             | Chromium/API                | health público retorna `{status: woot}`                               | aprovado                  |
| AUTH-PERSONAS-01   | `/app/login`            | 8 personas          | Chromium 1366×768           | login e storage state individual                                      | 8/8 aprovado              |
| APP-SMOKE-01       | `/app`                  | admin A             | Chromium 1366×768           | abre autenticado sem resposta 5xx                                     | aprovado                  |
| CRM-A11Y-01        | `/app/accounts/:id/crm` | admin A             | Chromium 360×800            | Axe critical/serious                                                  | zero                      |
| CRM-A11Y-02        | `/app/accounts/:id/crm` | admin A             | Chromium 768×1024           | Axe critical/serious                                                  | zero                      |
| CRM-A11Y-03        | `/app/accounts/:id/crm` | admin A             | Chromium 1024×768           | Axe critical/serious                                                  | zero                      |
| CRM-A11Y-04        | `/app/accounts/:id/crm` | admin A             | Chromium 1366×768           | Axe critical/serious                                                  | zero                      |
| CRM-A11Y-05        | `/app/accounts/:id/crm` | admin A             | Chromium 1920×1080          | Axe critical/serious                                                  | zero                      |
| CRM-REDESIGN-01    | `/app/accounts/:id/crm` | admin A             | cinco viewports Chromium    | hierarquia, ações, KPIs, filtros e board responsivo                   | 10/10 aprovado            |
| CRM-KEYBOARD-01    | `/app/accounts/:id/crm` | admin A             | cinco viewports Chromium    | `/` foca busca, `Escape` limpa e accordion mobile permanece acessível | aprovado                  |
| CRM-PERF-VISUAL-01 | `/app/accounts/:id/crm` | admin A             | Chromium                    | superfícies operacionais sem `backdrop-filter`                        | aprovado                  |
| ROUTES-MANIFEST-01 | inventário completo     | n/a                 | geração estática            | gerar rotas e superfícies não-URL                                     | 135 rotas + 8 superfícies |
| TENANCY-P0         | APIs/CRM/CAPITÃO        | contas A/B          | request spec                | leitura e mutation cross-account negadas (401/404)                     | aprovado (CRM-020, 8/8)   |
| CRM-201-01         | CRM Kanban/listas       | admin A             | API + Playwright            | 1996 deals na coluna, 1996 paginados sem duplicatas, soma reconciliada | aprovado (CRM-023)        |
| E2E-P0-00          | Inbox → CAPITÃO → CRM   | admin A             | Chromium                    | jornada autenticada inbox→estado IA→deal→board                         | aprovado (CRM-022, 9/9)   |
| VISUAL-F0          | famílias autenticadas   | admin A             | 1366×768 light/dark + 5×2   | 170 rotas OK, 0 falha 5xx, 0 overflow, 1 console 404 (param fixture)   | aprovado c/ ressalva      |
| INTEGRATIONS-F0    | Evolution/Google/LLM    | admin/operador      | sandbox                     | contrato e jornada externa                                            | pendente                  |
| CRM-STATES-033     | telas CRM               | admin/agent         | revisão + spec              | vazio/erro/offline/permissão auditados                                 | aprovado (CRM-033)        |

Os artefatos locais de falha ficam em `qa/e2e/test-results` e
`qa/e2e/playwright-report`. Antes de publicação, devem ser sanitizados e
movidos para `docs/qa/evidencias/<release>/<cenario>/<browser>/`.
