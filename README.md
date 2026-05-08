# ChusteRM

CRM conversacional omnichannel com orquestração de agentes de IA, construído sobre o fork do **Chatwoot Community Edition**.

---

## Visão geral

O **ChusteRM** é um produto white-label focado em captação, qualificação e conversão de leads via atendimento omnichannel. Ele combina:

- **Atendimento omnichannel** (WhatsApp, Instagram, Messenger, webchat) via Chatwoot CE forkado;
- **CRM conversacional nativo** com pipeline Kanban, scoring, atividades e relatórios de funil;
- **Agentes de IA** com skills especializadas para triagem, qualificação, agendamento e FAQ;
- **Autenticação unificada** via sistema principal (sem signup público).

---

## Documentação técnica

| Arquivo | Conteúdo |
| :--- | :--- |
| [docs/ChusteRM_blueprint.md](docs/ChusteRM_blueprint.md) | Blueprint completo do projeto |
| [docs/DESIGN_Modelo.md](docs/DESIGN_Modelo.md) | Design system — Obsidian Kinetic Ultra Refined |
| [docs/01-product-scope.md](docs/01-product-scope.md) | Escopo funcional detalhado |
| [docs/02-system-architecture.md](docs/02-system-architecture.md) | Arquitetura por serviço, filas e integrações |
| [docs/03-data-model.md](docs/03-data-model.md) | Modelo de dados do CRM e skills |
| [docs/04-auth-sso-flow.md](docs/04-auth-sso-flow.md) | Fluxo de autenticação unificada |
| [docs/05-agent-skills-catalog.md](docs/05-agent-skills-catalog.md) | Catálogo formal de skills de IA |
| [docs/06-ui-rebrand-checklist.md](docs/06-ui-rebrand-checklist.md) | Checklist de rebrand do fork |
| [docs/07-security-hardening.md](docs/07-security-hardening.md) | Controles de segurança e rollout |
| [docs/08-skills-management-ui.md](docs/08-skills-management-ui.md) | Gerenciamento visual de skills de IA |
| [docs/08-skills-management-ui.md](docs/08-skills-management-ui.md) | Gerenciamento visual de skills de IA |

---

## Stack tecnológica

### Core (fork do Chatwoot CE)
- Ruby on Rails
- Vue.js
- PostgreSQL
- Redis + Sidekiq
- Active Storage

### Serviços adicionais
- **CRM / Orchestrator API:** Node.js + Fastify + TypeScript + BullMQ
- **IA / Skills:** Node.js + TypeScript + BullMQ + OpenRouter (qwen/qwen3-coder-plus)
- **Frontend comercial:** Next.js + TypeScript

---

## Fases do projeto

| Fase | Nome | Status |
| :--- | :--- | :--- |
| 0 | Foundation & Audit | ✅ Concluído |
| 1 | White-label e autenticação | ✅ Concluído |
| 2 | CRM Foundation | ✅ Concluído |
| 3 | Agent Orchestrator e Skills v1 | ✅ Concluído |
| 4 | Agendamento, cadências e reativação | ✅ Parcial (scheduling + reactivation implementados) |
| 5 | Hardening, governança e analytics | ⬜ Pendente |

---

## Regras de licenciamento

- Base: **MIT Expat** (conteúdo fora de `enterprise/`)
- A pasta `enterprise/` **não deve ser usada** — recursos equivalentes serão implementados via clean-room
- Whitelabeling é realizado exclusivamente sobre o escopo licenciado livremente

---

## Design system

O produto segue o design system **Obsidian Kinetic — Ultra Refined** com os seguintes tokens principais:

| Token | Valor |
| :--- | :--- |
| Base background | `#0e0e12` |
| Primary Glow (Violeta) | `#df8eff` |
| Secondary Spark (Ciano) | `#00eefc` |
| Surface High | `#25252b` |
| On-Surface | `#f3eff6` |
| Fonte | Plus Jakarta Sans |
