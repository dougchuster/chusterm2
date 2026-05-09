# 🔍 ChusteRM — Relatório de Auditoria Completa do Sistema

> **Última atualização:** 2026-05-08 (sessão de hardening crítico)
> **Versão:** Docker Compose (Core + CRM Service + Orchestrator + Identity Bridge + Evolution API)
> **Ambiente:** Desenvolvimento (localhost:3010)

---

## 📋 Resumo Executivo

| Categoria | Total | Críticos | Médios | Baixos |
|-----------|-------|----------|--------|--------|
| Infraestrutura / Docker | 6 | 2 | 3 | 1 |
| Autenticação (UI) | 3 | 0 | 2 | 1 |
| Backend (Rails) | 5 | 1 | 3 | 1 |
| Frontend (Vue/CRM) | 8 | 1 | 5 | 2 |
| Build / Performance | 3 | 0 | 1 | 2 |
| Branding / i18n | 3 | 0 | 3 | 0 |
| **Total** | **28** | **4** | **17** | **7** |

> **Resolvidos nesta sessão:** CRIT-02, CRIT-03, CRIT-05 (parcial), MED-02, **NEW-01**
> **Novos achados:** ~~NEW-01~~ ✅, NEW-02 (locale `en` em vez de `pt_BR`), NEW-03 (URLs de branding chatwoot.com), NEW-04 (Core também roda em RAILS_ENV=production)

### Serviços verificados

| Serviço | Status | Porta |
|---------|--------|-------|
| Core (Rails) | ✅ Healthy | 3010→3000 |
| CRM Service (Node) | ✅ Healthy | 4003→4000 |
| Orchestrator (Node) | ✅ Healthy | 4001 |
| Identity Bridge (Node) | ✅ Healthy | 4002 |
| Evolution API | ✅ Healthy | 8085→8080 |
| PostgreSQL | ✅ Healthy | 5436→5432 |
| Redis | ✅ Healthy | 6382→6379 |
| Sidekiq | ✅ Healthy | — |
| Vite Watch | ✅ Running | — |
| Mailhog | ✅ Running | 8025/1025 |

### Páginas de login verificadas

| Página | HTTP | Design | Acentuação | Locale |
|--------|------|--------|------------|--------|
| `/app/login` | 200 | ✅ Glassmorphism | ✅ OK | ⚠️ `en` em vez de `pt_BR` |
| `/app/login/sso` | 200 | ✅ Glassmorphism | ✅ OK | ⚠️ idem |
| `/super_admin/sign_in` | 200 | ✅ Glassmorphism | ✅ OK | ✅ `lang="pt-BR"` |

---

## ✅ RESOLVIDOS NESTA SESSÃO (2026-05-08)

### ~~CRIT-02: Branding init errors com 127.0.0.1~~
- **Status:** ✅ RESOLVIDO
- **Causa raiz:** Initializer rodava em contextos onde `InstallationConfig` não estava disponível (asset precompile, rake tasks) e a conexão caía no fallback Rails (`127.0.0.1:6379`/`::1:5432`).
- **Solução aplicada:** `core/config/initializers/chusterm_branding.rb` agora:
  - Aborta cedo se `InstallationConfig` não estiver definido.
  - Verifica `data_source_exists?('installation_configs')` em `begin/rescue` antes de tentar persistir.
  - Mensagem de log mudou de "init error" para "init skipped" e inclui classe da exceção.
- **Validação:** `docker logs chusterm-core-1` desde restart não contém mais "Branding init error". Logo, nome e branding renderizam corretos no login.

### ~~CRIT-03: Migrations órfãs `20260502000001` e `20260507000001`~~
- **Status:** ✅ RESOLVIDO
- **Causa raiz:** `core/Dockerfile` linhas 197-205 fazia `COPY db/migrate/20260501*.rb`, `20260504*`, `20260505*`, `20260506*` — **omitindo** `20260502*` e `20260507*`. Os arquivos existiam no host mas nunca eram copiados para a imagem.
- **Solução aplicada:**
  - Adicionado `COPY db/migrate/20260502*.rb` e `COPY db/migrate/20260507*.rb` no Dockerfile.
  - Adicionado comentário explicativo para alertar sobre o padrão "wildcard por dia" evitar omissões futuras.
  - `docker cp` dos dois arquivos para containers `core` e `sidekiq` em runtime.
- **Validação:** `rails db:migrate:status` agora mostra "Create crm cadence enrollments" e "Adjust crm external connections per user" em vez de `NO FILE`.

### ~~MED-02: Sidekiq com `RAILS_ENV=production` hardcoded~~
- **Status:** ✅ RESOLVIDO (parcial — vide NEW-04)
- **Solução aplicada:** `docker-compose.yml` agora usa `RAILS_ENV=${RAILS_ENV:-production}` permitindo override via `.env` sem editar compose. Comando do Sidekiq também passou a usar a mesma variável (`sidekiq -e ${RAILS_ENV:-production}`).
- **Nota:** A imagem base `chatwoot/chatwoot:latest` já define `RAILS_ENV=production` em `ENV`. Para realmente rodar em development, o `.env` precisa explicitamente ter `RAILS_ENV=development` — vide NEW-04.

### ~~CRIT-05: Vite build com chunks gigantes~~
- **Status:** 🟡 PARCIALMENTE RESOLVIDO
- **Solução aplicada:** `core/vite.config.ts` com `manualChunks` agressivo:
  - `icons-dashboard` / `icons-base` → JSONs de SVG paths isolados em chunks dedicados (era arrastado para chunk de 10MB)
  - `vendor-sentry`, `vendor-charts`, `vendor-formkit`, `vendor-editor` (tiptap/prosemirror), `vendor-highlight`, `vendor-dompurify`, `vendor-floating`, `vendor-lucide` → vendor splits explícitos
  - `chunkSizeWarningLimit: 1000` para silenciar avisos abaixo de 1MB
- **Métricas (antes → depois):**
  - **Build time:** 318s → 100s (**3.18× mais rápido**)
  - **icons-dashboard:** isolado em 113 kB (gzip 38 kB) — antes diluía no chunk principal
  - **vendors separados:** 7 chunks vendor (23 kB a 361 kB), antes tudo aglomerado
  - **DashboardIcon-*.js:** 10.1 MB → 9.9 MB (-2%) — **melhoria mínima** (vide observação abaixo)
- **Limitação restante:** O chunk `DashboardIcon-*.js` de 9.9 MB **não é** o componente `DashboardIcon.vue`. É um chunk compartilhado que o Rollup nomeou pelo primeiro arquivo importado em comum entre os dois entrypoints (`dashboard.js` e `v3app.js`). Para reduzi-lo seria necessário reorganizar a arquitetura de entrypoints ou aplicar code-splitting via `import()` dinâmico nas rotas — fora do escopo de hardening crítico.

---

## 🔴 CRÍTICOS REMANESCENTES

### CRIT-01: Docker — Core não monta código Ruby como volume
- **Status:** ⚠️ NÃO TRATADO (escopo da sessão excluiu — risco de regressão de performance no Windows)
- **Localização:** `docker-compose.yml` → serviço `core` (linhas 209-211)
- **Descrição:** Apenas `public/vite` e `storage` são montados. Alterações em controllers, views, models, configs exigem `docker cp` + restart ou rebuild.
- **Solução proposta:** volumes adicionais (`./core/app/views`, `./core/app/controllers`, `./core/app/models`, `./core/config`) com `:delegated` no Windows. Risco: perf de I/O em Windows host.
- **Workaround atual:** Helper script ou `docker cp` manual.

### CRIT-04: eslint-disable generalizado nos componentes CRM
- **Status:** ⚠️ NÃO TRATADO (escopo da sessão excluiu — refatoração massiva)
- **Localização:** Todos os arquivos em `dashboard/components/crm/` e `dashboard/routes/dashboard/crm/pages/`
- **Descrição:** Strings hardcoded em pt-BR violando i18n. Solução incremental migrando para `i18n/locale/pt_BR/crm.json` e `$t()`.

---

## 🆕 NOVOS BUGS DESCOBERTOS NESTA SESSÃO

### ~~NEW-01 (🔴 Crítico): 22 migrations órfãs adicionais~~ ✅ RESOLVIDO
- **Localização:** `schema_migrations` PostgreSQL
- **Origem confirmada:** essas 22 versões vêm de uma versão anterior/diferente do Chatwoot rodada no banco antes da imagem atual. **Não estão na imagem upstream `chatwoot/chatwoot:latest`** (113 migrations, sem nenhum desses timestamps), nem no histórico Git do fork ChusteRM (`git log --all --diff-filter=D` retorna vazio).
- **Versões afetadas (22):** `20260404000001-2`, `20260405100001-8`, `20260406000001-11`, `20260407000001`.
- **Solução aplicada (Opção B — stubs no-op):**
  - Criados 22 arquivos `core/db/migrate/<timestamp>_legacy_upstream_stub.rb` com `class LegacyUpstreamStub<timestamp> < ActiveRecord::Migration[7.1]; def change; end; end`.
  - Cada arquivo tem comentário explicando a origem e referenciando este relatório.
  - `Dockerfile` atualizado com `COPY db/migrate/20260404*.rb`, `20260405*`, `20260406*`, `20260407*` para sobreviver a rebuilds.
  - Sincronizados via `docker cp` para `chusterm-core-1` e `chusterm-sidekiq-1`.
- **Validação:** `rails db:migrate:status | grep 'NO FILE' | wc -l` agora retorna **0**. App respondendo 200 OK em `/app/login` e `/health`.
- **Trade-off conhecido:** se o banco for resetado (`db:reset`), os stubs rodarão como no-ops (não recriam o schema que as migrations originais aplicaram). Para nova instalação from-scratch, será preciso reconstruir o schema desejado a partir do `db/schema.rb` ou identificar as features que ficaram sem migration de origem.

### NEW-02 (🟡 Médio): `selectedLocale` ainda é `en` no `chustermConfig`
- **Localização:** `app/views/layouts/vueapp.html.erb` (`window.chustermConfig`) ou origem em `app/controllers/application_controller.rb`
- **Descrição:** O HTML servido em `/app/login` contém `selectedLocale: 'en'` apesar de `pt_BR` estar configurado como default em `core/config/application.rb` ou similar. A memória do projeto diz "responder em pt-BR".
- **Reprodução:** `curl http://localhost:3010/app/login | grep selectedLocale` → `selectedLocale: 'en'`.
- **Impacto:** Usuário sem conta autenticada vê interface em inglês mesmo o sistema sendo pt_BR-first.
- **Prioridade:** 🟡 Média — afeta UX de novos usuários.

### NEW-03 (🟡 Médio): URLs de branding ainda apontam para chatwoot.com
- **Localização:** `window.globalConfig` no HTML servido
- **Descrição:** Vários campos do `globalConfig` ainda têm valores chatwoot:
  ```
  WIDGET_BRAND_URL: "https://www.chatwoot.com"
  TERMS_URL: "https://www.chatwoot.com/terms-of-service"
  PRIVACY_URL: "https://www.chatwoot.com/privacy-policy"
  ```
  Adicionalmente, a `<meta name="description">` ainda diz: *"ChusteRM is a customer support solution that helps companies engage customers over Messenger, Twitter, Telegram, WeChat, Whatsapp..."* — texto Chatwoot original com nome trocado.
- **Solução:** Atualizar `installation_config.yml` (chaves `WIDGET_BRAND_URL`, `TERMS_URL`, `PRIVACY_URL`) e a meta description no layout principal (`app/views/layouts/application.html.erb` ou `vueapp.html.erb`).
- **Prioridade:** 🟡 Média — visibilidade externa.

### NEW-04 (🟡 Médio): Core também roda em RAILS_ENV=production em dev
- **Localização:** Imagem base `chatwoot/chatwoot:latest` define `ENV RAILS_ENV=production`
- **Descrição:** Não só Sidekiq (MED-02), mas o próprio `core` roda em production. Boot log: `Rails 7.1.5.2 application starting in production`. O `.env` tem `APP_ENV=development` mas não define `RAILS_ENV`.
- **Impacto:**
  - Sem hot-reload de código Ruby (combinado com CRIT-01 = ciclo de dev mais lento).
  - Stack traces simplificados em erros 500.
  - Asset precompile diferente, gems não-dev podem estar ausentes.
- **Solução:** Adicionar `RAILS_ENV=development` ao `.env` para o ambiente local. Pode requerer rebuild da imagem com gems de development incluídas.
- **Prioridade:** 🟡 Média — mas requer mais investigação (mudar pode quebrar inits que assumem production).

### NEW-05 (🟢 Baixo): Deprecation warnings persistentes
- **Localização:** boot logs `core` e `sidekiq`
- **Descrição:** Vários warnings recorrentes:
  - `RubyLLM's legacy acts_as API is deprecated` (será removido em RubyLLM 2.0)
  - `redis-namespace`: `Passing 'info' command to redis as is; ... has been deprecated and will be removed in redis-namespace 2.0`
  - `Sass legacy JS API is deprecated` (durante build do Vite)
- **Impacto:** Funciona hoje mas quebrará em upgrades futuros das dependências.
- **Prioridade:** 🟢 Baixa, mas não esquecer.

---

## 🟡 MÉDIOS REMANESCENTES (do relatório anterior)

### MED-01: Deprecation Rails.application.secrets
- **Status:** Não tratado nesta sessão. Migrar para `Rails.application.credentials`.

### MED-03: Login Index.vue usa Options API legacy
- **Status:** Não tratado. Refatorar para `<script setup>`.

### MED-04: `accountIdFromRoute()` usa `window.location.pathname`
- **Status:** Não tratado. Receber `accountId` via Vue Router.

### MED-05: Variável `filterÁrea` com acento
- **Status:** Não tratado. Renomear para `filterArea`.

### MED-06: `window.confirm/alert` nativos no CRM
- **Status:** Não tratado. Criar `ConfirmDialog.vue`.

### MED-07: CrmIndex.vue com 1930 linhas
- **Status:** Não tratado. Extrair composables.

### MED-08: core-vite sem healthcheck
- **Status:** Não tratado.

### MED-09: Emojis como indicadores de urgência
- **Status:** Não tratado.

### MED-10: SSO action hardcoded
- **Status:** Não tratado.

### MED-11: Theme toggle inconsistente
- **Status:** Não tratado.

### MED-12: DEFAULT_STAGES hardcoded
- **Status:** Não tratado.

---

## 🟢 BAIXOS (do relatório anterior, não tratados)

- **LOW-01:** Score thresholds hardcoded (vir do backend)
- **LOW-02:** Google Fonts CDN (self-host)
- **LOW-03:** CRMSidebarCard.vue (24KB)
- **LOW-04:** Agenda.vue (88KB)
- **LOW-05:** Vite build time → ✅ **Reduzido de 318s para 100s** (CRIT-05 colateral)
- **LOW-06:** `completeActivity` camelCase vs snake_case API

---

## 📊 Saúde dos Microserviços

```
Core Health:      {"status":"woot"}                     ✅ 200 OK
CRM Service:      {"status":"ok"}                       ✅ 200 OK
Orchestrator:     {"status":"ok","version":"1.0.0"}     ✅ 200 OK
Identity Bridge:  {"status":"ok"}                       ✅ 200 OK
Login UI:         /app/login → 200 OK                   ✅
Super Admin UI:   /super_admin/sign_in → 200 OK         ✅
```

Nenhum erro `ERROR|FATAL|Exception` nos últimos 2 minutos de logs após restart.

---

## 🔧 Recomendação de Prioridade Atualizada

### Sprint 1 — Limpeza pós-hardening (1 dia)
1. ~~**NEW-01**~~ ✅ Resolvido com stubs no-op
2. **NEW-02** → Forçar `selectedLocale: 'pt_BR'` no controller
3. **NEW-03** → Atualizar `installation_config.yml` (WIDGET_BRAND_URL, TERMS_URL, PRIVACY_URL) e meta description

### Sprint 2 — Infraestrutura (2 dias)
4. **CRIT-01** → Volume mounts Ruby
5. **NEW-04** → Decidir entre rodar dev em `RAILS_ENV=development` (precisa rebuild da imagem com gems de dev)
6. **MED-08** → Healthcheck core-vite
7. **NEW-05** → Atacar deprecation warnings

### Sprint 3 — Performance (1-2 dias)
8. **CRIT-05 (parte 2)** → Lazy-load de rotas pesadas via `import()` para reduzir o chunk de 9.9 MB
9. **LOW-02** → Self-host Google Fonts

### Sprint 4 — Qualidade de Código (5 dias)
10. **CRIT-04** → i18n CRM (incremental)
11. **MED-05** → Renomear `filterÁrea`
12. **MED-07** → Refatorar CrmIndex.vue
13. **MED-06** → ConfirmDialog
14. **MED-01, MED-03, MED-04**

### Sprint 5 — Polish (2 dias)
15. **LOW-01 a LOW-04, LOW-06**, **MED-09 a MED-12**

---

## 🛠️ Comandos Úteis

```bash
# Sincronizar código para containers (até CRIT-01 ser resolvido)
docker cp core/app/views/ chusterm-core-1:/app/app/views/
docker cp core/app/controllers/ chusterm-core-1:/app/app/controllers/
docker cp core/config/initializers/ chusterm-core-1:/app/config/initializers/
docker restart chusterm-core-1 chusterm-sidekiq-1

# Verificar saúde de todos os serviços
curl -s http://localhost:3010/health
curl -s http://localhost:4003/health
curl -s http://localhost:4001/health
curl -s http://localhost:4002/health

# Verificar migrations
docker exec chusterm-core-1 sh -c "RAILS_ENV=production bundle exec rails db:migrate:status | grep 'NO FILE' | wc -l"

# Listar migrations órfãs no schema_migrations
docker exec chusterm-postgres-1 psql -U chusterm -d chusterm_core -c \
  "SELECT version FROM schema_migrations WHERE version NOT IN (SELECT regexp_replace(filename, '_.*$', '') FROM ...);"

# Verificar tamanho dos chunks Vite
docker logs chusterm-core-vite-1 --tail 50 | grep -E "kB|larger"

# Forçar rebuild Vite
docker restart chusterm-core-vite-1

# Ver logs de boot completo do core
docker logs chusterm-core-1 2>&1 | head -80
```

---

## 📜 Changelog desta sessão (2026-05-08)

- ✅ `core/config/initializers/chusterm_branding.rb` → hardening defensivo (early return + data_source_exists?)
- ✅ `core/Dockerfile` → adicionados `COPY db/migrate/20260404*.rb` ... `20260407*.rb` + `20260502*.rb` + `20260507*.rb` (corrige migrations órfãs em rebuilds)
- ✅ `docker-compose.yml` → Sidekiq usa `${RAILS_ENV:-production}` (override via .env)
- ✅ `core/vite.config.ts` → `manualChunks` para vendors e icons + `chunkSizeWarningLimit: 1000`
- ✅ `core/db/migrate/2026040*_legacy_upstream_stub.rb` → 22 stubs no-op para resolver órfãs (NEW-01)
- ✅ `docker cp` aplicado para sincronizar mudanças aos containers existentes sem rebuild

---

*Relatório atualizado por auditoria automatizada — 2026-05-08*
