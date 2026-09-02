# F0 Baseline de Ambiente e Evidências

**Data:** 2026-07-13  
**Branch/HEAD:** `main` / `f5f0dde`  
**Status:** 🟡 parcial — runtime, restore, suites, fixture e primeiro harness E2E aprovados; matriz ampla/visual pendentes

## 1. Ferramentas locais

| Ferramenta | Versão observada | Contrato | Estado |
|---|---|---|---|
| Git | 2.53.0.windows.1 | informativo | ✅ |
| Ruby | 3.4.4 | `core/.ruby-version` = 3.4.4 | ✅ |
| Bundler | 2.6.7 | compatível com o bundle atual | ✅ |
| Node | 25.2.1 | plano/CI alvo = Node 24 | ⚠️ divergente |
| pnpm | 10.28.2 | package manager major 10 | ✅ major; versão exata não pinada pelo runtime local |
| Docker CLI | 29.3.1 | informativo | ✅ |
| Docker Compose | 5.1.0 | informativo | ✅ |

## 2. Runtime

O Docker Desktop voltou a ficar disponível em 2026-07-13. Core, Sidekiq,
PostgreSQL, Redis, Orchestrator e Evolution foram exercitados e estabilizaram
como saudáveis. A migration atual foi aplicada, o endpoint `/api` confirmou
PostgreSQL e Redis como `ok`, e o health do Core retornou `{status: woot}`.

O serviço `core-vite` permanece desligado e opt-in. O bundle de produção é
compilado sem cache antigo e sincronizado no volume compartilhado ao iniciar o
Core, evitando que um manifesto persistente esconda assets novos.

## 3. Configuração estática

| Verificação | Resultado |
|---|---|
| `docker compose config --quiet` | exit 0 |
| `docker compose -f docker-compose.dev.yml config --quiet` | exit 0 |
| `docker compose -f docker-compose.prod.yml config --quiet` | exit 0, com variáveis obrigatórias ausentes no shell |
| parser PowerShell em `scripts/backup.ps1` | PASS |
| `git diff --check` | PASS |
| `git diff --cached --check` | PASS |

Warnings do Compose de produção:

- `POSTGRES_PASSWORD` ausente;
- `REDIS_PASSWORD` ausente;
- `EVOLUTION_SERVER_URL` ausente.

Esses valores não devem ser preenchidos com defaults inseguros. A validação real deve usar um arquivo de ambiente de sandbox/produção protegido.

## 4. Integridade das fontes

Os sete hashes registrados no plano continuam idênticos:

| Fonte | SHA-256 |
|---|---|
| `prompt-reformulacao-crm.md` | `E43BE28B2D88C03DC6A5F16C0DC3FB627ED98EC9C18905070A3E752A3FF50533` |
| `AUDITORIA.md` | `85F78FDB024C9E9D9089DD469531CF34327F7A3FF3D7CFB7715992295EF641A5` |
| `AUDITORIA-CSS.md` | `88B7749AB9DA2BB8F5122BB199BFB2F3DEE56CB8C1349676809B3769BD4DB655` |
| `AUDITORIA-FUNCIONAL.md` | `E3E88F00CD880D117A00A098EED024A291ABBC945E8283094C1AD2D6E96119FB` |
| `DECISOES.md` | `A9982251989E8AD5D61B831E688AB7416B6634B3589BFAA14D134B9FB0340A17` |
| `SETUP.md` | `30723CC3FF80A91D35568C1B50724402667C16F315B51ECF1BA2FA7C5B8863EA` |
| `docs/audit/INVENTARIO-ROTAS.md` | `4852241C23E289E4ED5EF08F82837BE107B835814A0FCEA172FB9B86FD01B6C5` |

Hash do plano executado:

`0E31D4DFA61BDF872BA85FD2180B5799C77E19790A8A64308EF93070FD126CD9`

## 5. Gates pendentes

- [x] executar com Node 24;
- [x] disponibilizar o Docker engine;
- [x] registrar `docker compose ps` e health checks;
- [x] confirmar migrations atuais aplicadas;
- [x] criar backup de PostgreSQL, `core-storage` e volumes Evolution;
- [x] restaurar o backup em cópia descartável e reconciliar contagens/checksums;
- [x] executar suítes e registrar comandos/commit/ambiente;
- [x] atualizar esta baseline após a mudança de estado.

## 6. Frontend Core

A linha de base do frontend foi recuperada e está verde em Node 24/pnpm 10: 342 arquivos, 3.349 testes, lint incremental e build de produção passaram. A vulnerabilidade alta do Vite foi removida com a atualização para 6.4.3. Evidência detalhada em `docs/execution/F0-FRONTEND-BASELINE.md`.

## 7. Próxima ação segura

Completar o gate F0 com testes cross-tenant P0, baseline visual das famílias de
tela nos cinco viewports, Firefox/WebKit, estados de interface e a jornada
composta `E2E-P0-00`, sem iniciar o redesign antes dessa evidência.

## 8. Atualização de 2026-07-13

O Docker voltou a ficar disponível e a baseline avançou:

- Core, PostgreSQL, Redis, Sidekiq, Orchestrator e Evolution estavam saudáveis;
- os três endpoints documentados em `SETUP.md` responderam com sucesso;
- os arquivos de migration atuais estavam aplicados;
- backup e restore local foram comprovados em
  `F0-RESTORE-DRILL-2026-07-13.md`;
- backend, Enterprise e portões de segurança estão registrados em
  `F0-BACKEND-BASELINE.md`.

O status da F0 continua parcial. Permanecem pendentes a cópia externa do
backup, a matriz E2E/visual ampla, sandboxes externas e a reconciliação dos IDs
históricos de migration sem arquivo no checkout. A fixture canônica, o
Playwright autenticado e o primeiro gate Axe foram implementados depois desta
atualização; consulte `F0-QA-HARNESS.md`.

## 9. Implantação local validada em 2026-07-13

Depois do restore drill, as imagens do worktree atual foram reconstruídas e
ativadas. A migration `20260710000001` foi aplicada antes da troca dos
contêineres. Core, Sidekiq, Orchestrator, PostgreSQL, Redis e Evolution
estabilizaram como `healthy`; os endpoints de Core, Orchestrator e Evolution
responderam com sucesso.

O Core ativo foi confirmado em Rails 7.2.3.1, Devise 5.0.4 e gRPC 1.72.0. O
serviço `core-vite` permanece desligado e opt-in, evitando o consumo de CPU que
motivou a investigação inicial. Evidências detalhadas estão em
`F0-BACKEND-BASELINE.md` e `F0-RESTORE-DRILL-2026-07-13.md`.

## 10. Fixture e primeiro harness E2E

A fixture canônica idempotente foi executada com contas A/B, oito personas de
login, CAPITÃO somente na conta A, pipeline conhecido e 201 deals. O projeto
Playwright gerou manifesto com 135 rotas e oito superfícies, autenticou as oito
personas e aprovou health/smoke.

O Axe do CRM passou com zero violações critical/serious em Chromium nos cinco
viewports oficiais: 360×800, 768×1024, 1024×768, 1366×768 e 1920×1080.
Detalhes, limitações e próximos gates estão em `F0-QA-HARNESS.md` e
`../qa/MATRIZ-COBERTURA.md`.
