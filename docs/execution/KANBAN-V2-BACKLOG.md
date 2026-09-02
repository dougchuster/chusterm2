# Backlog do Kanban v2 — dívidas encontradas de passagem

> Regra do plano: *"Não é refatorar código que o plano não cita. Se dói, anote no
> backlog; não conserte de passagem."* Este arquivo é esse backlog.
>
> Nada aqui foi corrigido. Cada item registra o que dói, onde, e quando o plano
> encosta no assunto.

---

## B-01 — Lógica de "atribuir dono" triplicada, com efeitos colaterais diferentes

**Encontrado em:** F0.4 (revisão do hotfix `assign_owner`)
**Severidade da revisão:** HIGH
**Endereçado por:** F3.4 (reescrita das ações do motor de automação)

Três implementações independentes da mesma operação de negócio, cada uma com um
conjunto diferente de efeitos colaterais:

| Caminho | `owner_id` | `assignee_id` | `contact.crm_owner_id` |
| :--- | :---: | :---: | :---: |
| `Crm::ContactOwnerRouter#sync_deal_owner` | ✓ | ✗ | (é a fonte, não o destino) |
| `DealsController#process_bulk_deal!` (ação manual em massa) | ✓ | ✓ | ✓ |
| `Crm::StageAutomation#execute_assign_owner` (pós-F0.4) | ✓ | condicional | ✗ |

Arquivos:
- `core/app/services/crm/contact_owner_router.rb` (~L48-54)
- `core/app/controllers/api/v1/accounts/crm/deals_controller.rb` (~L569-579)
- `core/app/services/crm/stage_automation.rb`

É exatamente o padrão que produziu o bug A-03: regra de negócio reimplementada
em serviços diferentes, divergindo aos poucos sem ninguém perceber. A saída é um
`Crm::DealOwnerAssigner` parametrizável (`sync_assignee:`, `sync_contact:`) usado
pelos três pontos de chamada, com teste para cada combinação.

**Não foi feito agora** porque o plano não cita esse refactor e a F3.4 vai
reescrever as ações do motor de qualquer forma.

---

## B-02 — Auditoria histórica de `automation_executed_assign_owner` é falsa

**Encontrado em:** F0.4
**Severidade da revisão:** LOW
**Endereçado por:** F3.8 (`crm_automation_runs` com status e erro)

Toda linha `automation_executed_assign_owner` em `crm_audit_events` anterior ao
deploy do hotfix representa um no-op. Se esse audit trail for usado para
relatório histórico de atribuições, os dados anteriores ao fix não refletem
atribuições reais.

Não há correção retroativa possível — os deals nunca foram atribuídos. O que
cabe é anotar a data de corte quando o hotfix subir para produção.

---

## B-03 — As demais ações da automação ainda auditam sucesso incondicional

**Encontrado em:** F0.4
**Severidade:** MEDIUM
**Endereçado por:** F3.8

`Crm::StageAutomation#perform` emite `automation_executed_<action_type>` depois
do `case`, independentemente de a ação ter feito algo. O F0.4 corrigiu apenas o
caminho `assign_owner`. `create_activity` (que sai cedo quando já existe
atividade pendente), `set_captain_mode` (sai quando não há conversa ou estado do
Captain) e `move_to_stage` (sai quando a etapa alvo não existe) continuam
reportando sucesso ao não fazer nada.

Corrigir isso de forma genérica muda o contrato de auditoria das quatro ações e
pode afetar consultas existentes sobre `crm_audit_events` — por isso ficou fora
do hotfix.

---

## B-04 — Fixture canônica de QA presume Previdenciário/INSS

**Encontrado em:** F0.3 (leitura da fixture ao montar o baseline)
**Severidade:** MEDIUM — viola a regra de produto nº 9 do plano
**Endereçado por:** F5.2 (presets por nicho)

`core/lib/qa/canonical_fixture.rb`, em `seed_conversations`, escreve diálogos
fixos sobre aposentadoria, CNIS, GPS e exigência do INSS. O escritório é full
service; nenhum seed pode presumir Previdenciário.

Não foi tocado agora porque a fixture é determinística, versionada
(`VERSION = '2026-07-22.1'`) e tem spec próprio — mudar o conteúdo invalida a
baseline da Fase 0 já registrada em `docs/execution/F0-BASELINE.md`. A troca
natural é junto com os presets de vocabulário da F5.2.

---

## B-05 — `AutomationRules.vue` só sabe criar regras `create_activity`

**Encontrado em:** F0.4
**Severidade:** MEDIUM
**Endereçado por:** F3.7 (builder visual WHEN → IF → THEN)

`core/app/javascript/dashboard/routes/dashboard/crm/pages/AutomationRules.vue`
envia `action_type: 'create_activity'` fixo no código. As outras três ações
(`set_captain_mode`, `move_to_stage`, `assign_owner`) existem no backend e são
validadas pelo modelo, mas só podem ser criadas por API ou console.

Consequência prática para o F0.4: uma regra `assign_owner` quebrada não era
visível nem editável pela interface, o que ajuda a explicar por que o no-op
passou meses despercebido.

---

## B-06 — O índice `(stage_id, position)` não cobre o `ORDER BY` do backfill

**Encontrado em:** F1.2 (revisão do job de backfill)
**Severidade da revisão:** LOW
**Endereçado por:** F7.7 (revisão do plano de query e índices faltantes)

`index_crm_deals_on_stage_and_position` serve o filtro `crm_pipeline_stage_id +
position IS NULL`, mas o lote do backfill ordena por `created_at DESC, id DESC`
— o que força um sort em memória por lote. Irrelevante no volume atual (5.000
negócios em 5 etapas rodam em 682 ms), e não vale um índice a mais só para o
backfill, que roda uma vez.

Vira relevante se o rebalanceamento da F1.3-a passar a renumerar colunas
grandes com frequência, ou se alguma consulta do board precisar da mesma
ordenação. A F7.7 já prevê revisar o plano de query dos filtros; é ali que este
índice deve ser decidido, com `EXPLAIN` na mão.

---

## B-07 — `flow_runtime` era o único chamador do `DealMover` sem guarda de etapa igual

**Encontrado em:** F1.3 (revisão do `DealMover`)
**Severidade da revisão:** MEDIUM
**Situação:** ✅ corrigido na própria F1.3 — fica registrado porque denuncia um padrão

`Captain::FlowRuntime#execute_crm_action` chamava `Crm::DealMover` sem o
`return if deal.crm_pipeline_stage_id == target_stage.id` que os outros três
chamadores (`StageAutomation`, `LeadScoreCalculator`, `TriageFromConversation`)
já tinham. Com a F1.3, mover para a etapa atual deixou de auditar e passou a
significar "reordene" — um nó de flow revisitado reposicionaria o card em
silêncio a cada execução.

A guarda foi copiada para o quarto ponto. **A cópia é o problema**: a mesma
regra de negócio agora vive em quatro arquivos, exatamente como a B-01. A saída
certa é a guarda morar dentro do `DealMover` (ou num `Crm::DealMoveRequest`) e
os chamadores não precisarem saber dela. Fica para a F3.4, que reescreve as
ações do motor de automação e mexe em três desses quatro pontos.

---

## B-08 — Rolagem da coluna usa offset, e offset não sobrevive a reordenação

**Encontrado em:** F1.6 (paginação por coluna)
**Severidade:** MEDIUM
**Endereçado por:** F2.2 (virtualização) ou F2.10 (drag&drop de verdade)

`GET /crm/deals?stage_id=X&order=board&page=2` usa `OFFSET`. Se alguém reordenar
a coluna entre a página 1 e a página 2 — que é exatamente o que a F1.3 acabou de
tornar possível — a página 2 pula ou repete cards, porque o offset conta linhas
numa ordem que mudou.

O plano pede `page=2` e é isso que está implementado. A saída certa é um cursor
de keyset sobre `(position IS NULL, position, created_at, id)`, que não depende
de contagem de linhas. Não foi feito agora por dois motivos: nenhum cliente
consome a rolagem por coluna ainda (o board pinta os 25 primeiros e para), e o
cursor precisa tratar os negócios de `position` nula que o backfill da F1.2
ainda não alcançou — estado transitório que some depois do primeiro deploy.

Quando a F2.2 ligar a rolagem infinita de verdade, é ali que o cursor entra.

---

## B-09 — Todo evento de negócio chega ao socket de todo agente da conta

**Encontrado em:** F1.7 (realtime do board)
**Severidade:** LOW hoje, MEDIUM na escala do plano
**Endereçado por:** F7.8 (cache e invalidação por evento) ou F7.5 (latência do realtime)

O broadcast de `crm_deal.*` vai para a room `account_{id}`, e `RoomChannel` faz
`stream_from "account_#{id}"` para todo usuário da conta. Com 5.000 negócios e
vários pipelines, cada movimentação de card é entregue ao navegador de todo
agente logado — inclusive de quem está no Inbox, em Relatórios, ou num pipeline
diferente.

Não é vazamento: o `CrmDealPolicy` já permite que agentes da conta vejam os
negócios. É barulho, e cresce com o número de agentes vezes o número de
movimentações.

A saída é escopar o broadcast por pipeline (`account_{id}_pipeline_{id}`) e o
cliente assinar só o pipeline aberto. Não foi feito agora porque exigiria um
segundo canal convivendo com o atual — exatamente a duplicação que a F1.7
decidiu evitar — e porque o número que justifica a mudança só existe depois da
F7.5 medir a latência sob carga real.

---

## B-10 — Duas telas do CRM no ar ainda presumem Previdenciário

**Encontrado em:** F2.1 (a) (comparação Legacy × Operational)
**Severidade:** MEDIUM — viola a regra de produto nº 9 do plano
**Endereçado por:** F5.4 (extrair strings para `crm.json`)

Dois placeholders escritos na reescrita Operational presumem INSS:

| Arquivo | Linha | Texto |
| :--- | ---: | :--- |
| `ActivitiesOperational.vue` | 1144 | `Ex.: Retornar sobre aposentadoria` |
| `AllLeadsOperational.vue` | 613 | `Ex.: Aposentadoria por invalidez` |

Não são regressões portadas do Legacy — o Legacy nunca teve esses textos; eles
nasceram na tela nova. O terceiro caso (`PipelineSettingsOperational.vue`, "Ex.:
Atendimento previdenciário") **foi** corrigido na F2.1 (a), porque ali o Legacy
já tinha a versão certa e portar era parte da tarefa.

Estes dois ficaram fora porque `Activities` e `AllLeads` não estavam no escopo
do porte de (a), e trocar texto solto é exatamente o que a F5.4 vai fazer de uma
vez, junto com a extração para `crm.json` e o vocabulário por pipeline da F5.3.
Corrigir agora criaria uma string nova no código para ser movida daqui a pouco.

---

## B-11 — A F2.4 perdeu o componente que ia redesenhar

**Encontrado em:** F2.1 (d)
**Severidade:** informativo — muda o escopo de uma tarefa futura
**Endereçado por:** F2.4 (card redesenhado)

`CRMDealCard.vue` (685 linhas) foi apagado junto com o `CrmIndexLegacy`, porque
era renderizado só por ele (achado D-05). O board que ficou desenha os cards
**inline**, dentro do `CrmIndexOperational.vue`.

Consequência para a F2.4: não há um componente de card para redesenhar. Ou o
markup inline é extraído para um `CRMDealCard` novo antes de começar — o que
também ajuda a F2.2 (virtualização), que precisa de um item barato de montar —
ou a F2.4 redesenha inline e o board continua um arquivo único crescendo.

A recomendação é extrair primeiro. O card inline hoje é o maior bloco do
`CrmIndexOperational.vue`, e a F2.2 vai renderizá-lo milhares de vezes.

---

## B-12 — A rolagem por coluna da F1.6 ainda não tem consumidor

**Encontrado em:** F2.2
**Severidade:** MEDIUM — funcionalidade entregue e não ligada
**Endereçado por:** F2.2 (segunda parte) ou F2.10

O board agora recebe 25 cards por coluna do endpoint da F1.5. Quem tem 1.200
negócios numa coluna vê 25 e **não tem como pedir os outros**: o
`getColumnPage` que a F1.6 criou não é chamado por ninguém.

Antes disso o board carregava tudo — errado, mas completo. Agora está certo e
incompleto. O atendente que precisa de um card além dos 25 primeiros depende do
filtro ou da busca para trazê-lo.

Isso torna a rolagem infinita mais urgente do que a virtualização: virtualizar
resolve renderizar muitos; rolar resolve **alcançar** muitos. Ligar o
`getColumnPage` ao scroll da coluna é o próximo passo natural da F2.2, e é
quando o cursor de keyset da B-08 passa a valer a pena.

---

## B-13 — Corrida entre requisições do board em voo

**Encontrado em:** revisão de código do frontend (F2.2)
**Severidade:** MEDIUM
**Endereçado por:** F7 (performance) ou antes, se aparecer em produção

`loadCrm`, `changePipeline` e `applyFilters` disparam `getBoard` sem token de
sequência nem `AbortController`. Trocar de pipeline duas vezes rápido deixa duas
respostas em voo, e **vence a que chegar por último** — não a mais recente. O
seletor pode indicar um pipeline e o quadro mostrar outro.

O mesmo vale para `loadMoreInColumn`: o `Set` de deduplicação é calculado antes
do `await`; se um refresh terminar no meio, a página que chega é filtrada contra
um estado que não existe mais.

Não foi corrigido agora porque a solução certa (sequência por requisição, ou
abortar a anterior) vale para as três telas do CRM e para o `AllLeads`, e fazer
em uma só criaria um padrão pela metade. Nenhum teste força o cenário hoje.

---

## B-14 — Kanban não é operável por teclado

**Encontrado em:** revisão de código do frontend (F2.2)
**Severidade:** MEDIUM — acessibilidade
**Endereçado por:** F8.4 (acessibilidade) e F2.13 (atalhos)

O arrasto usa `vuedraggable`/SortableJS, que é só ponteiro e toque. Quem depende
de teclado **não consegue mover um card entre etapas pelo quadro** — o menu do
card tem recalcular, cliente da base e descartar, mas não "mover para etapa".
Pela lista (`AllLeadsOperational`) consegue, porque lá a etapa é um `select`.

Falta também `aria-live` para anunciar que um card mudou de coluna.

A saída mais barata é adiantar um pedaço da F2.13: uma ação "mover para etapa"
no menu do card, acessível por teclado, que reusa o mesmo `moveDeal`. Isso
resolve o bloqueio funcional sem esperar o drag&drop acessível completo da F8.4.

---

## B-15 — `DealDetailsOperational.vue` passou de 800 linhas

**Encontrado em:** revisão de código do frontend (F2.2)
**Severidade:** MEDIUM — viola a regra 6 do prompt de execução
**Endereçado por:** F2 (quando a ficha for mexida de novo)

Está com 1.014 linhas. O board foi quebrado em `CRMBoardColumn` e `CRMDealCard`
quando cruzou o limite; a ficha não foi, porque a F2.1 (b) só portou o descarte
e não tinha motivo para reestruturá-la.

Candidatos naturais a sair: o bloco de descarte/disposição, a aba de auditoria e
o formulário de atividade nova.

---

## B-16 — Nove dos doze critérios de filtro não têm controle na interface

**Encontrado em:** F2.6
**Severidade:** MEDIUM — funcionalidade entregue e parcialmente inalcançável
**Endereçado por:** F2.7 (visões salvas)

`crmBoardFilters.js` traduz os 12 critérios da F1.4 e `CRMFilterPills` mostra e
remove qualquer um deles. Mas o toolbar do board só oferece **três** controles:
busca, responsável e faixa de score.

Os outros nove — etapa, etiqueta, situação operacional, modo da IA, faixa de
valor, janela de criação, `stale`, `has_pending_activity` — só entram por query
string. Quem souber montar a URL alcança; quem não souber, não.

Não construí os nove controles agora por duas razões. Primeira: um popover de
filtro com nove critérios é uma tela em si, e a F2.7 (visões salvas) vai querer
exatamente essa tela para montar e salvar uma visão — construir agora significa
construir duas vezes. Segunda: o critério mais valioso dos nove
(`has_pending_activity: false`, que responde a meta de <10%) já vai virar uma
visão pronta na F2.7, e é assim que o atendente deve alcançá-lo — não montando
filtro à mão todo dia.

---

## B-17 — `window.prompt` e `window.confirm` no menu de visões

**Encontrado em:** F2.7
**Severidade:** LOW
**Endereçado por:** F2.15 (estados vazios e de erro desenhados) ou antes

Salvar uma visão pede o nome com `window.prompt`; apagar confirma com
`window.confirm`. Funciona, mas destoa do resto do CRM, que já usa `DsModal`
(descarte, marcar perdido) e `CRMConfirmDialog`.

Deixei assim de propósito nesta tarefa: o valor da F2.7 é a visão salva
funcionar de ponta a ponta, e trocar dois diálogos nativos por modais é
trabalho de acabamento que a F2.15 vai fazer em bloco, junto com os estados
vazios e de erro. Trocar agora significaria dois modais novos antes de decidir
o padrão da fase.

Nota: `AgendaLegacy` tinha exatamente essa migração feita (`window.confirm` →
`CRMConfirmDialog`) e ela se perdeu quando o arquivo foi apagado na F2.1 (a) —
o Operational já usava o dialog. Vale conferir se sobrou algum `window.confirm`
no módulo quando a F2.15 chegar.

---

## B-18 — `column_cards` faz uma query por coluna

**Encontrado em:** F2.8 (revisão)
**Severidade:** MEDIUM
**Endereçado por:** ainda sem tarefa

`Crm::BoardGrouping` deu ao board um agrupamento por responsável, faixa de
score, área, origem e situação. Os **agregados** (contagem, soma, WIP) saem de
uma única query com `GROUP BY`. Os **cards**, não: `column_cards` roda um
`SELECT ... LIMIT 25` por balde. Agrupado por etapa isso já era assim desde a
F1.5 — cinco ou seis etapas, cinco ou seis queries. Agrupado por responsável, é
uma query por usuário da conta.

O caminho conhecido é uma query só, com
`ROW_NUMBER() OVER (PARTITION BY <key_sql> ORDER BY position)` e um corte em 25.
Não fiz agora por dois motivos: o plano não cita essa otimização (regra de
não refatorar o que ele não pede), e o número que decide — quanto isso custa
com 5.000 negócios e 20 responsáveis — ainda não foi medido. A baseline da F0.3
não cobre agrupamento.

**O que mediria antes de mexer:** `GET /crm/deals/board?group_by=owner` num
dump com 5.000 negócios e todos os responsáveis reais, comparado com
`group_by=stage`. Se a diferença couber no orçamento de 300ms do p95, isto pode
ficar como está.

---

## B-19 — `deals_controller.rb` passou de 800 linhas

**Encontrado em:** F2.8 (revisão)
**Severidade:** LOW
**Endereçado por:** ainda sem tarefa

860 linhas, contra o teto de 800 da regra 6. Era 722 em `main`; a F1.5 (board),
a F1.6 (paginação por coluna) e a F2.8 (agrupamento) somaram o resto. As funções
em si estão pequenas (nenhuma passa de 25 linhas) — o que cresceu foi a
quantidade delas.

O corte natural é um objeto de resposta do board (`Crm::BoardResponse` ou um
serializador), levando junto `column_aggregates`, `column_cards`,
`serialize_grouped_cards` e `serialize_column`. São ~90 linhas, e resolveria
B-18 no mesmo lugar.

Na F2.8 a página `CrmIndexOperational.vue` teve o mesmo problema (1.071 linhas)
e foi quebrada em `CRMBoardToolbar.vue`, `CRMCreateDealDrawer.vue`,
`useBoardViews`, `useBoardCards`, `useBoardDensity` e `useBoardDealActions`. O
controller ficou para depois porque quebrá-lo no mesmo passo teria misturado a
extração com a mudança de contrato do agrupamento, e a revisão precisava
conseguir ler as duas coisas separadas.
