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
