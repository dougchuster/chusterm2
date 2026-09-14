# Fase 3 — Design System — ChusteRM (Obsidian + Mineral / Nocturnal Architect)

**Data:** 2026-09-14 · **Status:** sistema **já implementado** em grande parte — este documento registra o contrato real do código e o que falta.
**Fontes canônicas:** `.github/skills/chusterm-ui-redesign/references/design-brief.md` · `core/app/javascript/dashboard/assets/scss/_design-tokens.scss` · `core/app/javascript/dashboard/design-system/tokens.js` · `core/tailwind.config.js` · `docs/design/reformulacao-2026-09/PLANO.md`

## 3.1 Tokens (estado real)

**Cor — implementado como camada semântica única.** Dois temas irmãos nascem juntos:

| Papel | Claro (Mineral) | Escuro (Obsidian) |
|---|---|---|
| canvas | `#f5f7fc` | `#0c0c0e` |
| surface | `#fbfcff` | `#19191c` |
| elevated | `#ffffff` | `#222225` |
| sunken/nav | `#ebeff8` | `#111113` |
| hover | `#e6ebf5` | `#2b2b2f` |
| text default | `#18233b` | `#f4f4f5` |
| text muted | `#53627c` | `#a1a1aa` |
| accent | `#4f46e5` | `#e4e4e7` (pérola) |
| IA accent | `#c890ff` | `#c890ff` |
| success/warning/danger/info | teal/amber/ruby/blue Radix | pares explícitos |

Contrato: componentes novos consomem **apenas** `--ds-*` (SCSS) ou `ui.*` (Tailwind via `operationalTokens`) — nunca escala Radix direta nem hex. Cobertura: `bg-canvas/surface/elevated/sunken/hover/active`, `fg-default/muted/subtle/disabled/on-accent`, `border-subtle/default/strong/focus`, `accent`, `state-*`, `chart-*`.

**Espaçamento:** escala Tailwind padrão (grade 4px) — uso consistente; não há escala fechada customizada nem lint contra valor solto ainda (gap).
**Tipografia:** Manrope (`fontFamily.heading`) títulos + Inter (`sans`) corpo; labels caixa alta com tracking amplo. Números tabulares em tabelas/métricas — parcial (verificar `tabular-nums` nas grids).
**Raio/elevação:** `rounded-xl+` em cards; sombras amplas/difusas; `borderRadius` exportado de `operationalTokens`. Regra: **ou** borda 1px sutil **ou** mudança de superfície — nunca borda+sombra+fundo juntos.
**Movimento:** microtransições curtas; `prefers-reduced-motion` — verificar cobertura global (gap de auditoria).

## 3.2 Densidade e separação (o que o dono pediu, traduzido)

- Separação por **empilhamento tonal** (canvas→surface→elevated), não borda dura — implementado.
- Cabeçalho de seção: label pequena, caixa alta, tracking amplo, cor terciária — padrão em uso.
- Divisores em lista em vez de cards flutuantes — parcial.
- Painéis laterais colapsáveis/redimensionáveis persistidos — **não implementado** (card CRM-032).
- Toggle densidade compacta/confortável — **não implementado** (card CRM-031).
- Hierarquia por peso/cor antes de tamanho — princípio ativo do plano.

## 3.3 Estados obrigatórios

| Estado | Status |
|---|---|
| Carregando (skeleton) | parcial — existe em telas CRM novas; auditar as 161 rotas (CRM-033) |
| Vazio (CTA + texto que ensina) | parcial — corrigido o vazio redundante da conversa |
| Erro (mensagem humana + recuperação) | parcial |
| Sem permissão | existe via `usePolicy` — visual a auditar |
| Offline/reconectando | existe no shell upstream — revisar sob o tema |
| Conteúdo longo (truncate+tooltip) | parcial |

## 3.4 Telas prioritárias — estado

| Tela | Estado |
|---|---|
| Inbox 3 colunas + painel CRM à direita | redesenhada (fases 1-3 do master plan) — edição inline a expandir |
| Contato/Empresa 360º | `ContactsIndex.vue` (2.183 linhas) — funcional; split + timeline unificada pendente |
| Pipeline Kanban | redesenhado — filtros progressivos, nav móvel por etapa, ação "mover" sem arrastar; rotting/soma pendente (CRM-012) |
| Dashboard | bento grid aplicado; comparação temporal parcial |
| Configurações 2 níveis + busca | navegação existe; busca interna de settings **pendente** |
| Login / super login | mesma família visual ✅ (diferenciação por copy/contexto, não por paleta) |

## 3.5 Acessibilidade (evidência, não promessa)

- Axe critical/serious = **0** na rota CRM em 5 viewports (matriz `CRM-A11Y-01..05`, Playwright) ✅
- Teclado: `/` foca busca, `Escape` limpa, accordion móvel acessível ✅ (`CRM-KEYBOARD-01`)
- Contraste AA, foco visível, alvo ≥44px, cor não única portadora — cobertos no tema novo; auditoria ampla das demais rotas = **pendente** (CRM-025/033)

## Regra de lint a criar (gap)

Não existe ainda a regra que **proíbe** hex/px soltos fora dos tokens. Card a abrir na onda 2: `eslint` custom `no-hardcoded-color` para `app/javascript/**` (permitir em `theme/`, `_design-tokens.scss`, `tailwind.config.js`).

## Antes/depois

`docs/execution/03-ANTES-DEPOIS.md` — evidência já coletada em `docs/qa/RELATORIO_QA_FINAL_UIUX.md` e `qa/e2e/playwright-report` (sanitizar antes de publicar).
