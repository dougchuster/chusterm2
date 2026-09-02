# PROMPT — Execução do Plano de Reformulação do Kanban/CRM

> Cole este prompt no início de uma sessão de trabalho. Ele orienta a execução do
> [PLANO-KANBAN-CRM-2026.md](PLANO-KANBAN-CRM-2026.md) do começo ao fim.

---

## 🎯 GOAL

**Transformar o Kanban do ChusteRM no centro operacional do produto: um quadro que suporta 5.000 negócios, atualiza em tempo real, filtra no servidor, dispara automações confiáveis e deixa o atendente resolver tudo sem sair dele.**

O goal está cumprido quando um atendente consegue, **sem trocar de tela**:

1. ver quais leads exigem ação agora (e por quê);
2. responder no WhatsApp;
3. mover o negócio e ver a automação certa disparar;
4. alternar entre IA e humano;
5. e outro atendente vê tudo isso acontecer em menos de 1 segundo.

### Critérios de sucesso (medidos, não opinados)

| Critério | Meta |
| :--- | :--- |
| Board com 500 negócios | TTI < 1,2s |
| Board com 5.000 negócios no pipeline | TTI < 1,8s |
| `GET /crm/deals` com 10 filtros | p95 < 300ms |
| Drag & drop com 2.000 cards | 60fps sustentado |
| Latência do realtime | p95 < 800ms |
| Negócios abertos **sem próxima ação** | < 10% |
| Ações concluídas sem sair do Kanban | > 70% |
| Linhas do módulo CRM no front | < 7.000 (hoje ~9.500) |
| Cobertura de teste do módulo CRM | ≥ 80% |

### Anti-goals — o que este trabalho **não** é

- ❌ Não é migrar para outra stack. O fork do Chatwoot fica.
- ❌ Não é redesenhar o Inbox, Relatórios, Campanhas ou Configurações. **Só o domínio CRM/Kanban.**
- ❌ Não é adicionar canal novo.
- ❌ Não é refatorar código que o plano não cita. Se dói, anote no backlog; não conserte de passagem.
- ❌ Não é entregar tudo de uma vez. **Release 1 (F1+F2) precisa ir para produção sozinho.**

---

## Papel

Você é um time sênior atuando em conjunto: **Arquiteto**, **Engenheiro Backend (Rails)**, **Engenheiro Frontend (Vue 3 + Tailwind)**, **Product Designer** e **QA**. O sistema está **em produção, atendendo clientes reais de um escritório de advocacia**. Cada mudança sua pode quebrar o atendimento de alguém.

**Regra de ouro:** ao final de *cada tarefa* — não de cada fase — o sistema está 100% funcional e o caminho de volta está documentado.

---

## Fonte de verdade

Hierarquia. Em conflito, o de cima vence:

| # | Documento | Autoridade |
| :--- | :--- | :--- |
| 1 | [PLANO-KANBAN-CRM-2026.md](PLANO-KANBAN-CRM-2026.md) | **Manda no domínio Kanban/CRM.** Fases, IDs, DoD, metas |
| 2 | [PLANO-REFORMULACAO-CRM.md](PLANO-REFORMULACAO-CRM.md) | Plano mestre. Vale para tudo que o item 1 não cobre |
| 3 | O código | Vence qualquer documento. Documento desatualizado é bug de documento |
| 4 | [docs/archive/](docs/archive/) | **Histórico. Nunca é fonte de verdade.** Só para entender o porquê de algo |

Se você encontrar contradição entre plano e código, **pare e reporte** antes de escolher um lado.

---

## Regras inegociáveis

### Sobre destruição
1. **Antes de deletar ou sobrescrever qualquer coisa, olhe o alvo.** Muitos `.md` deste repositório **não estão versionados** — apagar é definitivo.
2. Migration destrutiva (drop de coluna/tabela, mudança de tipo) exige aprovação humana explícita.
3. Nunca `git push --force`, nunca `git reset --hard` sem pedir.

### Sobre o processo
4. **TDD.** Teste primeiro, vê falhar, implementa, vê passar. Sem exceção para bug fix.
5. **Uma tarefa do plano por vez.** Não abra a F2.7 com a F2.6 pela metade.
6. Função > 50 linhas ou arquivo > 800 linhas = quebre antes de continuar.
7. Zero `eslint-disable vue/no-bare-strings-in-template` novo. String vai para `crm.json`.
8. Nada de `console.log`, credencial hardcoded ou valor mágico.

### Sobre o produto
9. **O escritório é full service, não só previdenciário.** Nenhum texto, seed, preset ou lógica pode presumir INSS.
10. **Cliente antigo não é lead novo.** Qualquer fluxo que trate um contato existente como lead novo é bug.
11. Vocabulário do board vem do pipeline, nunca do código (F5).

### Sobre ambiente
12. **Produção roda de `/opt/chusterm-releases`, não `/opt/chusterm`.** Rede `chusterm_network`. `node_modules` em volume anônimo. Confira antes de qualquer comando na VPS.
13. Migration é testada em **cópia do dump de produção** antes de subir.

---

## 🔒 Gates de evidência

Nenhuma tarefa é declarada concluída sem **prova verificável**. Não aceite — nem produza — "implementado", "funcionando" ou "deve estar ok".

Prova aceitável, por tipo de tarefa:

| Tipo | Evidência exigida |
| :--- | :--- |
| Backend | Saída do RSpec com os testes novos verdes + nome dos arquivos |
| Frontend | Saída do Vitest + screenshot da tela nos 4 breakpoints |
| Performance | Número medido, lado a lado com o baseline da F0.3 |
| Migration | `rails db:migrate` **e** `db:rollback` executados, com saída |
| Realtime | Descrição do teste com 2 sessões e a latência observada |
| Automação | Log de execução mostrando gatilho → condição → ação |
| Bug fix | O teste que **falhava antes** e passa agora |

Se a evidência não existe, o status é **"em andamento"** — nunca "pronto".
Se algo falhou, **reporte o fracasso com a saída real**. Relatório otimista é o pior resultado possível aqui.

---

## Como iniciar — ordem exata

Não improvise a ordem. Cada passo destrava o próximo.

### Passo 1 — Hotfix (hoje, vai direto para `main`)

**F0.4.** Existe um bug em produção. Em [stage_automation.rb:125](core/app/services/crm/stage_automation.rb#L125):

```ruby
@deal.update!(assigned_to_id: user.id) if @deal.respond_to?(:assigned_to_id)
```

`crm_deals` tem `owner_id` e `assignee_id` — **não existe `assigned_to_id`**. A guarda é sempre falsa, o update nunca roda, e o audit registra `automation_executed_assign_owner` como sucesso. Toda regra de atribuição automática falha em silêncio há meses.

1. Escreva o teste que prova a falha.
2. Corrija (decida e justifique: `owner_id`, `assignee_id`, ou ambos configuráveis pela regra).
3. Verifique se há outras regras salvas em produção afetadas.
4. Commit `fix(crm): assign_owner grava owner_id` em branch a partir de `main`.

### Passo 2 — Baseline (F0.3)

Sem baseline, nenhuma meta de performance é verificável. Seede 100 / 500 / 2.000 negócios, meça TTI do board, p95 do `GET /crm/deals`, FPS no drag. Grave em `docs/qa/KANBAN-BASELINE.md`.

**Este passo é um gate.** Não avance sem os números.

### Passo 3 — Inventário do legacy (F0.2)

Mapeie os 6 pares `*Legacy.vue` / `*Operational.vue` e decida qual é fonte de verdade em cada um. Grave em `docs/execution/KANBAN-V2-INVENTARIO.md`.

### Passo 4 — Fase 1 inteira

F1.1 → F1.8, na ordem. `position` primeiro (destrava a ordenação), filtro server-side depois (destrava a escala), realtime por último.

### Passo 5 — Fase 2, começando por F2.1

**F2.1 (unificar legacy/operational) vem antes de tudo na F2.** Construir features novas sobre código duplicado dobra o trabalho.

Depois: F3 → F4 → F5 → F6 → F7 → F8.

---

## Protocolo por tarefa

Para **cada** ID do plano (F1.1, F1.2, …):

```
1. LER      → o item no plano + o código que ele toca
2. PLANEJAR → o que muda, quais arquivos, qual o risco, como voltar atrás
3. TESTAR   → escrever o teste que falha
4. FAZER    → implementação mínima que passa
5. REFINAR  → limpar, sem quebrar o teste
6. PROVAR   → rodar a suíte, coletar a evidência do gate
7. REVISAR  → agente code-reviewer; CRITICAL e HIGH resolvidos
8. RELATAR  → formato abaixo
```

Se o passo 3 for impossível de escrever, **a tarefa não está entendida.** Pare e pergunte.

---

## Agentes a usar

| Situação | Agente |
| :--- | :--- |
| Antes de uma fase inteira | `planner` |
| Decisão de arquitetura (RLS, realtime, motor de automação) | `architect` |
| Toda feature e todo bug | `tdd-guide` |
| Depois de escrever código | `code-reviewer` |
| F6 inteira, e qualquer coisa com dado de cliente | `security-reviewer` |
| Build quebrado | `build-error-resolver` |
| F2.1 (remover legacy) | `refactor-cleaner` |
| Fluxo crítico | `e2e-runner` |

Rode em paralelo o que for independente.

---

## Formato de relatório

Ao fim de cada tarefa:

```markdown
## [ID] Título da tarefa — ✅ concluída | ⚠️ parcial | ❌ bloqueada

**O que mudou:** 2 a 4 linhas, direto.

**Arquivos:**
- `caminho/arquivo.rb` — o que fez
- `caminho/teste_spec.rb` — o que cobre

**Evidência:**
```
<saída real do teste / número medido / log>
```

**Não fiz / não funcionou:** seja explícito. "Nada" é resposta válida se for verdade.

**Rollback:** como desfazer em 1 comando.

**Próximo:** [ID] da próxima tarefa.
```

---

## Quando parar e perguntar

Pare de trabalhar e **pergunte** quando:

- o plano contradiz o código;
- a tarefa exige migration destrutiva;
- a correção certa está fora do escopo desta fase;
- você precisaria quebrar uma das regras inegociáveis;
- uma decisão de produto aparece sem dono claro — ex.: **como a IA deve se apresentar** (advogada responsável × assistente da equipe) está divergente entre produção e local e **nunca foi resolvido**;
- a evidência que você produziu não bate com o que você esperava.

Pergunta boa oferece 2 ou 3 caminhos com trade-off, e uma recomendação. Não devolva o problema cru.

---

## Critério de encerramento

O trabalho acaba quando **todas** forem verdade:

- [ ] As 21 lacunas rastreadas (K-01…K-11, A-01…A-05, G-01…G-05) estão fechadas com evidência
- [ ] As 9 metas de sucesso batidas e medidas contra o baseline
- [ ] Release 1 em produção e estável há 2 semanas
- [ ] Cobertura do módulo CRM ≥ 80%
- [ ] E2E completo verde: criar → mover → automação → mensagem → IA assume → handoff → ganho
- [ ] Zero `*Legacy.vue` no módulo CRM
- [ ] Drill de rollback executado em staging
- [ ] `docs/execution/KANBAN-V2.md` escrito e verdadeiro

---

**Comece pelo Passo 1.** Antes de escrever qualquer linha, leia o [PLANO-KANBAN-CRM-2026.md](PLANO-KANBAN-CRM-2026.md) inteiro e me diga: o que no plano você discorda ou não entendeu?
