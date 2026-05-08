# 🐛 ChusteRM — Bug Tracking & System Checkup

> **Gerado em:** 2026-05-01
> **Auditor:** Engenheiro de Software Sênior / QA Lead
> **Escopo:** Módulo CRM (Frontend Vue 3 + Backend Rails 7)

---

## Índice

- [Resumo Executivo](#resumo-executivo)
- [🔴 Bugs Críticos](#-bugs-críticos)
- [🟠 Bugs Importantes](#-bugs-importantes)
- [🟡 Bugs Moderados](#-bugs-moderados)
- [🟢 Melhorias / Code Smells](#-melhorias--code-smells)
- [Histórico de Correções](#histórico-de-correções)

---

## Resumo Executivo

| Severidade | Contagem | Status |
|:---:|:---:|:---:|
| 🔴 Crítico | 5 | Pendente |
| 🟠 Importante | 6 | Pendente |
| 🟡 Moderado | 7 | Pendente |
| 🟢 Code Smell | 5 | Pendente |
| **Total** | **23** | — |

---

## 🔴 Bugs Críticos

### BUG-001: Rota `export` de deals inexistente no `routes.rb`

- **Arquivo:** `config/routes.rb` (linha 114-121) + `app/controllers/api/v1/accounts/crm/deals_controller.rb` (linha 98)
- **Problema:** O controller `DealsController` define a action `export` (linha 98) e o frontend `CRMExportButton.vue` chama `CrmAPI.exportDeals()` que faz POST para `deals/export`. Porém, **não existe rota** correspondente no `routes.rb`. A definição de `resources :deals` só inclui `:index, :show, :create, :update, :destroy` com `member` routes para `move`, `mark_won`, `mark_lost`, `reopen`. O resultado é um **404** silencioso sempre que o usuário tenta exportar.
- **Impacto:** Funcionalidade de exportação CSV completamente quebrada.
- **Correção:**
  ```ruby
  # config/routes.rb — dentro de resources :deals
  resources :deals, only: [:index, :show, :create, :update, :destroy] do
    collection do
      post :export  # <-- ADICIONAR
    end
    member do
      post :move
      post :mark_won
      post :mark_lost
      post :reopen
    end
  end
  ```
- **Status:** ⬜ Pendente

---

### BUG-002: `CRMFunnelChart.vue` — `computed` importado após uso

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMFunnelChart.vue` (linhas 31-47)
- **Problema:** O `import { computed } from 'vue'` está na **linha 47**, mas `computed()` é usado nas linhas 31-36. Isto causa um `ReferenceError` em runtime porque o `computed` é acessado antes de ser importado. O componente simplesmente não renderiza.
- **Impacto:** Gráfico de funil não funciona — tela branca ou erro no console.
- **Correção:** Mover `import { computed } from 'vue'` para o topo do bloco `<script setup>`, antes de qualquer uso.
  ```diff
  <script setup>
  -/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
  +/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
  +import { computed } from 'vue';
  +
   const props = defineProps({
  ...
  -import { computed } from 'vue';
   </script>
  ```
- **Status:** ⬜ Pendente

---

### BUG-003: Inconsistência de thresholds de classificação entre 3 locais

- **Arquivo:** `CrmDeal#score_classification_label` (model), `Crm::LeadScoreCalculator` (service), `CrmLeadScore#classification_for` (model)
- **Problema:** Existem **3 implementações diferentes** da lógica de classificação de score, com thresholds ligeiramente incompatíveis:

  | Local | `prioridade_alta` | `qualificado` | `medio_potencial` | `baixo_potencial` |
  |---|---|---|---|---|
  | `CrmDeal#score_classification_label` | `80..100` | `60..79` | `40..59` | `0..39` |
  | `Crm::LeadScoreCalculator::CLASSIFICATION_THRESHOLDS` | `>= 80` | `>= 60` | `>= 40` | `>= 0` |
  | `CrmLeadScore#classification_for` | `80..100` | `60..79` | `40..59` | `else` |

  O `CrmDeal#score_classification_label` retorna `nil` para scores negativos ou > 100 (o `case/when` não cobre). O `CrmLeadScore` usa `else` para < 40, mas também para > 100. O `LeadScoreCalculator` usa `.clamp(0, 100)` mas os outros não.

- **Impacto:** Scores calculados pelo service podem ter classificação diferente do que o model retorna. Frontend (`CRMScoreBadge`) implementa uma **4ª versão** com os mesmos thresholds mas pode divergir se receber dados do model vs service.
- **Correção:** Centralizar a lógica de classificação num único método/concern e reutilizar em todos os pontos.
- **Status:** ⬜ Pendente

---

### BUG-004: `CRMScoreBadge.vue` — CSS `:root` dentro de `<style scoped>` não aplica tokens

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMScoreBadge.vue` (linhas 105-123)
- **Problema:** Os CSS custom properties (design tokens) estão definidos dentro de `:root {}` mas o bloco `<style>` tem atributo `scoped`. Quando Vue processa `scoped`, ele adiciona atributos de escopo `[data-v-xxx]` a todos os seletores, transformando `:root` em `:root[data-v-xxx]`, que **nunca faz match** no DOM (o `<html>` não tem esse atributo). As variáveis CSS `--crm-score-high-bg` etc. **nunca são definidas**.
- **Impacto:** O badge exibe cores fallback do navegador (tipicamente preto/transparente), não as cores pretendidas.
- **Correção:** Remover `scoped` do `<style>` **ou** mover as definições de `:root` para um arquivo CSS global, mantendo apenas os estilos do componente como `scoped`.
- **Status:** ⬜ Pendente

---

### BUG-005: `CRMScoreBadge.vue` — Dark mode usa seletor `.dark-theme` mas o sistema usa `.dark`

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMScoreBadge.vue` (linha 126)
- **Problema:** Os overrides de dark mode usam o seletor `.dark-theme`, mas o layout do sistema (`super_admin/application.html.erb`, linha 26) adiciona a classe `dark` ao `<html>` (não `.dark-theme`). Isso significa que o dark mode dos score badges **nunca é ativado**.
- **Impacto:** No dark mode, os badges ficam com cores claras (fundo branco, texto escuro) criando contraste ruim contra o fundo escuro.
- **Correção:** Alterar `.dark-theme` para `.dark` (ou `html.dark`, conforme o padrão do sistema).
- **Status:** ⬜ Pendente

---

## 🟠 Bugs Importantes

### BUG-006: Frontend `exportDeals` faz POST mas controller espera action dentro de collection

- **Arquivo:** `app/javascript/dashboard/api/crm.js` (linha 134)
- **Problema:** Mesmo após corrigir o BUG-001, o `CrmAPI.exportDeals()` faz `axios.post(crmUrl('deals/export'), params, { responseType: 'blob' })`. Mas o path gerado será `/api/v1/accounts/:id/crm/deals/export` que não corresponde ao padrão RESTful da rota collection. Além disso, o controller espera params via query (GET-style) mas recebe no body (POST). A disjunção de formatos pode causar filtros ignorados.
- **Impacto:** Exportação pode retornar todos os deals sem filtros aplicados.
- **Status:** ⬜ Pendente

---

### BUG-007: `CRMDealCard.vue` — prop `size` inválida em `CRMLegalAreaBadge`

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMDealCard.vue` (linha 102)
- **Problema:** O `CRMDealCard` passa `:size="xs"` para `CRMLegalAreaBadge`, mas esse componente **não aceita prop `size`** — ele usa `compact` (Boolean). A prop é silenciosamente ignorada e o badge renderiza no tamanho padrão (não compacto).
- **Impacto:** Visual inconsistente — badges de área jurídica ficam maiores do que o pretendido nos cards do kanban.
- **Correção:** Substituir `size="xs"` por `:compact="true"` ou `compact`.
- **Status:** ⬜ Pendente

---

### BUG-008: `CRMSidebarCard.vue` — Classes Tailwind hardcoded vs Design Tokens

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMSidebarCard.vue`
- **Problema:** O componente mistura classes do design system (`text-n-slate-12`, `bg-n-slate-1`, `border-n-weak`) com classes Tailwind padrão hardcoded (`text-gray-500`, `dark:text-gray-400`, `text-red-400`, `bg-blue-50`, `dark:bg-slate-700`, `text-woot-500`, etc.). Isso cria inconsistência visual porque:
  1. As cores `gray-*` e `woot-*` não seguem o tema dinâmico
  2. O dark mode usa `dark:` prefix em vez do sistema de tokens
- **Impacto:** Cores inconsistentes entre CRMSidebarCard e outros componentes CRM; dark mode parcialmente funcional.
- **Status:** ⬜ Pendente

---

### BUG-009: `CRMDealCard.vue` — Mesclagem de formatos camelCase e snake_case

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMDealCard.vue` (linhas 23-71)
- **Problema:** O componente tenta acessar propriedades em **dois formatos** como fallback (`deal.urgency_level || deal.urgencyLevel`, `deal.next_best_action || deal.nextBestAction`, `deal.value_estimate_cents || deal.expectedRevenue`). Isso sugere que a API pode retornar dados em formatos diferentes, mas os nomes camelCase (`urgencyLevel`, `nextBestAction`, `expectedRevenue`) **nunca são retornados** pelo backend Rails (que usa snake_case nativo). Isso é código morto que pode causar confusão em manutenção.
- **Impacto:** Baixo risco imediato, mas indica falta de contrato de API definido. Se alguém renomear a propriedade no backend, o fallback pode mascarar o erro.
- **Status:** ⬜ Pendente

---

### BUG-010: `Crm::StageAutomation` — Pode criar atividades sem `due_at` válida

- **Arquivo:** `app/services/crm/stage_automation.rb` (linha 26)
- **Problema:** Quando `config[:due_in_hours]` é `nil` ou `0`, o cálculo `Time.current + 0.hours` resulta no momento presente, criando uma atividade que já está "vencida" no instante da criação. Isso poluí o scope `overdue` imediatamente.
- **Impacto:** Atividades automáticas podem aparecer como "atrasadas" instantaneamente.
- **Correção:** Adicionar validação `due_in_hours = [config[:due_in_hours].to_i, 1].max` ou usar um default razoável.
- **Status:** ⬜ Pendente

---

### BUG-011: `Crm::DealMover` — Não valida se o stage pertence ao mesmo pipeline

- **Arquivo:** `app/services/crm/deal_mover.rb` (linha 10)
- **Problema:** O serviço atualiza `crm_pipeline_stage_id` sem verificar se o stage destino pertence ao **mesmo pipeline** do deal. Se um ID de stage de outro pipeline for passado, o deal ficará em estado inconsistente — pertencendo a um pipeline mas apontando para um stage de outro.
- **Impacto:** Corrupção de dados silenciosa. O Kanban pode não exibir o deal em nenhuma coluna.
- **Correção:** Adicionar validação antes do `update!`:
  ```ruby
  target_stage = CrmPipelineStage.find(@stage_id)
  raise "Stage does not belong to deal's pipeline" unless target_stage.crm_pipeline_id == @deal.crm_pipeline_id
  ```
- **Status:** ⬜ Pendente

---

## 🟡 Bugs Moderados

### BUG-012: `CRMActivityList.vue` — Atividades concluídas limitadas a 4 sem opção de ver mais

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMActivityList.vue` (linha 22)
- **Problema:** `completedActivities` faz `.slice(0, 4)` hardcoded. Não há botão "Ver mais" ou paginação. Se o deal tem muitas atividades concluídas, o histórico fica incompleto.
- **Impacto:** UX limitada — usuário perde contexto de atividades antigas.
- **Status:** ⬜ Pendente

---

### BUG-013: `CRMDealDrawer.vue` — `centsFromInput` não valida entrada negativa

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMDealDrawer.vue` (linhas 166-173)
- **Problema:** A função `centsFromInput` aceita valores negativos, o que geraria `value_estimate_cents` negativo no banco. Embora o backend não valide isso explicitamente, um valor negativo pode distorcer o cálculo do score (`economic_score`) e criar dados financeiros incorretos.
- **Impacto:** Dados financeiros potencialmente inválidos.
- **Correção:** Adicionar `Math.max(0, Math.round(amount * 100))`.
- **Status:** ⬜ Pendente

---

### BUG-014: `CRMTimeline.vue` — `payloadSummary` pode exibir `[object Object]`

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMTimeline.vue` (linhas 41-45)
- **Problema:** A função itera sobre `Object.entries(payload)` e faz `${key}: ${value}`. Se `value` for um objeto aninhado (ex: `{ from_stage_id: 1, to_stage_id: 2 }` contendo sub-objetos), o template literal produz `[object Object]`.
- **Impacto:** Timeline exibe dados ilegíveis para eventos com payloads complexos.
- **Correção:** Usar `JSON.stringify(value)` como fallback para valores não-primitivos.
- **Status:** ⬜ Pendente

---

### BUG-015: `Crm::AuditLogger` — Silencia TODOS os erros de criação

- **Arquivo:** `app/services/crm/audit_logger.rb` (linhas 16-18)
- **Problema:** O `rescue StandardError => e` captura **qualquer** exceção (incluindo erros de banco, violações de constraint, etc.) e apenas loga no Rails logger. Isso significa que falhas de auditoria nunca causam rollback de transações, mesmo quando a auditoria é parte de um fluxo crítico.
- **Impacto:** Eventos de auditoria podem ser silenciosamente perdidos. Em fluxos regulatórios (LGPD), isso pode ser uma violação de compliance.
- **Status:** ⬜ Pendente

---

### BUG-016: `CRMDealDrawer.vue` — `toDateInput` não trata datas inválidas

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMDealDrawer.vue` (linhas 116-119)
- **Problema:** `new Date(value)` pode retornar `Invalid Date` se `value` for uma string malformada. Chamar `.toISOString()` em `Invalid Date` lança `RangeError`.
- **Impacto:** O drawer pode crashar ao abrir um deal com data de retenção mal formatada.
- **Correção:**
  ```javascript
  function toDateInput(value) {
    if (!value) return '';
    const d = new Date(value);
    return isNaN(d.getTime()) ? '' : d.toISOString().slice(0, 10);
  }
  ```
- **Status:** ⬜ Pendente

---

### BUG-017: `CrmPipelineStage` — Falta uniqueness constraint em `slug` por pipeline

- **Arquivo:** `app/models/crm_pipeline_stage.rb`
- **Problema:** O model valida `presence` de `slug` mas **não valida uniqueness** com scope no pipeline. Isso permite dois stages com o mesmo slug no mesmo pipeline, o que pode quebrar o `stage_for_classification` no `LeadScoreCalculator` que busca por slug: `find_by(slug: slug)` — retornará o primeiro encontrado, que pode não ser o desejado.
- **Impacto:** Deals podem ser movidos para o stage errado quando dois stages compartilham o mesmo slug.
- **Correção:** Adicionar `validates :slug, uniqueness: { scope: :crm_pipeline_id }`.
- **Status:** ⬜ Pendente

---

### BUG-018: `Crm::ApplyChecklistTemplate` — Não define `due_at` nas atividades criadas

- **Arquivo:** `app/services/crm/apply_checklist_template.rb` (linhas 12-21)
- **Problema:** As atividades criadas a partir do checklist template não recebem `due_at`. Isso significa que elas nunca aparecem no scope `overdue` nem `due_today`, tornando impossível rastrear prazos.
- **Impacto:** Atividades de checklist ficam sem prazo definido — o acompanhamento de SLA fica prejudicado.
- **Status:** ⬜ Pendente

---

## 🟢 Melhorias / Code Smells

### SMELL-001: `CrmAPI` (frontend) — `accountIdFromRoute()` extraído via parsing de URL

- **Arquivo:** `app/javascript/dashboard/api/crm.js` (linhas 4-9)
- **Problema:** O `accountId` é extraído manualmente do `window.location.pathname` via `split('/')[3]`. Isso é frágil — qualquer mudança na estrutura de URL quebra todas as chamadas CRM. O restante do sistema usa o Vuex store (`auth/currentAccountId`) para obter o account ID.
- **Impacto:** Fragilidade — se a estrutura de rotas mudar, todas as API calls CRM param de funcionar.

---

### SMELL-002: `CRMDealCard.vue` — Variáveis CSS com fallback inline

- **Arquivo:** `app/javascript/dashboard/components/crm/CRMDealCard.vue` (linhas 238-239)
- **Problema:** A classe `.crm-deal-card__urgency--media` usa `var(--amber-3, 254 243 199)` com fallback inline. Se o token `--amber-3` não estiver definido, o fallback funciona, mas isso mascara a ausência do token no design system.

---

### SMELL-003: `Crm::LeadScoreCalculator` — Método `campaign_scoring_config` acessa `scoring_config.to_h` sem nil check robusto

- **Arquivo:** `app/services/crm/lead_score_calculator.rb` (linha 301)
- **Problema:** `@deal.conversation&.campaign&.scoring_config.to_h` — se `scoring_config` for `nil`, `.to_h` retorna `{}` (OK). Mas se `scoring_config` for uma String (malformada no JSONB), `.to_h` lança erro. Embora improvável, é um vetor de falha silenciosa.

---

### SMELL-004: `CrmCadence` model — scope `active` usa `archived_at: nil` em vez de `status`

- **Arquivo:** `app/models/crm_cadence.rb` (linha 12)
- **Problema:** O scope `active` filtra por `archived_at: nil`, mas o model tem um campo `status` com valor `'active'`. Isso cria ambiguidade — um cadence pode ter `status: 'paused'` e `archived_at: nil`, e seria considerado "active" pelo scope.

---

### SMELL-005: `CRMDealDrawer.vue` — Formulário envia `summary` e `next_best_action` mas controller não os lista explicitamente no `deal_update_params`

- **Arquivo:** Controller `deals_controller.rb` (linhas 132-138) vs Drawer (linhas 180-183)
- **Problema:** Na verdade, revisando novamente, o `deal_update_params` **inclui** `:summary` e `:next_best_action` (linha 135-136). Mas **não inclui** `:consent_collected_at` e `:data_retention_until` que o drawer também envia. Na verdade, verificando novamente — eles **estão** na linha 137. Sem problema real aqui. ~~Reclassificado como falso positivo.~~
- **Revisão:** Sem bug. Removido da contagem.

---

## Histórico de Correções

| Data | Bug ID | Descrição | Commit |
|---|---|---|---|
| — | — | Nenhuma correção aplicada ainda | — |

---

> **Próximos passos:** Priorizar correções dos bugs 🔴 Críticos primeiro, seguidos pelos 🟠 Importantes. Cada correção deve ser registrada neste documento com data e commit hash.
