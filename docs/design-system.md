# ChusteRM Design System

Documento de referência para o design system unificado do ChusteRM. Atualizar
sempre que tokens forem adicionados, renomeados ou aposentados.

## Princípios

1. **Uma só fonte de verdade.** Componentes novos consomem somente a camada
   semântica `--ds-*` (CSS) ou `ds.*` (Tailwind). Escalas Radix continuam
   existindo, mas só como base — nunca devem ser referenciadas direto em
   componentes de produto.
2. **Aliases, não duplicação.** Tokens semânticos apontam para escalas Radix
   via `var(--slate-12)` etc. Mudar a escala = sistema inteiro acompanha.
3. **Dark e light em paridade.** Todo token semântico tem valor em `:root`
   (light) e `.dark` (dark). Componentes não precisam pensar em tema.
4. **Adoção forçada.** Componente que reinventa `<select>`, `<button>` ou
   cores hardcoded é bug de DS, não estilo válido.

## Arquivos

| Arquivo | Papel |
|---|---|
| [`scss/_next-colors.scss`](../core/app/javascript/dashboard/assets/scss/_next-colors.scss) | Escalas Radix (12 steps por cor), light + dark. **Não consumir direto.** |
| [`scss/_design-tokens.scss`](../core/app/javascript/dashboard/assets/scss/_design-tokens.scss) | Camada semântica `--ds-*`. **Esta é a API pública.** |
| [`theme/colors.js`](../core/theme/colors.js) | Aliases Tailwind. Bloco `ds:` no final expõe os tokens semânticos como classes utilitárias. |
| [`css/chusterm-theme.css`](../core/app/javascript/dashboard/assets/css/chusterm-theme.css) | Camada paliativa (legado). Em aposentadoria — cada classe `*-shell` some à medida que a rota correspondente migra para tokens. |

## Tokens disponíveis

### Cores (Tailwind: `bg-ds-*`, `text-ds-*`, `border-ds-*`)

**Superfícies**
- `ds.bg.canvas` — fundo geral da app
- `ds.bg.surface` — cards, painéis principais
- `ds.bg.elevated` — popovers, modais, dropdowns
- `ds.bg.sunken` — áreas recuadas (inputs, code blocks)
- `ds.bg.hover`, `ds.bg.active` — estados interativos

**Texto**
- `ds.fg.default` — texto principal
- `ds.fg.muted` — texto secundário (subtítulos, labels)
- `ds.fg.subtle` — placeholder, hint
- `ds.fg.disabled`
- `ds.fg.on-accent` — texto sobre fundo accent (sempre branco)

**Bordas**
- `ds.border.subtle` — divisor leve, lista
- `ds.border` (DEFAULT) — borda padrão de input, card
- `ds.border.strong` — borda em hover
- `ds.border.focus` — borda em foco (= accent)

**Marca**
- `ds.accent` (DEFAULT) — primária roxa (`iris-9`)
- `ds.accent.hover`, `ds.accent.active`, `ds.accent.soft`
- `ds.accent.secondary` — teal
- `ds.accent.secondary-hover`, `ds.accent.secondary-soft`

**Estados**
- `ds.state.success` / `success-soft` — teal
- `ds.state.warning` / `warning-soft` — amber
- `ds.state.danger` / `danger-soft` — ruby
- `ds.state.info` / `info-soft` — blue

### Tipografia (CSS vars)

- Família: `--ds-font-sans` (Inter), `--ds-font-mono`
- Escala: `--ds-text-xs` (12) → `--ds-text-3xl` (30)
- Pesos: `--ds-weight-regular/medium/semibold/bold`
- Line-height: `--ds-leading-tight/snug/normal/relaxed`

### Espaçamento (CSS vars)

`--ds-space-0` ... `--ds-space-16` (base 4px). Use as utilities Tailwind
nativas (`p-4`, `gap-6`) — elas seguem a mesma escala.

### Raio, sombra, motion, z-index

- `--ds-radius-xs/sm/md/lg/xl/pill`
- `--ds-shadow-xs/sm/md/lg/xl` (com versão dark mais densa)
- `--ds-duration-fast/base/slow` + `--ds-easing-standard/emphasized`
- `--ds-z-base/sticky/overlay/modal/popover/toast`

## Como migrar uma tela

1. **Trocar `<select>` cru pelo `<Select>` da `components-next/select/`.**
   Use prop `block` para form full-width. Vide
   [`AssistantLlmSettingsForm.vue`](../core/app/javascript/dashboard/components-next/captain/pageComponents/assistant/settings/AssistantLlmSettingsForm.vue)
   como referência.
2. **Trocar cores hardcoded** (`bg-n-alpha-black2`, `#df8eff`, etc.) pelas
   classes `bg-ds-*` / `text-ds-*` / `border-ds-*`.
3. **Aposentar classes paliativas** do `chusterm-theme.css` (qualquer
   `*-shell` que a página usa) à medida que o componente é refeito com
   tokens.
4. **Padronizar listas** usando linha sem sombra individual e divisor
   `border-ds-subtle` em vez de cards isolados.

## Primitivos disponíveis

### Button
[`components-next/button/Button.vue`](../core/app/javascript/dashboard/components-next/button/Button.vue)

- **Default color:** `primary` (marca, usa `--ds-accent-*`).
- **Variantes:** `solid` (default), `faded`, `outline`, `link`, `ghost`.
- **Cores:** `primary`, `tertiary` (teal), `slate`, `blue`, `ruby`, `amber`, `teal`.
  As variantes `primary`/`tertiary` consomem tokens `--ds-*` e seguem a marca
  automaticamente em light/dark. As demais permanecem para compatibilidade
  com usos legados.
- **Sizes:** `xs`, `sm`, `md` (default), `lg`.
- **Boolean attrs:** `solid`, `outline`, `faded`, `link`, `ghost` (variantes);
  `xs/sm/md/lg` (sizes); `start/center/end` (justify); cores como booleans.

```vue
<Button label="Salvar" />                       <!-- primary solid md -->
<Button label="Cancelar" outline slate sm />
<Button icon="i-lucide-trash-2" ghost ruby />
```

### Badge
[`components-next/badge/Badge.vue`](../core/app/javascript/dashboard/components-next/badge/Badge.vue)

Tag/chip com variantes semânticas. Use para status ("Verificado"), papéis
("Administrador"), categorias ou contadores.

- **Variantes:** `neutral` (default), `accent`, `info`, `success`, `warning`,
  `danger`. Cada uma com versão `soft` (default) ou `outline` via prop
  `outline`.
- **Sizes:** `sm`, `md` (default).
- **Ícone:** prop `icon` (Lucide/Woot) ou slot `#icon`.

```vue
<Badge label="Administrador" variant="neutral" size="sm" />
<Badge label="Verificado" variant="success" icon="i-lucide-badge-check" />
<Badge label="Pendente" variant="warning" icon="i-lucide-clock" outline />
```

### Select
[`components-next/select/Select.vue`](../core/app/javascript/dashboard/components-next/select/Select.vue)

Substitui `<select>` nativo (regra ESLint força adoção em `components-next/`).

- **Props:** `options` (`[{value, label, disabled?}]`), `groups`,
  `placeholder`, `disabled`, `error`, `block` (full-width em forms).
- v-model com `String | Number | Boolean`.

```vue
<Select v-model="state.provider" :options="providerOptions" block />
```

### Card
[`components-next/card/Card.vue`](../core/app/javascript/dashboard/components-next/card/Card.vue)

Container genérico. Use sempre que a UI precisar de um "bloco" agrupador.

- **Variantes:** `flat`, `outlined` (default), `elevated`.
- **Padding:** `none`, `sm`, `md` (default), `lg`.
- **Interactive:** quando `true`, vira `role="button"` com `tabindex=0`,
  hover e foco visível, e responde a Enter/Space (emite `@click`).

```vue
<Card variant="outlined" padding="lg">…</Card>
<Card interactive @click="open">…</Card>
```

### ListRow + ListGroup
[`components-next/list/ListRow.vue`](../core/app/javascript/dashboard/components-next/list/ListRow.vue) ·
[`components-next/list/ListGroup.vue`](../core/app/javascript/dashboard/components-next/list/ListGroup.vue)

Padroniza listas — substitui o anti-padrão "card flutuante por linha".
`ListGroup` cria o container com borda + divisores. `ListRow` é a linha
com slots `leading`, `title`, `meta`, `description`, `trailing`.

- **Density:** `compact`, `comfortable` (default), `spacious`.
- **Interactive:** mesma a11y do Card.

```vue
<ListGroup>
  <ListRow v-for="item in items" :key="item.id">
    <template #leading><Avatar :src="item.avatar" /></template>
    <template #title>{{ item.name }}</template>
    <template #meta>{{ item.email }}</template>
    <template #trailing>
      <Button icon="i-lucide-pencil" ghost slate sm />
    </template>
  </ListRow>
</ListGroup>
```

### EmptyState
[`components-next/empty-state/EmptyState.vue`](../core/app/javascript/dashboard/components-next/empty-state/EmptyState.vue)

Estado vazio padronizado — substitui as 5+ variações espalhadas em
`Campaigns/EmptyState`, `Contacts/EmptyState`, `HelpCenter/EmptyState`.

- **Props:** `icon`, `title`, `description`. Slot `actions` para CTA.

```vue
<EmptyState
  icon="i-lucide-inbox"
  title="Nenhuma conversa ainda"
  description="Suas conversas aparecem aqui assim que chegarem."
>
  <template #actions>
    <Button label="Configurar inbox" />
  </template>
</EmptyState>
```

### PageHeader
[`components-next/page-header/PageHeader.vue`](../core/app/javascript/dashboard/components-next/page-header/PageHeader.vue)

Cabeçalho de rota com título + descrição + ações. Use no topo de cada
página para uniformidade.

```vue
<PageHeader
  title="Agentes"
  description="Gerencie quem tem acesso à sua conta."
>
  <template #actions>
    <Button label="Adicionar agente" />
  </template>
</PageHeader>
```

### FormField
[`components-next/form-field/FormField.vue`](../core/app/javascript/dashboard/components-next/form-field/FormField.vue)

Wrapper de campo de formulário com label, helper, error e a11y completa
(`aria-describedby`, `role="alert"` no erro, `*` para required).
O slot recebe `id`, `describedBy`, `invalid` para amarrar no input.

```vue
<FormField label="E-mail" required :error="errors.email">
  <template #default="{ id, describedBy, invalid }">
    <Input
      :id="id"
      v-model="state.email"
      :aria-describedby="describedBy"
      :aria-invalid="invalid"
    />
  </template>
</FormField>
```

## Regras ESLint ativas

`.eslintrc.js` aplica em `app/javascript/dashboard/components-next/**`:

| Regra | Efeito |
|---|---|
| `vue/no-restricted-syntax` `VElement[rawName="select"]` | Bloqueia `<select>` cru. |
| `vue/no-restricted-syntax` `VElement[rawName="textarea"]` | Bloqueia `<textarea>` cru. |

Exceções (componentes que encapsulam o elemento nativo): `select/`,
`selectmenu/`, `input/`, `textarea/`, `button/`, `inline-input/`,
`phonenumberinput/`, `taginput/`, `combobox/`, `Editor/`, `copilot/`,
e `*.story.vue`.

## Auditoria de adoção

Script automatizado em [`scripts/audit-design-system.mjs`](../scripts/audit-design-system.mjs):

```bash
node scripts/audit-design-system.mjs            # relatório legível
node scripts/audit-design-system.mjs --json     # saída JSON
```

Lista arquivos `.vue` com `<select>` ou `<textarea>` nativos fora dos
primitivos. Use para acompanhar a redução do número ao longo das migrações.

**Baseline (após Fase 4):** 39 selects + 12 textareas em 28 arquivos.

## Roadmap

- **Fase 0:** ✅ tokens semânticos + vitrine (form Captain LLM).
- **Fase 1:** ✅ Button refatorado, Badge novo, regra ESLint barrando
  `<select>`/`<textarea>` crus, vitrine na lista de Agentes.
- **Fase 2:** ✅ primitivos `Card`, `ListRow`, `ListGroup`, `EmptyState`,
  `PageHeader` (todos com a11y — focus-visible, role/tabindex quando
  interativos, keyboard handlers).
- **Fase 3:** ✅ padrão `FormField` com label/helper/error/aria-describedby.
  DataTable, Kanban, MetricCard ficam para Fase 4 quando rotas migrarem.
- **Fase 4:** ✅ tela de **Login** migrada (cores e fonte para tokens DS,
  layout intacto), ✅ lista de **Inboxes** migrada, ✅ lista de **Agentes**
  migrada (Fase 1). Pendente: Settings restantes, Reports, CRM pages,
  Conversation, Captain. **Contatos por último** (alinhado com backend em
  andamento).
- **Fase 5:** ✅ script de auditoria contínuo + a11y nos primitivos novos.
  Pendentes: codemod automatizado para os 39 selects restantes (mapear
  `<select>` cru → `<Select>` via AST), audit WCAG AA das rotas migradas
  com axe-core.
