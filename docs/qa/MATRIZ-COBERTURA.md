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
| TENANCY-P0         | APIs/CRM/CAPITÃO        | contas A/B          | todos aplicáveis            | leitura e mutation cross-account                                      | pendente                  |
| CRM-201-01         | CRM Kanban/listas       | admin A             | cinco viewports             | localizar 201º deal e reconciliar soma                                | pendente                  |
| E2E-P0-00          | Inbox → CAPITÃO → CRM   | operador/vendedor   | Chromium/Firefox/WebKit     | jornada composta duas vezes                                           | pendente                  |
| VISUAL-F0          | famílias autenticadas   | personas aplicáveis | cinco viewports, light/dark | screenshots aprovados                                                 | pendente                  |
| INTEGRATIONS-F0    | Evolution/Google/LLM    | admin/operador      | sandbox                     | contrato e jornada externa                                            | pendente                  |

Os artefatos locais de falha ficam em `qa/e2e/test-results` e
`qa/e2e/playwright-report`. Antes de publicação, devem ser sanitizados e
movidos para `docs/qa/evidencias/<release>/<cenario>/<browser>/`.
