# Changelog do Projeto — Reformulação do CRM

Memória executável do programa. Uma entrada por card/fechamento, com evidência.
(O prompt pedia `docs/CHANGELOG-PROJETO.md`; `docs/*` é ignorado no .gitignore,
então o arquivo vive em `docs/execution/` como os demais entregáveis.)

## 2026-07 — Sessão de diagnóstico + primeiros cards

### Documentação do programa (fases 0–3)

- `00-DIAGNOSTICO.md` — arquitetura real, inventário de rotas/telas, débito
  técnico com evidência, mapa de risco de merge com upstream v4.17.1,
  reconciliação dos audits históricos (achados já corrigidos não reaparecem
  como bugs atuais) e as 10 dores ordenadas por impacto.
- `00-BASELINE-METRICAS.md` — bundle Vite (~53,7 MB; `DashboardIcon` ~11 MB),
  latência dos endpoints medida via curl, contagens de rotas/specs, runtime.
- `01-BENCHMARK.md` — matriz temos/não-temos, top-25 RICE, 5 padrões de UX a
  adotar, vereditos das candidatas do prompt.
- `02-KANBAN.md` + `kanban.json` — board com 40+ cards, RICE, dependências e
  roadmap em 4 ondas.
- `03-DESIGN-SYSTEM.md` — estado real do Obsidian + Mineral (tokens `--ds-*` +
  `operationalTokens`), gaps de aplicação e regras de uso.

### Cards executados

- **CRM-001 (P1, E1)** — `Crm::DealOwnerAssigner` unifica os três caminhos de
  atribuição de dono (roteador, bulk action, automação de estágio) com flags
  explícitas `sync_assignee`/`sync_contact`. A ação em lote passa a auditar a
  mudança de dono do contato via `assign_crm_owner!` e o payload do evento
  `deal_owner_assigned` deixa de referenciar variável inexistente.
  Evidência: `rspec spec/controllers/api/v1/accounts/crm/deals_controller_spec.rb
  spec/services/crm/stage_automation_spec.rb spec/services/crm/deal_owner_assigner_spec.rb`
  → 54 exemplos, 0 falhas; rubocop 6 arquivos sem ofensas.
  Rollback: revert do commit `752c11b`; call sites voltam ao inline.
- **CRM-020 (P0, E3)** — spec de invariante cross-account
  (`spec/controllers/api/v1/accounts/crm/tenancy_spec.rb`): não-membro da
  conta da URL → 401; membro acessando id estrangeiro → 404 sem mutação,
  inclusive bulk_action com id estrangeiro; audit-events admin-only e sem
  vazamento entre contas. Evidência: 8 exemplos, 0 falhas.
  Rollback: n/a (só spec).
