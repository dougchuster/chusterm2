# F0 - Baseline de backend, Enterprise e seguranca

**Data:** 2026-07-13  
**Branch/HEAD:** `main` / `f5f0dde`  
**Ambiente:** Windows, Ruby 3.4.4, Rails 7.2.3.1, PostgreSQL local e Redis local  
**Resultado:** suites executadas sem falhas; pendencias esperadas registradas

## 1. Cobertura RSpec executada

As suites foram divididas por diretorio para evitar concorrencia sobre a mesma
base de testes. Nenhuma falha foi mascarada.

| Grupo | Exemplos | Falhas | Pendentes |
|---|---:|---:|---:|
| Core models | 823 | 0 | 22 |
| Core services | 1.167 | 0 | 17 |
| Core jobs | 283 | 0 | 0 |
| Core lib | 336 | 0 | 0 |
| Core builders | 232 | 0 | 0 |
| Core listeners/helpers | 271 | 0 | 0 |
| Core mailers/mailboxes/finders | 236 | 0 | 0 |
| Core policies/presenters | 87 | 0 | 0 |
| Core requests/actions/drops/channels/config/dispatchers/swagger/middleware | 82 | 0 | 15 |
| Core controllers, em shards | todos os arquivos do diretorio | 0 | conforme suite |
| Enterprise services | 433 | 0 | 0 |
| Enterprise models/policies/presenters/listeners/mailers/drops/builders | 405 | 0 | 0 |
| Enterprise jobs | 129 | 0 | 0 |
| Enterprise lib | 152 | 0 | 0 |
| Enterprise controllers | 380 | 0 | 0 |

Os 181 arquivos sob `spec/enterprise` foram cobertos. As pendencias de MFA
continuam explicitas porque criptografia/MFA nao estao configurados no ambiente
de teste; nao foram convertidas em sucesso artificial.

Depois das correcoes de estilo/refatoracao, 92 exemplos diretamente afetados
foram repetidos e passaram.

## 2. Portoes estaticos

| Comando | Resultado |
|---|---|
| `bundle exec rubocop --cache false --format simple` | 2.632 arquivos, zero ocorrencias |
| `bundle exec rails zeitwerk:check` | `All is good!` |
| `bundle exec bundler-audit check` | nenhuma vulnerabilidade conhecida |
| `bundle exec brakeman --no-pager -q -i config/brakeman.ignore` | zero alertas; dois ignores documentados |
| `git diff --check` | sem erro de whitespace; apenas avisos CRLF/LF |

## 3. Baselines adjacentes

- Core frontend: 3.349 testes, build de producao e audit sem vulnerabilidade
  alta, detalhados em `F0-FRONTEND-BASELINE.md`.
- Orchestrator: 9 testes, build TypeScript e audit aprovados.
- Runtime Docker e restore: detalhados em
  `F0-RESTORE-DRILL-2026-07-13.md`.

## 4. Imagens e runtime Docker atualizados

As imagens `core`, `sidekiq` e `orchestrator` foram reconstruidas a partir do
worktree auditado. O Dockerfile do Core agora instala o `Gemfile.lock` do fork,
em vez de herdar silenciosamente as gems da imagem upstream.

| Verificacao | Resultado |
|---|---|
| `docker compose build core sidekiq orchestrator` | aprovado |
| `bundle check` dentro de Core e Sidekiq | dependencias satisfeitas |
| Rails dentro do Core em execucao | 7.2.3.1 |
| Devise dentro do Core em execucao | 5.0.4 |
| gRPC dentro do Core em execucao | 1.72.0 |
| `docker compose run --rm core bundle exec rails db:migrate` | migration `20260710000001` aplicada |
| health Core | `{"status":"woot"}` |
| health Orchestrator | `{"status":"ok","version":"1.0.0"}` |
| health Evolution API | HTTP 200, versao 2.3.0 |
| Core, Sidekiq, Orchestrator, PostgreSQL, Redis e Evolution | `healthy` |
| `core-vite` | continua desligado/opt-in; nao consome CPU em background |

O gRPC foi fixado em 1.72.0 porque essa e a versao nativa presente na imagem
Alpine/musl pinada. Versoes posteriores eram compiladas localmente e esgotavam
CPU/memoria durante o build. O lockfile resultante passou novamente no
`bundler-audit`.

No momento da verificacao, o Sidekiq registrava 84.097 jobs processados, 353
falhas historicas e 2 jobs enfileirados. Nao houve erro de boot nos logs dos
tres servicos reconstruidos.

## 5. Correcoes funcionais validadas

- busca padrao de conversas voltou a representar apenas conversas abertas;
- configuracoes persistentes de instalacao deixaram os testes deterministas;
- fallback de excecao do CAPITAO ficou neutro e seguro, sem resposta juridica
  hardcoded;
- geracao de FAQ voltou a exigir resposta JSON;
- handoff do CAPITAO produz mensagem publica e resumo CRM privado estruturado;
- reconciliacao de plano Enterprise voltou a executar configuracao e features;
- template SAML Enterprise usa o estado real da conta;
- job de resolucao do CAPITAO voltou a alcancar avaliacao, handoff e resolucao;
- sincronizacao de plano passou a consumir os valores recebidos do Hub;
- configuracao global foi refatorada sem mudar o contrato, com testes verdes.

## 6. Dividas observadas, nao ocultadas

- avisos de enums por keyword e `ActiveSupport::ProxyObject` para Rails 8;
- `fiddle` devera ser declarado antes de Ruby 3.5;
- o banco de runtime possui IDs historicos em `schema_migrations` cujos arquivos
  nao existem mais no checkout; os arquivos atuais estao aplicados, mas essa
  deriva precisa de inventario antes de um rebuild do zero;
- fixture canonica e primeiro harness Playwright autenticado foram criados; a
  baseline visual ampla ainda nao existe;
- copia externa/offsite do backup ainda nao foi configurada.

## 7. Criterio de continuidade

Esta evidencia fecha a baseline automatizada de backend da F0. Ela nao encerra
a Fase 0 inteira: fixture canonica, E2E autenticado, axe, cinco viewports,
sandboxes externas e reconciliacao final do worktree continuam obrigatorios.
