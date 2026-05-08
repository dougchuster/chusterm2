# 🔍 ChusteRM — Relatório de Auditoria Completa do Sistema

> **Data:** 2026-05-08  
> **Versão:** Docker Compose (Core + CRM Service + Orchestrator + Identity Bridge + Evolution API)  
> **Ambiente:** Desenvolvimento (localhost:3010)

---

## 📋 Resumo Executivo

| Categoria | Total | Críticos | Médios | Baixos |
|-----------|-------|----------|--------|--------|
| Infraestrutura / Docker | 5 | 2 | 2 | 1 |
| Autenticação (UI) | 3 | 0 | 2 | 1 |
| Backend (Rails) | 4 | 1 | 2 | 1 |
| Frontend (Vue/CRM) | 8 | 1 | 5 | 2 |
| Build / Performance | 3 | 1 | 1 | 1 |
| **Total** | **23** | **5** | **12** | **6** |

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

### Páginas de login verificadas visualmente

| Página | Design | Formulário | Toggle Tema | Acentuação |
|--------|--------|------------|-------------|------------|
| `/app/login` | ✅ Glassmorphism | ✅ OK | ✅ OK | ✅ OK |
| `/app/login/sso` | ✅ Glassmorphism | ✅ OK | ✅ OK | ✅ OK |
| `/super_admin/sign_in` | ✅ Glassmorphism (CORRIGIDO) | ✅ OK | ✅ OK | ✅ OK |

---

## ✅ RESOLVIDOS NESTA SESSÃO

### ~~CRIT-01: Alterações em arquivos ERB/Ruby não propagam para o container Docker~~
- **Status:** ✅ RESOLVIDO
- **Solução aplicada:** Arquivos copiados via `docker cp` + `docker restart chusterm-core-1`
- **Nota:** Solução permanente ainda precisa ser implementada (volume mount ou rebuild automatizado)

### ~~CRIT-04: Super Admin sign_in — Layout ainda usava versão antiga~~
- **Status:** ✅ RESOLVIDO
- **Verificado:** Screenshots confirmam glassmorphism, orbs animados, toggle de tema e acentuação funcionando.

---

## 🔴 CRÍTICOS (Necessitam ação imediata)

### CRIT-01: Docker — Core não monta código Ruby como volume
- **Localização:** `docker-compose.yml` → serviço `core` (linhas 209-211)
- **Descrição:** O container `core` NÃO monta o diretório do código Ruby/ERB como volume. Apenas `public/vite` e `storage` são montados. O `core-vite` monta `./core/app/javascript` para hot-reload de JS, mas alterações em controllers, views, models, e configs requerem `docker cp` + restart ou rebuild completo.
- **Impacto:** Qualquer alteração backend exige processo manual de deploy para o container.
- **Solução permanente:** Adicionar volumes no `docker-compose.yml`:
  ```yaml
  volumes:
    - ./core/app/views:/app/app/views
    - ./core/app/controllers:/app/app/controllers
    - ./core/app/models:/app/app/models
    - ./core/config:/app/config
    - core-vite-output:/app/public/vite
    - core-storage:/app/storage
  ```
- **Risco:** Volume mounts no Windows podem ter performance reduzida. Avaliar uso de `delegated` consistency mode.
- **Prioridade:** 🔴 Alta

### CRIT-02: Redis/PostgreSQL — Branding init errors
- **Localização:** `core/log/development.log`, `core/config/initializers/chusterm_branding.rb`
- **Descrição:** Logs mostram falhas repetidas de conexão ao Redis (`127.0.0.1:6379`) e PostgreSQL (`::1:5432`) no inicializador de Branding. Dentro do Docker, os serviços comunicam via nomes de container (`redis:6379`, `postgres:5432`), não localhost.
- **Mensagens:**
  ```
  [ChusteRM] Branding init error for INSTALLATION_NAME: ...redis://127.0.0.1:6379
  [ChusteRM] Branding init error for INSTALLATION_NAME: ...port 5432 failed: Connection refused
  ```
- **Impacto:** Logo, nome da instalação e branding caem para fallback. Não quebra o sistema mas degrada branding.
- **Solução:** Verificar `REDIS_URL` e `DATABASE_URL` no `.env` — devem usar nomes de serviço Docker internos. O initializer deve ter fallback gracioso sem logar repetidamente.
- **Prioridade:** 🔴 Alta

### CRIT-03: Migrations órfãs — "NO FILE" no migration status
- **Localização:** `db/migrate/`
- **Descrição:** Duas migrations aparecem como `********** NO FILE **********`:
  ```
  up  20260502000001  ********** NO FILE **********
  up  20260507000001  ********** NO FILE **********
  ```
  Isso significa que migrations foram executadas no banco mas os arquivos `.rb` correspondentes foram deletados do código.
- **Impacto:** `rails db:migrate:status` mostra estado inconsistente. Pode causar problemas em rollback ou nova instalação.
- **Solução:** Identificar o que essas migrations faziam e restaurar os arquivos, ou criar migrations "stub" vazias com os mesmos timestamps para satisfazer o schema_migrations.
- **Prioridade:** 🔴 Alta

### CRIT-04: eslint-disable generalizado nos componentes CRM
- **Localização:** Todos os arquivos em `dashboard/components/crm/` e `dashboard/routes/dashboard/crm/pages/`
- **Descrição:** Todo componente CRM usa:
  ```html
  <!-- eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text, vue/no-static-inline-styles -->
  ```
  Strings hardcoded em pt-BR: "Lead sem nome", "Alta prioridade", "Score pendente", "Pipeline Jurídico", "Gerencie atendimentos...", etc.
- **Impacto:** Internacionalização completamente quebrada para CRM. Build pode emitir warnings se eslint config mudar.
- **Solução:** Migrar strings para `i18n/locale/pt_BR/crm.json` e usar `$t()`.
- **Prioridade:** 🔴 Alta (mas pode ser tratada incrementalmente)

### CRIT-05: Vite build — chunks enormes (10MB+ DashboardIcon)
- **Localização:** `core-vite` container logs
- **Descrição:** O build Vite produz chunks desproporcionais:
  ```
  DashboardIcon-BQpgEGpD.js   10,105.99 kB (10MB!)
  dashboard-CDxNNRnV.js        3,307.39 kB (3.3MB)
  typing-DH0Kp7el.js             445.92 kB
  ```
  Warning do Vite: "Some chunks are larger than 500 kB after minification"
- **Impacto:** Tempo de carregamento lento, consumo excessivo de banda, performance ruim em conexões lentas.
- **Solução:**
  1. Configurar `build.rollupOptions.output.manualChunks` no `vite.config.ts`
  2. Usar `import()` dinâmico para code-splitting (lazy loading de rotas)
  3. Verificar se o `DashboardIcon` (10MB) está importando toda a lib de ícones — provavelmente deve usar tree-shaking
- **Prioridade:** 🔴 Alta

---

## 🟡 MÉDIOS (Devem ser corrigidos em breve)

### MED-01: Deprecation Warnings — Rails.application.secrets
- **Localização:** `core/config/environment.rb` (linha 5)
- **Descrição:** Três avisos de depreciação repetidos a cada boot:
  ```
  DEPRECATION WARNING: `Rails.application.secrets` is deprecated in favor of `Rails.application.credentials`
  ```
- **Impacto:** Funciona agora mas quebrará no Rails 7.2+.
- **Solução:** Migrar para `Rails.application.credentials`.

### MED-02: Docker — Sidekiq roda com RAILS_ENV=production em ambiente dev
- **Localização:** `docker-compose.yml`, linha 260
- **Descrição:** O Sidekiq está configurado com `RAILS_ENV=production` mesmo no compose de desenvolvimento.
- **Impacto:** Jobs podem se comportar diferente do esperado. Error reporting e logs podem estar suprimidos.
- **Solução:** Remover `RAILS_ENV=production` ou criar perfil separado.

### MED-03: Login Index.vue — Usa Options API (legado) vs Composition API
- **Localização:** `core/app/javascript/v3/views/login/Index.vue`
- **Descrição:** Index.vue usa `export default { ... }` (Options API) enquanto Saml.vue e componentes CRM usam `<script setup>` (Composition API). Inconsistência de padrão no mesmo projeto.
- **Solução:** Refatorar Index.vue para `<script setup>`.

### MED-04: CRM API — `accountIdFromRoute()` usa window.location.pathname
- **Localização:** `core/app/javascript/dashboard/api/crm.js`, linhas 4-10
- **Descrição:** O helper extrai `accountId` via `window.location.pathname.split('/')[3]`. Isso é frágil e quebra se a estrutura de URL mudar.
- **Solução:** Aceitar `accountId` como parâmetro do Vue Router.

### MED-05: CrmIndex.vue — Nome de variável com caractere acentuado
- **Localização:** `CrmIndex.vue`, linha 70
- **Descrição:** Variável `filterÁrea` usa "Á" acentuado. Embora JavaScript suporte, é anti-padrão e pode causar bugs com encodings diferentes, copy-paste, e ferramentas de build.
  ```js
  const filterÁrea = ref(route.query.área || '');
  ```
- **Solução:** Renomear para `filterArea` (sem acento).

### MED-06: CrmIndex.vue — `window.confirm()` e `window.alert()` nativos
- **Localização:** `CrmIndex.vue`, linhas 789, 812, 826
- **Descrição:** Usa `window.confirm()` e `window.alert()` nativos do browser para confirmações. Isso quebra a experiência visual do design system e não é estilizável.
- **Solução:** Criar componente `ConfirmDialog.vue` reutilizável com glassmorphism.

### MED-07: CrmIndex.vue — Arquivo com 1930 linhas
- **Localização:** `core/app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndex.vue`
- **Descrição:** O componente principal do CRM tem quase 2000 linhas (69KB). Contém lógica de Kanban, filtros, bulk actions, activities, health checks, board panning — tudo em um único arquivo.
- **Solução:** Extrair composables: `useCrmBoard.js`, `useCrmFilters.js`, `useCrmBulkActions.js`, `useCrmActivities.js`.

### MED-08: Core Vite Watch — Sem healthcheck
- **Localização:** `docker-compose.yml`, serviço `core-vite` (linhas 223-237)
- **Descrição:** O serviço `core-vite` não tem healthcheck. Impossível saber se está compilando.
- **Solução:** Adicionar healthcheck ou pelo menos volume para logs.

### MED-09: CRMDealCard — Emojis como indicadores de urgência
- **Localização:** `CRMDealCard.vue`, linhas 106-111
- **Descrição:** Emojis (🔴🟠🟡🟢) para urgência renderizam diferente em cada OS/browser.
- **Solução:** Usar ícones SVG/CSS consistentes.

### MED-10: SSO Login — action hardcoded
- **Localização:** `Saml.vue`
- **Descrição:** `action="/api/v1/auth/saml_login"` hardcoded no formulário.
- **Solução:** Usar rota relativa ou config.

### MED-11: Theme toggle — Inconsistência entre Login (Vue) e Super Admin (ERB)
- **Localização:** Login usa classes CSS (`i-lucide-sun/moon`), Super Admin usa SVG inline
- **Solução:** Padronizar abordagem.

### MED-12: CRM — `DEFAULT_STAGES` hardcoded no frontend
- **Localização:** `CrmIndex.vue`, linhas 17-24
- **Descrição:** Estágios padrão do pipeline são definidos no frontend. Se o backend criar com nomes diferentes, ficam inconsistentes.
- **Solução:** Sempre carregar do backend; usar defaults apenas como fallback visual.

---

## 🟢 BAIXOS (Melhorias e boas práticas)

### LOW-01: Score Badge — Thresholds hardcoded
- **Localização:** `CRMScoreBadge.vue`, linhas 26-30
- **Descrição:** Thresholds (80, 60, 40) hardcoded. Deveriam vir do backend.
- **Solução:** Buscar da API `ScoringConfig`.

### LOW-02: Google Fonts CDN
- **Localização:** `Index.vue`, `Saml.vue`, `new.html.erb`
- **Descrição:** Inter e Outfit carregadas de CDN externo.
- **Solução:** Self-host para performance e privacidade.

### LOW-03: CRMSidebarCard.vue — 24KB, muito extenso
- **Localização:** `dashboard/components/crm/CRMSidebarCard.vue`
- **Solução:** Dividir em sub-componentes.

### LOW-04: Agenda.vue — 88KB, arquivo extremamente grande
- **Localização:** `dashboard/routes/dashboard/crm/pages/Agenda.vue`
- **Solução:** Dividir lógica em composables e sub-componentes.

### LOW-05: Vite build time — 318 segundos (5+ minutos)
- **Localização:** `core-vite` container
- **Descrição:** Build completo leva 318148ms (~5.3 minutos). Excessivo para desenvolvimento.
- **Solução:** Configurar excludes, otimizar deps, considerar esbuild para pre-bundling.

### LOW-06: `completeActivity` no CrmIndex usa campo camelCase mas API espera snake_case
- **Localização:** `CrmIndex.vue`, linha 842
- **Descrição:**
  ```js
  await CrmAPI.updateActivity(activity.id, {
    completedAt: new Date().toISOString(),
  });
  ```
  A API Rails provavelmente espera `completed_at` (snake_case), não `completedAt`.
- **Solução:** Verificar se há normalização no backend ou corrigir para `completed_at`.

---

## 📊 Saúde dos Microserviços

```
Core Health:      {"status":"woot"}           ✅
CRM Service:      {"status":"ok"}             ✅
Orchestrator:     {"status":"ok","version":"1.0.0"} ✅
Identity Bridge:  {"status":"ok"}             ✅
```

---

## 🔧 Recomendação de Prioridade de Correção

### Sprint 1 — Infraestrutura (1-2 dias)
1. **CRIT-01** → Volume mounts para código Ruby no Docker
2. **CRIT-02** → Corrigir variáveis Redis/Postgres no branding
3. **CRIT-03** → Resolver migrations "NO FILE"
4. **MED-02** → Sidekiq RAILS_ENV

### Sprint 2 — Performance (1-2 dias)
5. **CRIT-05** → Code-splitting e tree-shaking do Vite build
6. **LOW-05** → Otimizar build time

### Sprint 3 — Qualidade de Código (3-5 dias)
7. **CRIT-04** → Internacionalização CRM (incremental)
8. **MED-05** → Renomear `filterÁrea`
9. **MED-07** → Refatorar CrmIndex.vue em composables
10. **MED-06** → Substituir `window.confirm/alert`
11. **MED-01** → Deprecation warnings Rails

### Sprint 4 — Polish (2-3 dias)
12. **MED-03** → Migrar Login Index.vue para Composition API
13. **MED-04** → Refatorar `accountIdFromRoute()`
14. **LOW-01 a LOW-06** → Melhorias gerais

---

## 📝 Comandos Úteis

```bash
# Copiar alterações para o container (enquanto volumes não estão configurados)
docker cp core/app/views/ chusterm-core-1:/app/app/views/
docker cp core/app/controllers/ chusterm-core-1:/app/app/controllers/
docker restart chusterm-core-1

# Verificar saúde de todos os serviços
docker exec chusterm-core-1 wget -qO- http://127.0.0.1:3000/health
docker exec chusterm-crm-service-1 wget -qO- http://127.0.0.1:4000/health
docker exec chusterm-orchestrator-1 wget -qO- http://127.0.0.1:4001/health
docker exec chusterm-identity-bridge-1 wget -qO- http://127.0.0.1:4002/health

# Verificar migrations
docker exec chusterm-core-1 sh -c "RAILS_ENV=production bundle exec rails db:migrate:status | tail -20"

# Verificar logs do Vite
docker logs chusterm-core-vite-1 --tail 30

# Rebuild completo do core
docker compose build core && docker compose up -d core sidekiq
```

---

*Relatório gerado por auditoria automatizada do sistema ChusteRM — 2026-05-08*
