# Baseline de performance do Kanban — F0.3

**Data:** 2026-08-28
**Plano:** [PLANO-KANBAN-CRM-2026.md](../../PLANO-KANBAN-CRM-2026.md) — item F0.3
**Status:** ✅ fechado — todos os números medidos
**Board medido:** `CrmIndexOperational.vue` (`crm_v2` está **ligado** em todas as contas, inclusive na conta real `Adv` id=1)

Este documento é o ponto de comparação da F7. Nenhum número aqui é meta; são
medições do estado atual. Quem for medir de novo deve usar exatamente o mesmo
harness e registrar lado a lado.

---

## 1. Como reproduzir

```bash
# 1. Semear a fixture (isolada, namespace proprio por volume)
docker exec -e RAILS_ENV=production \
  -e DATABASE_URL=postgresql://chusterm:chusterm_pass@postgres:5432/chusterm_core \
  -e FRONTEND_URL=http://localhost:8086 -e QA_FIXTURE_TARGET=local-compose \
  -e QA_FIXTURE_PASSWORD="<senha local, min 12 chars>" \
  -e QA_FIXTURE_NAMESPACE=kb500 -e QA_FIXTURE_DEAL_COUNT=500 \
  <container-com-o-codigo> sh -c 'cd /app && bundle exec rake qa:seed'

# 2. Latencia da API
CRM_BENCH_TOKEN=... CRM_BENCH_ACCOUNT=121 CRM_BENCH_PIPELINE=41 \
  CRM_BENCH_STAGE=224 CRM_BENCH_OWNER=47 CRM_BENCH_INBOX=124 \
  bash qa/bench/crm-deals-bench.sh

# 3. Carga do board e FPS do drag
cd qa/e2e
QA_FIXTURE_NAMESPACE=kb500 QA_FIXTURE_PASSWORD=... \
KANBAN_BASELINE_ACCOUNT=121 KANBAN_BASELINE_LABEL="500 negocios" \
  pnpm exec playwright test tests/kanban-baseline.spec.ts --project=chromium-desktop
```

Harness versionado:
- `qa/bench/crm-deals-bench.sh` — p50/p95/max do `GET /crm/deals`
- `qa/e2e/tests/kanban-baseline.spec.ts` — carga do board, nós de DOM, FPS do drag

### Ambiente

| Item | Valor |
| :--- | :--- |
| Host | AMD Ryzen 7 9800X3D (8 núcleos), 61,6 GB RAM, Windows 11 |
| App | Docker Compose local, `RAILS_ENV=production`, `http://127.0.0.1:8086` |
| Ruby / Rails | 3.4.4 / 7.2.3.1 |
| PostgreSQL | 15.17 |
| Node (Playwright) | 25.2.1, Chromium desktop, viewport 1366×768 |
| Commit | `f6e8cf7` (working tree com WIP), `main` em `f5f0dde` |

### Fixtures

| Volume | Namespace | Conta | Pipeline | Etapa `novo` |
| ---: | :--- | ---: | ---: | ---: |
| 100 | `kb100` | 118 | 39 | 212 |
| 500 | `kb500` | 121 | 41 | 224 |
| 2.000 | `kbase` | 115 | 37 | 200 |

---

## 2. `GET /crm/deals` — latência por requisição

40 amostras por cenário, após 5 requisições de aquecimento.

Percentil por *nearest-rank* (`ceil(N·p)`).

### 100 negócios

| Cenário | p50 | p95 | max |
| :--- | ---: | ---: | ---: |
| sem filtro, `per_page=50` | 48 ms | 52 ms | 57 ms |
| como o board pede, `per_page=200` | 82 ms | 103 ms | 111 ms |
| **10 filtros simultâneos** | 49 ms | **53 ms** | 54 ms |

### 500 negócios

| Cenário | p50 | p95 | max |
| :--- | ---: | ---: | ---: |
| sem filtro, `per_page=50` | 48 ms | 60 ms | 65 ms |
| como o board pede, `per_page=200` | 146 ms | 157 ms | 281 ms |
| **10 filtros simultâneos** | 49 ms | **62 ms** | 69 ms |

### 2.000 negócios

| Cenário | p50 | p95 | max |
| :--- | ---: | ---: | ---: |
| sem filtro, `per_page=50` | 49 ms | 60 ms | 76 ms |
| como o board pede, `per_page=200` | 146 ms | 164 ms | 204 ms |
| **10 filtros simultâneos** | 53 ms | **72 ms** | 80 ms |

Os 10 filtros são `pipeline_id`, `stage_id`, `owner_id`, `inbox_id`, `status`,
`operational_status`, `source`, `score_min`, `score_max`, `search`.

> **A meta de p95 < 300 ms já está batida no endpoint** — em todos os volumes, com
> folga de 4×. O diagnóstico do plano estava certo: `deals_controller#index` já
> resolve N+1 com contagens agregadas. **O gargalo do board não é a API.**

---

## 3. Carga do board — o custo real do K-01

O board não faz uma requisição. `fetchAllCrmDeals` (`crmDealsPagination.js`)
pagina **sequencialmente** com `per_page=200` até cobrir o total, e só então
entrega tudo ao componente.

### Só a rede (10 repetições, `qa/bench/crm-deals-bench.sh`)

| Volume | Requisições sequenciais | p50 | max |
| ---: | ---: | ---: | ---: |
| 100 | 1 | 125 ms | 132 ms |
| 500 | 3 | 484 ms | 630 ms |
| 2.000 | 10 | **1.787 ms** | 1.925 ms |

Com 10 repetições não faz sentido publicar p95 aqui — seria só repetir o máximo.

### Board completo no navegador

Mediana de 3 execuções. `boardReady` = do início da navegação até a contagem de
cards no DOM parar de crescer. A janela de confirmação de 1,5 s **não** entra na
conta: o valor é o instante da estabilização.

| Volume | boardReady | boot do SPA | paginação | render | cards no DOM | nós de DOM |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 100 | **1.344 ms** | 1.116 ms | 0 ms | 228 ms | 100 | 2.334 |
| 500 | **1.720 ms** | 1.151 ms | 245 ms | 324 ms | 500 | 9.134 |
| 2.000 | **3.684 ms** | 1.239 ms | 1.543 ms | 902 ms | 2.000 | 34.634 |

- **boot do SPA** — constante ~1,15 s, independe do volume. É o piso.
- **paginação** — o preço do K-01. Cresce linear: 0 → 245 → 1.427 ms.
- **render** — montar os cards. Cresce 4× de 100 para 2.000.

### Contra as metas do plano

| Meta | Valor | Medido | Situação |
| :--- | :--- | ---: | :--- |
| TTI do board, 500 negócios | < 1,2 s | 1.720 ms | ❌ 43% acima |
| TTI do board, 5.000 negócios | < 1,8 s | 3.684 ms **com 2.000** | ❌ já estoura com 40% do volume |
| `GET /crm/deals`, 10 filtros | p95 < 300 ms | 53–72 ms | ✅ com folga |

> Nota sobre TTI: `boardReady` é uma proxy — "a contagem de cards parou de
> crescer" — não o TTI canônico (thread principal livre para responder a input em
> < 50 ms). A medição inclui o boot do SPA a partir de uma sessão restaurada; um
> atendente que já navega dentro do app não paga esse boot de novo. Descontando o
> boot, o board custa **228 ms (100)**, **569 ms (500)** e **2.445 ms (2.000)**.
> Mesmo nessa leitura mais generosa, os 500 ficam dentro de 1,2 s, mas os 2.000
> estouram 1,8 s sozinhos.

---

## 4. Drag & drop — FPS

Quatro varreduras de ponteiro sobre a coluna (`mouse.move` com `steps: 40`, que
enfileira os eventos intermediários numa chamada só), amostrando
`requestAnimationFrame`. `pegouOCard: true` em todas as execuções — confirmado
pelo *ghost* do `vuedraggable`, então há um card sendo arrastado de verdade.

**Controle de sanidade:** `somaFramesMs` (soma dos deltas de frame) tem que bater
com `janelaRealMs` (relógio de parede do arrasto). Se destoarem, o recorte da
janela está errado e os números não valem.

| Volume | FPS mediano | p95 do frame | **max do frame** | frames > 16,7 ms | amostras | soma × janela |
| ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| 100 | 60 | 17 ms | 17 ms | 3 de 9 | 9 | 150 × 149 ms ✓ |
| 500 | 60 | 17 ms | 33 ms | 7 de 30 | 30 | 517 × 471 ms ✓ |
| 2.000 | 60 | **83–100 ms** | **133 ms** | 25 de 67 | 67 | 1.750 × 1.591 ms ✓ |

> **Até 500 negócios o drag é saudável.** Com 2.000 ele engasga de verdade: o p95
> do frame vai a ~90 ms (≈11 fps) e o pior frame chega a **133 ms** — um travamento
> visível ao usuário. A mediana permanece em 60 fps, o que mostra que **a mediana
> é a métrica errada** para esta meta.
>
> **Correção metodológica.** A primeira versão deste harness movia o ponteiro num
> laço de `mouse.move` + `waitForTimeout(16)`. Cada passo pagava um round-trip do
> CDP, a janela real ficava ~7× maior que a nominal e a página ganhava folga
> ociosa entre eventos — o oposto de um arrasto real. Aquela versão reportava
> p95 = 33 ms e max não era reportado, escondendo o engasgo. Os números acima são
> da versão corrigida. **Se você viu uma revisão anterior deste documento com
> p95 = 33 ms para 2.000, descarte: estava errado.**
>
> Consequência para a F7.4: a meta "60 fps sustentado" precisa virar **p95 e max
> do frame**, não FPS mediano.

---

## 5. Volumetria do módulo CRM no front

| Escopo | Linhas |
| :--- | ---: |
| `routes/dashboard/crm` + `components/crm` (sem specs) | **34.727** |
| idem, sem os 6 `*Legacy.vue` | 19.459 |
| só `components/crm` | 6.164 |
| incluindo specs | 35.776 |

Os 6 pares Legacy/Operational:

| Par | Legacy | Operational | Wrapper |
| :--- | ---: | ---: | ---: |
| `CrmIndex` | 2.538 | 599 | 27 |
| `Agenda` | 3.490 | 808 | 27 |
| `PipelineSettings` | 2.765 | 678 | 27 |
| `AllLeads` | 2.515 | 665 | 27 |
| `Activities` | 2.180 | 1.255 | 29 |
| `DealDetails` | 1.780 | 951 | 27 |
| **Total** | **15.268** | **4.956** | 164 |

---

## 6. Distribuição por etapa — limite conhecido desta baseline

`Qa::CanonicalFixture` distribui cenário por ordinal: só os 7 primeiros negócios
variam; do 8º em diante todos entram como `lead` → status `open`, etapa `novo`.

No pipeline de 2.000:

| Etapa | Negócios |
| :--- | ---: |
| Novo | 1.997 |
| Qualificação | 0 |
| Proposta | 0 |
| Negociação | 0 |
| Ganho | 1 |
| Perdido | 2 |

**O que isso significa:** a baseline mede o **pior caso de coluna única** — todos
os cards empilhados numa coluna com `overflow-y-auto`. É um cenário legítimo de
estresse para o K-04 (sem virtualização), mas não é a forma de um pipeline real,
onde os cards se espalham por 5 ou 6 colunas. A F7 deve medir os dois.

---

## 7. Divergências entre o plano e o código

Registradas conforme a regra "se plano e código divergirem, pare e reporte".
**Nenhuma foi corrigida** — as três precisam de decisão.

### D-01 — A contagem de linhas do módulo CRM está errada no plano

O plano (seção 10) diz `~9.500` linhas hoje, com meta `< 7.000`. O real é
**34.727**. Nenhum recorte razoável do módulo chega perto de 9.500 — o menor
escopo defensável (`components/crm` sozinho) dá 6.164 e o maior 35.776.

Consequência: a meta `< 7.000` foi calibrada sobre um número errado. Mesmo
apagando os 6 `*Legacy.vue` inteiros (−15.268 linhas), o módulo fica em 19.459.

### D-02 — A F2.1 remove ~15.268 linhas, não "~4.000"

O plano estima que unificar legacy/operational "remove ~4.000 linhas". Os seis
arquivos Legacy somam **15.268**. O ganho é quase 4× o previsto — o que reforça
a prioridade da F2.1, mas muda o dimensionamento do esforço.

### D-03 — A estimativa de nós de DOM do K-04 está ~30× alta

O plano diz "500 cards = ~340k nós DOM (card tem 685 linhas de template)". O
medido é **9.134 nós para 500 cards** (~18 nós por card) e 34.634 para 2.000.

A estimativa provavelmente veio de `CRMDealCard.vue` (685 linhas, usado **só** pelo
board Legacy — ver [KANBAN-V2-INVENTARIO.md](../execution/KANBAN-V2-INVENTARIO.md)),
mas o board vivo é o Operational, que monta um `article` inline bem mais enxuto.
A virtualização (F2.2) continua justificada — 34,6k nós e o p95 do frame dobrando
são reais — mas **não** pelo motivo escrito no plano.

### D-04 — O chat no board não está no ar

O plano trata `CRMKanbanChatDrawer.vue` como pronto e como o maior diferencial do
produto (§3.1 e §4). Ele é importado por **um único arquivo**: `CrmIndexLegacy.vue`.
Como `crm_v2` está ligado, o board no ar é o Operational, que abre `CRMDealDrawer`
— sem conversa de WhatsApp.

Consequência: o item nº 2 do goal ("responder no WhatsApp sem trocar de tela")
**não é alcançável hoje**, e apagar o Legacy na F2.1, como o plano manda, removeria
o único ponto de entrada do chat. Detalhamento em
[KANBAN-V2-INVENTARIO.md §4](../execution/KANBAN-V2-INVENTARIO.md).

---

## 8. Metas ainda não medidas nesta baseline

| Meta | Por quê |
| :--- | :--- |
| Latência do realtime (p95 < 800 ms) | Não há realtime no board hoje (K-02). Não há o que medir; o baseline é "não existe". |
| Negócios abertos sem próxima ação (< 10%) | Métrica de produto sobre dados reais, não sobre fixture. Precisa rodar na base de produção. |
| Ações concluídas sem sair do Kanban (> 70%) | Idem — exige instrumentação de uso que ainda não existe. |
| Cobertura de teste do módulo CRM (≥ 80%) | Não medida aqui. Exige rodar SimpleCov/Vitest com recorte do módulo. |
| Bundle do módulo CRM (< 180 kb gzip) | Meta da F7.6, fora do escopo da F0.3. |
