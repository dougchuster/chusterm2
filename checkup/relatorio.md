# Check-up de páginas — Relatório final

**Data:** 2026-09-18 · **Branch:** `chore/checkup-paginas` (a partir de `refactor/crm-deal-owner-assigner` @ `c038738a69`) · **Ambiente:** stack local `docker compose` (imagem `core` rebuildada 4× durante o check-up, porta **3010**), fixture QA `Qa::CanonicalFixture` namespace `f0` (conta A = 55, conta B = 56)

Arquivos: [`inventario.md`](inventario.md) (status por rota) · [`log.md`](log.md) (correções com causa raiz e evidência) · `probe/` (ferramentas e resultados brutos, `probe/results/final/` = regressão final)

---

## 1. Resumo executivo

Foram inventariadas **237 rotas** (6 de autenticação, 204 do dashboard Vue, 27 do Super Admin) e todas passaram pelo checklist A–H com evidência automatizada (Playwright: console, rede, overflow em 360/768/1440, axe WCAG AA, tempo de carga; matriz de 7 perfis + anônimo + outro tenant) e, nos módulos CRM, Contatos, Empresas, Settings, Portais e Super Admin, por **CRUD de ponta a ponta** (192 checks de API com verificação de persistência) e checks de formulário na UI.

**Status final:** 168 `OK` · 69 `BLOQUEADO` · 0 `FALHOU` · 0 `PENDENTE`.

Os 69 `BLOQUEADO` **não são 69 defeitos**: são páginas em que o único item aberto é um dos dois bloqueios sistêmicos (§4.1): contraste dos tokens de cor do design system (40 páginas) e acessibilidade de componentes herdados do Chatwoot (54 páginas; 25 em ambos). Todo o resto do checklist passou nelas.

**19 commits** de correção (46 arquivos, +774/−47), cada um com spec (RSpec ou Vitest) e verificado no runtime após rebuild. Nenhum design ou regra de negócio foi alterado sem registro; o que exige decisão sua está em §4.

### Os 8 achados que mais importam

| # | Sev. | Onde | O que era | Estado |
|---|---|---|---|---|
| 1 | **CRÍTICO** | deploy · `db/migrate/20260918000001` | `db:migrate` **abortava** (`ForeignKeyViolation`) porque `crm_deals.conversation_id` não tem FK e existem negócios apontando para conversas apagadas; cancelava mais 3 migrations | Corrigido (`29a874d9c7`). **Antes de deployar nas VPS**, rodar a query de contagem de órfãos que está no `log.md` |
| 2 | **ALTO** | `…/crm` (board) | Arrastar card para a coluna **Ganho/Perdido deixava o negócio `open`** — fora de toda métrica de fechamento | Corrigido (`1408d98492`), 4 specs |
| 3 | **ALTO** | `…/crm/settings/loss-reasons` | **Não dava para criar motivo de perda pela UI** (422 `Slug can't be blank`) | Corrigido (`abc8dc87cb`) |
| 4 | **ALTO** | `…/search` | Busca global com apóstrofo/operador (`d'água`, `O'Brien`) → **500** | Corrigido (`663f834cd0`) |
| 5 | **ALTO** | sistema · `features.yml` | Flags nº 64/65 (`conversation_required_attributes`, `advanced_assignment`) **não podem ser ligadas em nenhuma conta** (bigint de 63 bits); rotas `assignment-policy/capacity/*` estão mortas em produção | **Decisão sua** (§4.2) |
| 6 | **ALTO** | `…/settings/integrations/webhook`, inbox API | Webhook aceita `http://localhost`/IP interno (**SSRF**, herdado do Chatwoot) | **Decisão sua** (§4.2) |
| 7 | MÉDIO | todas as páginas com formulário | Erros de validação do servidor chegavam **em inglês** ("Validation failed: Title can't be blank") e o login inválido também | Corrigido (`13f7477832`, `28dce7a11e`) |
| 8 | MÉDIO | 7 páginas | Agente abria páginas cujo backend é admin-only (Captain config/score/cenários, Histórico do negócio, edição de artigo, aba Atendimento & SLA) e recebia 401 silencioso ou tela vazia | Corrigido (5 commits) |

---

## 2. Método e evidência

| Fase | Ferramenta (`checkup/probe/`) | Cobre |
|---|---|---|
| Inventário | `router.getRoutes()` do router real via vitest descartável → `_routes_raw.json` | 204 rotas Vue com `meta.permissions`/`featureFlag` exatos; auth e Super Admin à mão |
| Varredura | `sweep.mjs` (Playwright, 4 workers) — 9 passadas: admin @1440 (+axe WCAG 2A/AA +screenshots), @360, @768; operator, seller, manager, knowledge_manager, admin_b (outro tenant), anônimo | A (status/console/rede), E (texto de vazio), F (matriz de perfis, tenant), G (overflow, axe), H (tempo, requisições repetidas) |
| Permissões | `perms.mjs`, `tenant.mjs` | rota × perfil × API; 20 endpoints cross-tenant + escrita + anônimo |
| Funcional | `crm-crud.mjs` (61), `core-crud.mjs` (100), `superadmin.mjs` (30), `auth.mjs` (70), `ui-crm.mjs` (16) | B, C, D: CRUD com GET de verificação, validação server-side, paginação/busca/filtro, mensagens pt-BR, confirmação de exclusão, formulários na UI |
| Estático | `static.mjs` | sinais por página: loading/empty/erro/confirm/validação/`console.log`/texto jurídico hardcoded |
| Fechamento | `finalize.mjs` | cruza a regressão final com bloqueios conhecidos → `inventario.md` |

Ambiente: a imagem `core` local estava **2 dias/15 commits atrás** do HEAD (e sem 5 migrations) — foi rebuildada antes de auditar; o `docker-compose.override.yml` (porta 8086) não existe mais, o `core` subiu na porta canônica 3010. Rebuild a cada lote de correções; tudo que está marcado como corrigido foi re-testado no runtime.

Regressão final (imagem com todas as correções): admin 204/204 rotas **0 falhas de rede, 0 erros de console, 0 overflow** em 1440 e 360; anônimo 204/204 → `/app/login`; outro tenant 0 respostas 2xx; RSpec das áreas tocadas **753/0**; Vitest completo **411 arquivos / 3.897 testes** verdes; ESLint 0 erros; RuboCop 0 ofensas nos arquivos alterados (as 11 restantes são pré-existentes em arquivos não tocados); build da imagem (Vite + bundle) OK.

---

## 3. Problemas por categoria

| Categoria do checklist | Encontrados | Corrigidos | Bloqueados/decisão | Observação |
|---|---|---|---|---|
| A. Carregamento e erros | 6 | 6 | — | 500s (busca, relatórios, portal, installation_configs*), 404 de logo, 404/429 do widget no Super Admin |
| B. Dados e API | 8 | 6 | 2 | dedupe de negócio por contato é regra (não bug); automação aceita `event_name` inválido (baixo) |
| C. CRUD | 3 | 2 | 1 | coluna terminal não fechava; motivo de perda não criava; cadência sem consentimento (D6, decisão) |
| D. Formulários | 8 | 7 | 1 | i18n de validação, nome vazio em segmento/macro/perfil/agent bot, `custom_domain` nulo; telefone sem máscara no drawer de negócio (baixo, não alterado) |
| E. Estados de UI | 1 | 1 | — | criar negócio sem feedback visível em coluna longa → toast |
| F. Permissões e segurança | 9 | 7 | 2 | 7 páginas admin-only abertas para agente; SSRF em webhooks e flags 64/65 (decisão). Tenant e anônimo: 0 falhas |
| G. Layout e acessibilidade | 4 + 2 sistêmicos | 4 | 2 sistêmicos | labels em auth/contatos, `img alt`; contraste de tokens e a11y upstream |
| H. Performance | 0 | — | — | 8 páginas passaram de 3s só com 4 navegadores em paralelo; isoladas ficam entre 1,4 e 2,2s. `cache_keys` disparado 4–8× por página é design do Chatwoot (recomendação em §6) |
| Deploy/dados | 3 | 2 + 1 dado | — | migration com órfãos; imagem defasada; `installation_configs.SETUP_DONE` inserido à mão em JSON (corrigido no banco local) |

\* `installation_configs` 500: causa era um **dado** inserido fora do Rails, não código — corrigido no banco local; verificar nas VPS (query no `log.md`).

---

## 4. Itens bloqueados

### 4.1 Sistêmicos (marcam 69 páginas como `BLOQUEADO`)

1. **Contraste AA (40 páginas)** — `text-n-slate-10/11` (#80838d) e `text-n-brand` (#2781f6) usados em texto ≤14px sobre branco dão 3,77–3,78:1 (mínimo 4,5:1). É um token do design system: trocar afeta o sistema inteiro. **Recomendação:** na Fase 4 (design system) criar `n-text-muted` ≥ 4,5:1 e restringir `n-brand` a ≥18px/bold ou botões. Não mexi porque é decisão de design.
2. **A11y de componentes herdados do Chatwoot (54 páginas)** — `button-name` (botões só com ícone sem `aria-label` no components-next/Captain), `label` (radios/checkbox de perfil, formulários de time e assignment), `select-name` (`select` sem label em perfil/geral/inbox), `role-img-alt` (gráficos dos relatórios), `nested-interactive` (perfil). Corrigi os casos em código do fork (auth, contatos/lista, integrações); os demais são upstream — corrigir junto com o sync do upstream 4.17 ou na Fase 4.

### 4.2 Decisões que só você pode tomar

| Item | Por que não corrigi | Opções |
|---|---|---|
| **SSRF em webhooks** (`settings/integrations/webhook`, inbox API `webhook_url`) — admin pode fazer o servidor chamar `http://localhost`/rede interna | Mitigar direito exige resolver DNS na validação e bloquear faixas privadas (ou proxy de egress); afeta integrações legítimas em rede interna | (a) validador que rejeita loopback/privado/link-local resolvendo DNS; (b) allowlist de hosts por instalação; (c) aceitar o risco (deploy single-tenant em VPS própria) |
| **Flags 64/65 impossíveis** (`features.yml` tem 65 flags, `accounts.feature_flags` bigint aguenta 63) | Reordenar/remover flags remapeia bits de **todas** as contas — precisa migration de remapeamento | (a) remover flags obsoletas herdadas (`reply_mailer_migration`, `advanced_search_indexing`…) com migration que reescreve `feature_flags`; (b) mover flags do fork (`crm_*`, `marketing`, `companies`…) para uma coluna própria |
| **Cadência sem guard de consentimento** (D6 do PLANO_17_09) — `enroll_deal` aceita contato `opt_out` | Regra de negócio (LGPD + Provimento 205) | implementar no `Crm::Cadences` como o plano prevê |
| **Feature flag não aplicada pelo router** — URL direta de módulo desligado (ex.: `/marketing`) renderiza a página e mostra "erro de conexão" | Guard no router precisa das features da conta antes do `beforeEach`; sidebar já esconde | (a) redirecionar no `validateActiveAccountRoutes` quando `meta.featureFlag` estiver off (carregando a conta antes); (b) estado "módulo não habilitado" nas páginas |
| **Módulos por conta** — `marketing`, `crm_universal`, `custom_roles`, `saml` estavam desligados na conta QA (liguei para auditar) | Configuração, não bug | decidir quais ficam ligados por padrão nas VPS |

### 4.3 Baixa prioridade, não alterado

- API aceita `event_name` fora da lista da UI em automações (lista de eventos vive só no front).
- API aceita mensagem privada com `content` vazio e sem anexo (UI bloqueia).
- Drawer "Novo negócio": telefone sem máscara/validação client-side (o servidor valida E.164 e devolve pt-BR).
- `A4 /app/auth/confirmation` com token inválido volta ao login sem avisar "link expirado" (upstream).
- `CRMBoard` a 360px: card clipado na coluna (kanban rola horizontalmente; a visão em lista existe).
- `deals_controller.rb` tem 962 linhas (>800) — refatoração fora do escopo do check-up.

---

## 5. Regressão final nas páginas críticas

Imagem com todos os 19 commits (rebuild #4): login/reset, dashboard (conversas), CRM (board, leads, negócio, relatórios, agenda, atividades), contatos, empresas e relatórios re-executados como admin e como agente — 0 falhas de rede, 0 erros de console, agente em `crm/reports` sem 401 (a última pendência, `…/crm/analytics`, confirmada no runtime).

---

## 6. Recomendações priorizadas

1. **Antes do próximo deploy** (30 min): rodar nas duas VPS as duas queries do `log.md` (órfãos de `crm_deals.conversation_id`; `installation_configs` com `jsonb_typeof <> 'string'`). Se houver órfãos, a migration corrigida já lida com eles; a segunda evita o 500 no Super Admin.
2. **Decidir SSRF** (§4.2) — se (a), é ~1 dia com spec; vale também para `Channel::Api#webhook_url` e `AgentBot#outgoing_url`.
3. **Resolver as flags 64/65** antes de adicionar qualquer flag nova ao `features.yml`.
4. **Implementar D6** (consentimento na cadência) — já está no PLANO_17_09; é o item de compliance mais barato que está aberto.
5. **Fase 4 (design system):** tokens de texto com contraste AA e `aria-label` nos botões-ícone do components-next — zera os 69 `BLOQUEADO` de uma vez.
6. **Performance:** deduplicar `GET /cache_keys` no `CacheEnabledApiClient` (uma promessa compartilhada por tick) — hoje cada página dispara 4–8 chamadas idênticas; ganho fácil no INP das páginas de settings/relatórios.
7. **Processo:** manter `checkup/probe/run-final.sh` como smoke de regressão pós-deploy (roda em ~12 min contra o stack local); as personas da fixture já cobrem admin/agente/custom role/outro tenant/anônimo.
8. **Universal CRM (A0 do plano):** a análise estática achou texto jurídico hardcoded em 14 páginas (`ContactCategoriesPage` "Setor jurídico", labels em `contacts/segments`, `crm/checklist-templates`, `crm/reports`, `crm/deals/:id`…) — lista em `probe/results/static.json` (`hardcodedJuridico`). Não alterei: é o item 2.4 do PLANO_17_09.

---

## 7. Como reproduzir

```bash
# stack local (porta 3010) + fixture
export QA_FIXTURE_PASSWORD='<senha local ≥12>' QA_BASE_URL=http://127.0.0.1:3010
docker compose exec -T -e QA_FIXTURE_PASSWORD=$QA_FIXTURE_PASSWORD -e QA_FIXTURE_NAMESPACE=f0 -e QA_FIXTURE_TARGET=local-compose core bundle exec rake qa:seed
(cd qa/e2e && pnpm exec playwright test --project=auth-setup)   # sessões em qa/e2e/playwright/.auth

# regressão completa (~12 min) → checkup/probe/results/final/
cd checkup/probe && sh run-final.sh && node finalize.mjs
```

Os registros criados pelos probes usam prefixo `QA_` e são removidos ao fim de cada script; a fixture `f0` é idempotente.
