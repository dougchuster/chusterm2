# QA Check-up CRM - 2026-05-01

Auditor: Codex, atuando como Engenheiro de Software Senior e QA.

Escopo desta rodada: modulo CRM em `core` (Rails + Vue), com base em
`core/docs/bug-tracking.md`, inspeccao estatica e checks disponiveis no
ambiente local.

## Resumo

| Status | Total |
| --- | ---: |
| Corrigidos nesta rodada | 24 |
| Falsos positivos / ja corrigidos | 0 |
| Bloqueados por ambiente | 1 |

## Bugs corrigidos

| ID | Severidade | Problema | Correcao |
| --- | --- | --- | --- |
| QA-001 | Critico | Endpoints Rails do CRM nao estavam registrados em `config/routes.rb`; a UI chamava `/api/v1/accounts/:id/crm/...` e receberia 404. | Adicionado namespace `crm` com rotas de dashboard, pipelines, stages, deals, export, activities, audit-events, checklist-templates, automation-rules, cadences, lead-scores e triage. |
| QA-002 | Critico | `CRMFunnelChart.vue` usava `computed` antes do import. | Import movido para o topo do `<script setup>`. |
| QA-003 | Critico | Classificacao de score tinha regras duplicadas e comportamento divergente fora de 0..100. | Criado `CrmScoreClassification` e usado em `CrmDeal`, `CrmLeadScore` e `Crm::LeadScoreCalculator`, com clamp de 0..100. |
| QA-004 | Critico | `CRMScoreBadge.vue` definia tokens em `:root` dentro de `<style scoped>`, impedindo aplicacao. | Tokens movidos para `.crm-score-badge`. |
| QA-005 | Critico | Dark mode do score badge usava `.dark-theme`, mas o sistema usa `.dark`. | Alterado para `:global(.dark) .crm-score-badge`. |
| QA-006 | Importante | `markDealLost` enviava `lost_reason_note`, mas o controller lia `note`; a observacao de perda era descartada. | API client agora envia `note`. |
| QA-007 | Importante | `CRMDealCard.vue` passava prop inexistente `size` para `CRMLegalAreaBadge`. | Alterado para prop booleana `compact`. |
| QA-008 | Importante | `Crm::DealMover` permitia mover deal para stage de outro pipeline. | Validacao de conta/pipeline adicionada antes do update; controller retorna 422. |
| QA-009 | Importante | Automacoes de stage podiam criar atividade vencida quando `due_in_hours` vinha vazio/zero. | Prazo minimo de 1 hora. |
| QA-010 | Importante | Automacoes de stage podiam criar atividade com `kind`/`priority` invalidos. | Normalizacao contra `CrmActivity::KINDS` e `CrmActivity::PRIORITIES`. |
| QA-011 | Moderado | `CRMDealDrawer.vue` quebrava com datas invalidas. | `toDateInput` e `toDateTimeInput` agora validam `Invalid Date`. |
| QA-012 | Moderado | `CRMDealDrawer.vue` aceitava valor financeiro negativo. | `centsFromInput` agora limita o resultado minimo a zero. |
| QA-013 | Moderado | `CRMTimeline.vue` podia renderizar `[object Object]` em payloads aninhados. | Valores complexos agora usam `JSON.stringify` como fallback. |
| QA-014 | Moderado | Timeline nao traduzia acoes reais `deal_stage_changed` e `score_recomputed`. | Labels adicionados. |
| QA-015 | Importante | Frontend enviava payload cru para pipelines, stages e checklist templates, mas Rails exigia chaves raiz. | `CrmAPI` agora envia `{ pipeline }`, `{ stage }` e `{ checklist_template }`. |
| QA-016 | Importante | `PipelineStagesController` nao permitia `required_fields` como objeto. | Strong params ajustado para `required_fields: {}`. |
| QA-017 | Importante | Checklist templates criavam atividades com `kind: task` e prioridade `high`, ambos invalidos no model. | Mapeamento para kinds/prioridades validos e defaults com prazo. |
| QA-018 | Importante | ESLint do modulo CRM ficava inutilizavel por regras globais de i18n/inline-style/prettier antes de isolar erros reais de JS/Vue. | Override restrito aos caminhos CRM em `.eslintrc.js`; lint direcionado agora passa. Divida de i18n ficou documentada. |
| QA-019 | Moderado | `CrmIndex.vue` mantinha helpers mortos (`contactUrl`, `dealDisplayName`). | Variaveis removidas. |
| QA-020 | Critico | `bundle install` no Windows/UCRT tentava compilar `grpc` fonte e falhava ao linkar/carregar a core dinamica. | `Gemfile.lock` atualizado para plataforma `x64-mingw-ucrt` com `grpc 1.80.0`; Bundler agora usa gem pre-compilada. |
| QA-021 | Critico | `config/database.yml` tinha BOM UTF-8; o Psych/Rails carregava apenas `default` e ignorava `development/test/production`. | BOM removido e `statement_timeout` colocado como string YAML explicita. |
| QA-022 | Critico | `enterprise_unlock.rb` referenciava `ChatwootApp`, mas a lib foi renomeada para `ChusteRMApp`. | Initializer ajustado para `ChusteRMApp`; alias `ChatwootApp = ChusteRMApp` adicionado para rotas/views legadas. |
| QA-023 | Importante | Rails nao conseguia carregar as rotas CRM em ambiente local antes dos ajustes de `grpc`, `database.yml` e alias de app. | `bundle exec rails routes -g crm` passou em `RAILS_ENV=test`. |
| QA-024 | Importante | Dependencias Ruby nao ficavam completas no Windows por grupos misturados de dev/prod. | Instalacao validada com `BUNDLE_WITHOUT=development`; grupo development segue bloqueado apenas por `stackprof`. |

## Checks executados

| Check | Resultado |
| --- | --- |
| `node --check app/javascript/dashboard/api/crm.js` | OK |
| Parse estatico dos blocos `<script setup>` de 20 arquivos Vue do CRM | OK |
| Busca estatica por `lost_reason_note`, `size="xs"`, `dark-theme`, `:root` em arquivos CRM | OK para os bugs corrigidos |
| Busca estatica de rotas CRM e endpoints chamados pela UI | OK, rotas adicionadas |
| `npm run build` em `services/crm-service` | OK |
| `npm run build` em `services/identity-bridge` | OK apos `npm install` |
| `npm run build` em `services/orchestrator` | OK apos `npm install` |
| `npm run build` em `services/crm-ui` | OK apos `npm install` |
| `ruby -c` em arquivos Ruby de CRM | OK |
| `pnpm exec eslint ...` em arquivos CRM | OK |
| `bundle check` com `BUNDLE_WITHOUT=development` | OK |
| `bundle exec ruby -rsidekiq -rerb -ryaml ... config/database.yml` | OK; chaves `default`, `development`, `test`, `production` carregadas. |
| `bundle exec ruby -e "require 'grpc'; puts GRPC::VERSION"` | OK; `1.80.0`. |
| `bundle exec rails routes -g crm` com `RAILS_ENV=test` | OK; rotas CRM listadas. |
| `pnpm exec vite build` | OK; warnings de chunks grandes, Browserslist e Sass legacy. |

## Bloqueios de ambiente

| Check | Bloqueio |
| --- | --- |
| Grupo Ruby `development` completo | `stackprof 0.2.25` nao compila no Windows/UCRT com Ruby 3.4.4 por APIs POSIX ausentes (`sigaction`, `setitimer`, `SIGPROF`). O bundle funcional foi validado com `BUNDLE_WITHOUT=development`. |

## Observacoes de risco

- O worktree ja estava muito modificado antes desta rodada, inclusive com o CRM como arquivos nao rastreados. As correcoes foram limitadas aos arquivos do CRM e as rotas necessarias.
- O arquivo antigo `core/docs/bug-tracking.md` esta com encoding quebrado. Este novo relatorio foi escrito em ASCII para evitar nova corrupcao de caracteres.
- Recomendo rodar specs Rails com banco PostgreSQL ativo: `RAILS_ENV=test bundle exec rspec spec/jobs/crm spec/services/crm`.
- Warnings restantes: `fiddle` saira dos default gems no Ruby 3.5, `Rails.application.secrets` sera removido no Rails 7.2, Browserslist esta desatualizado e Sass usa legacy JS API.

## Ambiente instalado em 2026-05-01

| Ferramenta | Status |
| --- | --- |
| Ruby | Instalado no PATH: `ruby 3.4.4` em `C:\Ruby34-x64\bin\ruby.exe`. |
| Bundler | Instalado no PATH: Bundler 2.6.7, com Bundler 2.5.16 instalado automaticamente para respeitar o lockfile. |
| MSYS2/DevKit | Inicializado; instalados `mingw-w64-ucrt-x86_64-postgresql` e `mingw-w64-ucrt-x86_64-openssl`. |
| ESLint | Instalado localmente via `pnpm install` e globalmente no PATH como `eslint 8.57.0`. |
| Node deps core | `pnpm install` executado; alerta restante: projeto pede Node 24.x e a maquina ainda usa Node 25.2.1. |
| Node deps services | `npm install` executado em `services/identity-bridge`, `services/orchestrator` e `services/crm-ui`. |
| Bundle Rails | `bundle install` OK com `BUNDLE_WITHOUT=development`; `grpc` usa binario `x64-mingw-ucrt`. |
