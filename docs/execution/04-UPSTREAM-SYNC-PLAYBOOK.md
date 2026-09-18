# CRM-044 — Playbook: sync quinzenal com upstream Chatwoot

**Cadência:** quinzenal · **Base atual:** Chatwoot `v4.12.1` (`core/VERSION_CW`) · **Remote:** `upstream` = `https://github.com/chatwoot/chatwoot.git`

## Checklist executável

1. **Preparar**
   ```bash
   git fetch upstream --tags
   git tag -l 'v4.*' --sort=-v:refname | head -5   # descobrir última tag estável
   ```
2. **Dimensionar** — `git log --oneline v4.12.1..vX.Y.Z -- core/ | wc -l` e
   `git diff --stat v4.12.1..vX.Y.Z -- core/ | tail -1`. Registrar no
   changelog (commits + arquivos).
3. **Classificar o diff** por risco de merge:
   - **Arquivos Chatwoot puros** (inbox, contatos, relatórios): merge normal.
   - **Arquivos tocados pelo ChusteRM** (`crm/*`, `captain/*`, commandbar,
     design system, `routes.rb`, models com `has_many :crm_*`): merge manual
     com diff lado a lado.
   - **`enterprise/`**: manter compatibilidade — nunca editar OSS para
     comportamento Enterprise.
4. **Branch de sync** — `sync/upstream-vX.Y.Z` a partir de main.
5. **Aplicar** — preferir cherry-pick de patches de segurança primeiro;
   features grandes vão por merge de release inteira, nunca commit a commit.
6. **Pós-merge (obrigatório)**:
   - `bundle exec rspec spec/` (ao menos a suíte CRM: `spec/controllers/api/v1/accounts/crm/`)
   - `pnpm vitest run` nos composables/components CRM
   - `pnpm eslint` nos arquivos tocados pelo merge
   - `bundle exec rubocop` nos `.rb` tocados
   - `npx vite build` (confere chunk budget — ver baseline em
     `docs/execution/00-BASELINE-METRICAS.md`)
   - Sweep visual `qa/e2e/tests/visual-sweep.spec.ts` (rotas críticas)
   - Migration check: `bundle exec rails db:migrate:status`
7. **Rollback** — manter tag `pre-sync-v4.12.1` no commit anterior ao merge;
   documentar `git revert`/restore no changelog da sync.

## Regras de ouro

- Nunca mergear upstream direto em `main` sem a suíte CRM verde.
- Conflitos em `app/models/account.rb`, `config/routes.rb` e
  `app/javascript/dashboard/routes/**` são sempre manuais — esses arquivos
  têm customizações estruturais do ChusteRM.
- Cada sync atualiza `core/VERSION_CW` e registra baseline de bundle.
- Diffs de segurança (CVEs) têm prioridade sobre a cadência quinzenal.

## Evidência da última auditoria

Comparação v4.12.1 → v4.17.1: 756 commits, 4.365 arquivos
(`docs/audit/`). Próxima revisão deve repetir essa medição e atualizar o
mapa de risco de merge por arquivo.

## Análise de sobreposição real (5.1, medido por conteúdo)

**As histórias são disjuntas.** Nosso primeiro commit
(`7594e37d59`, "primeiro commit — ChusteRM CRM omnicanal") é um snapshot
do 4.12.1 — não há merge-base com `upstream/master` e `git merge` não
funciona (`--allow-unrelated-histories` marcaria cada arquivo como
adicionado dos dois lados). O sync é portanto uma operação **por árvore**,
com `v4.12.1` como base semântica virtual.

Medição de 2026 (blob-hash `v4.12.1:<path>` vs `HEAD:core/<path>`):

| Lado | Arquivos |
|---|---|
| Nós modificamos vs 4.12.1 | 2.154 |
| Nós adicionamos (CRM/Marketing/Evolution/Captain) | 709 |
| Upstream tocou 4.12.1 → 4.17.1 | 4.365 |
| **Sobreposição (conflito provável)** | **1.187** |
| Upstream apagou e nós tocamos | 18 |
| Clean take (só upstream tocou) | ~3.160 |

Hotspots de conflito: `config/locales` (~60 yml), `app/javascript`
(~700), `enterprise/app` (Captain), `app/models` (account, contact,
conversation, inbox, message, user), `app/services/whatsapp`,
`app/controllers`, `app/views` (jbuilders). Clean take concentra-se em
`app/javascript` de features novas, `db/migrate` upstream, e specs.

## Estratégia recomendada (corrige o passo 5)

Como não há merge-base, o sync v4.12.1 → v4.17.x se faz em duas classes:

1. **Clean take (~3.160 arquivos)** — aplicar o diff upstream por atacado:
   ```bash
   git diff v4.12.1 v4.17.1 -- <paths> | git apply --directory=core
   ```
   Inclui migrations upstream inteiras — os stubs `legacy_upstream_stub*`
   que criamos em `db/migrate/` devem ser substituídos pelas migrations
   reais na mesma versão-timestamp.
2. **Sobreposição (1.187 arquivos)** — merge manual por arquivo com
   three-way real: `git merge-file ours core/base(v4.12.1) theirs(v4.17.1)`.
   Priorizar nesta ordem: `config/routes.rb`, `app/models/{account,contact,
   conversation,inbox,message}.rb`, `config/locales/*` (mecânico),
   `enterprise/app` Captain, WhatsApp services.
3. **Features upstream nomeadas no plano** (Templates Hub, wizard
   WhatsApp guiado + health, macros `#`, relatórios clicáveis, SLA
   comercial, automações com delay upstream, Rails 7.2.3) — avaliar por
   cherry-pick de release inteira depois do sync estrutural, não antes.

Execução estimada em sprint dedicado — fora do escopo de uma sessão de
implementação contínua. Não executar merge cego: quebraria
`crm.coimbraeruas.com.br`.
