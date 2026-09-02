# Inventário legacy/operational do módulo CRM — F0.2

**Data:** 2026-08-28
**Plano:** [PLANO-KANBAN-CRM-2026.md](../../PLANO-KANBAN-CRM-2026.md) — item F0.2
**Status:** ✅ inventário fechado — **mas a F2.1 não pode começar sem uma decisão** (ver §4)

Objetivo do item: mapear os 6 pares `*Legacy.vue` / `*Operational.vue` e decidir
qual é a fonte de verdade em cada um.

---

## 1. Qual versão está no ar

Os **6 wrappers usam a mesma flag**, `FEATURE_FLAGS.CRM_V2` (`crm_v2`). Não há
controle por página: os seis viram juntos.

```
CrmIndex.vue · Agenda.vue · AllLeads.vue · Activities.vue · DealDetails.vue · PipelineSettings.vue
  → isFeatureEnabled(accountId, FEATURE_FLAGS.CRM_V2) ? *Operational : *Legacy
```

`core/config/features.yml` traz `crm_v2: enabled: false`, mas o estado real do
banco é outro:

```
conta   1 (Adv — conta real): crm_v2=true
conta 115 (Conta A QA):       crm_v2=true
conta 118 (Conta A QA):       crm_v2=true
conta 121 (Conta A QA):       crm_v2=true
```

> **Fonte de verdade nos 6 pares: `*Operational.vue`.** É o que o atendente vê
> hoje, inclusive na conta de produção. Todo `*Legacy.vue` é código morto em
> runtime — com uma exceção que muda tudo (§4).

---

## 2. Volumetria

| Par | Legacy | Operational | Wrapper | Delta |
| :--- | ---: | ---: | ---: | ---: |
| `CrmIndex` (o board) | 2.538 | 599 | 27 | −1.939 |
| `Agenda` | 3.490 | 808 | 27 | −2.682 |
| `PipelineSettings` | 2.765 | 678 | 27 | −2.087 |
| `AllLeads` | 2.515 | 665 | 27 | −1.850 |
| `Activities` | 2.180 | 1.255 | 29 | −925 |
| `DealDetails` | 1.780 | 951 | 27 | −829 |
| **Total** | **15.268** | **4.956** | **164** | **−10.312** |

Apagar os seis Legacy remove **15.268 linhas**, não as "~4.000" estimadas no
plano (divergência D-02, registrada em [KANBAN-BASELINE.md](../qa/KANBAN-BASELINE.md)).

---

## 3. Paridade funcional, par a par

Método: comparação da superfície de chamadas a `dashboard/api/crm` em cada
arquivo. É um proxy — cobre o que cada tela consegue *fazer*, não como ela se
parece.

### ✅ Paridade total — Legacy é puro peso morto

| Par | Métodos de API |
| :--- | :--- |
| `PipelineSettings` | 14 idênticos nos dois |
| `Agenda` | 12 idênticos nos dois |
| `Activities` | 13 idênticos nos dois |

**8.435 linhas** removíveis sem perda funcional conhecida. É por aqui que a F2.1
deve começar — risco baixo, ganho alto.

### 🔴 D-05 — `CRMDealCard.vue` é um segundo D-04 (achado em 2026-08-28)

`CRMDealCard.vue` (685 linhas) é renderizado **só** por `CrmIndexLegacy.vue`.
O board no ar, o Operational, desenha os cards inline no próprio arquivo. É o
mesmo padrão do `CRMKanbanChatDrawer` (D-04): componente vivo no código, morto
em runtime.

Isso muda a F2.4 ("Card redesenhado"), que assume estar redesenhando
`CRMDealCard`. Ou o card do Operational é extraído para esse componente antes
da F2.4, ou a F2.4 redesenha o markup inline e o `CRMDealCard` é apagado junto
com o `CrmIndexLegacy` na etapa (d).

Consequência imediata: o botão de descartar que o `CRMDealCard` emite
(`@click="emit('discardDeal', { deal, reason: 'spam' })"`) não existe para o
atendente hoje.

### ⚠️ Operational com lacunas

> ### ⚠️ Correção de método, 2026-08-28 (F2.1 b)
>
> O levantamento abaixo procurou `CrmAPI.` **no arquivo da página**. Isso não
> enxerga o que a página alcança pelos componentes que ela renderiza — e
> superestimou as lacunas dos três pares restantes.
>
> `CRMDealDrawer.vue` implementa `deleteDeal` e é renderizado por
> `DealDetailsOperational`, `AllLeadsOperational` e `CrmIndexOperational`. Logo
> **`deleteDeal` nunca foi lacuna** em nenhum dos três.
>
> `discardDeal`, esse sim, não é alcançável em lugar nenhum do mundo
> Operational: só existe nos arquivos Legacy e no `CRMDealCard.vue`, cujo
> `emit('discardDeal')` ninguém escuta fora do `CrmIndexLegacy`.
>
> Ao revisar (c) e (d), refaça a conta incluindo os componentes filhos.

**`DealDetails`** — ~~Operational não alcança 2 ações~~ **1 ação** (corrigido):

| Só no Legacy | O que é | Lacuna real? |
| :--- | :--- | :--- |
| `deleteDeal` | excluir negócio | **não** — o `CRMDealDrawer` que a página renderiza já exclui |
| `discardDeal` | descartar (inválido / spam / duplicado / sem lead) | **sim** — portado na F2.1 (b), agora com os quatro motivos escolhíveis |

**`AllLeads`** — Operational não alcança 7 ações:

| Só no Legacy | O que é |
| :--- | :--- |
| `deleteDeal` · `discardDeal` | excluir e descartar |
| `markDealBaseClient` | marcar como cliente da base |
| `markDealWon` | marcar ganho |
| `moveDeal` | trocar de etapa pela lista |
| `recomputeScore` | recalcular score |
| `updateDeal` | edição direta |

**`CrmIndex` (o board)** — Operational não alcança 10 ações:

| Só no Legacy | O que é | Lacuna real? |
| :--- | :--- | :--- |
| `getActivities` | atividades pendentes por card | **sim** — alimenta "próxima ação", princípio nº 5 do plano |
| `updateDeal` | edição inline | **sim** |
| `deleteDeal` · `discardDeal` | excluir / descartar | **sim** |
| `markDealBaseClient` | cliente da base | **sim** — regra de produto nº 10 (cliente antigo ≠ lead novo) |
| `recomputeScore` | recalcular score | provável |
| `getHealth` | health do CRM | não — utilitário de admin |
| `purgeOrphanDeals` | expurgo de órfãos | não — utilitário de admin |
| `createPipeline` · `createPipelineStage` | CRUD de pipeline pelo board | **não** — pertence a `PipelineSettings` |

Só no Operational: `createDeal` (criar negócio direto na coluna) — o Legacy não tem.

---

## 4. 🔴 O achado que trava a F2.1

**`CRMKanbanChatDrawer.vue` (2.183 linhas) é importado por exatamente um
arquivo: `CrmIndexLegacy.vue`.**

```
$ grep -rl "CRMKanbanChatDrawer" core/app/javascript/
core/app/javascript/dashboard/components/crm/CRMKanbanChatDrawer.spec.js
core/app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndexLegacy.vue
```

Comportamento ao clicar num card:

| Board | Abre | Dá para responder no WhatsApp? |
| :--- | :--- | :---: |
| `CrmIndexLegacy` | `CRMKanbanChatDrawer` (conversa inline) | **sim** |
| `CrmIndexOperational` ← **no ar** | `CRMDealDrawer` (dados do negócio) | **não** |

### Por que isso importa

O plano trata o chat no board como pronto e como o maior diferencial do produto:

> §3.1 — "Chat no board — `CRMKanbanChatDrawer.vue` — 2.183 linhas, com busca na
> timeline, controle de modo da IA, envio de mensagem, troca de etapa"
>
> §4 — "Card = conversa (chat no board) | Mercado BR | ✅ **Já existe** — polir
> `CRMKanbanChatDrawer` | F2.14"

**O código existe. O produto no ar não alcança.** Como `crm_v2` está ligado na
conta real, o atendente de hoje **não consegue responder no WhatsApp sem sair do
Kanban** — que é o item nº 2 dos cinco que definem o goal.

E a consequência direta para a F2.1: apagar `CrmIndexLegacy.vue` como o plano
manda **apaga o único ponto de entrada do chat**, junto com `CRMDealCard.vue`
(685 linhas), que também só ele usa.

---

## 5. Órfãos e travessias fora do CRM

Uso de cada componente em `components/crm/` (quem importa):

| Componente | Linhas | Importado por |
| :--- | ---: | :--- |
| `CRMKanbanChatDrawer` | 2.183 | **só `CrmIndexLegacy`** |
| `CRMDealCard` | 685 | **só `CrmIndexLegacy`** |
| `CRMContactLifecycle` | 302 | **nenhum arquivo encontrado — já órfão hoje** |
| `CRMSidebarCard` | 777 | `ContactPanel.vue` — **fora do CRM, é o Inbox** |
| `CRMDealDrawer` | 773 | 6 arquivos, Legacy e Operational |
| `CRMConfirmDialog` | 62 | 6 arquivos, Legacy e Operational |
| `CRMDealOutcomeControl` | 219 | `CRMDealDrawer`, `CRMKanbanChatDrawer`, `DealDetailsLegacy` |
| `CRMLegalAreaBadge` | 64 | 5 arquivos |
| `CRMScoreAudit` | 164 | 3 arquivos |
| `CRMScoreBadge` | 118 | 6 arquivos |
| `CRMActivityList` · `CRMNextActionBox` · `CRMTimeline` | 447 | só `CRMDealDrawer` |
| `CRMExportButton` · `CRMFunnelChart` | 370 | só `Reports.vue` |

**Atenção da F2.1:** `CRMSidebarCard` é consumido pelo `ContactPanel` do **Inbox**.
O anti-goal proíbe mexer no Inbox — qualquer alteração nesse componente sangra
para fora do escopo.

**Achado lateral:** `CRMContactLifecycle.vue` (302 linhas) não tem nenhum
importador. Candidato a remoção, mas **não removido aqui** — precisa de
confirmação de que não há uso dinâmico.

---

## 6. Ordem recomendada para a F2.1

Deriva das evidências acima, não da intuição:

1. **`PipelineSettings`, `Agenda`, `Activities`** — paridade total. Apagar os
   três Legacy e achatar o wrapper. −8.435 linhas, risco baixo.
2. **`DealDetails`** — portar `deleteDeal` e `discardDeal` para o Operational,
   depois apagar. −1.780.
3. **`AllLeads`** — portar as 7 ações faltantes, depois apagar. −2.515.
4. **`CrmIndex`** — **por último e não como uma exclusão**. Antes de apagar o
   Legacy é preciso levar o `CRMKanbanChatDrawer` para o board Operational e
   fechar as lacunas reais da tabela do §3. Enquanto isso não acontecer, apagar o
   Legacy remove capacidade do produto.

---

## 7. Decisão pendente

O §4 é uma contradição entre o plano e o código que **não cabe a esta tarefa
resolver**. Está registrada como divergência **D-04** e precisa de decisão antes
que a F2.1 encoste no par `CrmIndex`.
