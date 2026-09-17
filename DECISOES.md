# DECISOES.md — Registro de decisões arquiteturais (ADRs)

Referência: `PLANO_17_09.md` §3 (achados A0–A3). Data das decisões: 2026-09-17.

---

## ADR-A0 — Núcleo universal: `category`/`subcategory` + `crm_field_definitions`

**Status:** aceito · **Decisão:** adotar a recomendação do plano.

- `crm_deals.legal_area` → `category` (slug, indexada); `case_type` → `subcategory`.
- `conflict_check_status` e `documents_status` saem do schema → `custom_fields.pack.*` / itens de checklist do pack.
- `crm_pipelines.kind` → `template_slug` (default `sales_default`).
- `CrmActivity::KINDS` → tipos base universais + `crm_activity_types` por conta.
- Taxonomia, labels, pesos de score, playbooks, prompts e perguntas de intake vivem em **packs versionados** (`config/crm_packs/<slug>.yml` + `crm_account_packs`).
- Migração aditiva primeiro (colunas novas + backfill), remoção das antigas só após 2 releases. Flag `crm_universal` por conta durante a transição.
- `crm.coimbraeruas.com.br` migra para o pack `legal` — paridade total, zero perda de configuração.

**Alternativas rejeitadas:** custom fields puro (campos de 1º nível são usados em filtro/group_by/score — precisam de coluna indexada); custom objects completos (YAGNI até 3 packs em produção).

---

## ADR-A1 — IA única: orchestrator como cérebro, estado no Rails

**Status:** aceito · **Decisão:** caminho (c) + (b) parcial do plano.

- O **orchestrator** (Node/Fastify, MIT, já escrito, já multi-perfil) é o único motor de IA, acoplado via `AgentBot` webhook — mecanismo nativo do Chatwoot, sem fork.
- Clean-room parcial em `app/` apenas do estado que o Rails precisa (`captain_conversation_states`, handoff, tools de CRM auditadas).
- `enterprise/` deixa de ser carregado por `chatwoot_app.rb` na sequência (risco de licença eliminado); o que o fork usa é reimplementado ou movido para `app/`.
- O `agent profile registry` do orchestrator passa a carregar **perfil do pack** instalado na conta (`pack_slug` no assistente).

**Alternativas rejeitadas:** licença enterprise self-hosted (custo + lock-in); manter duas IAs (incoerência de persona — A3).

---

## ADR-A2 — WhatsApp: Evolution como provider + aviso + caminho oficial

**Status:** aceito.

- Evolution/Baileys permanece como **provider suportado** (o cliente atual depende dele), mas:
  - a tela de inbox exibe aviso "canal não-oficial — risco de banimento" onde o canal é Evolution;
  - o card do kanban sinaliza canal não-oficial (E6);
  - o caminho de migração para **Cloud API oficial** é documentado e chega com o sync upstream 4.17 (setup guiado + health + Templates Hub) — Fase 5.2.
- Nenhuma remoção de funcionalidade no cliente em produção.

**Alternativas rejeitadas:** migração forçada agora (quebraria o cliente em produção); silêncio sobre o risco (inaceitável operacional e juridicamente — OAB 205).

---

## ADR-A3 — Identidade da IA: `public_identity` + disclosure obrigatório

**Status:** aceito.

- `captain_assistants` ganha `public_identity` (`self | assistant_of | brand`) e `public_name`.
- Toda primeira mensagem da IA carrega disclosure ("Sou a assistente virtual da equipe X") — nunca "sou a Dra. Paula" (pessoa real).
- Spec que **falha** se o primeiro outbound da IA não contiver disclosure.
- Divergência VPS vs local eliminada: a identidade vem do perfil do pack/assistente, não de código.

---

## Gate da Fase 0

- [x] 4 ADRs registrados (este arquivo)
- [ ] Triagem com acentos + áudio (0.4)
- [ ] Métricas coerentes (0.5)
- [ ] Bugs visuais + copy jurídica fora do núcleo visível (0.6)
- [ ] Payload do serializer limpo (0.7)
- [ ] gitleaks + throttle (0.8)
- [ ] Repo limpo: serviços órfãos, .nvmrc, docs/execution versionados (0.9)
- [ ] RSpec + Vitest verdes; 0 termos jurídicos fora do pack em contas sem `legal`
