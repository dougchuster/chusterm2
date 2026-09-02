# F3D — piloto de redesign do CRM Index/Kanban

**Data:** 2026-07-14  
**Status:** 🟢 primeira fatia validada; gate completo da F3D permanece aberto  
**Ambiente:** Docker Compose, conta fixture A, tema claro

## Resultado entregue

A tela principal do CRM foi reorganizada como centro de comando comercial,
preservando contratos, dados, paginação, drag-and-drop, drawers e operações já
existentes.

- cabeçalho com contexto, pipeline ativo, estado de sincronização e ações
  priorizadas;
- Central de IA como ação principal, Métricas como ação secundária e tarefas
  administrativas em menu de baixa frequência;
- busca e filtros em uma faixa compacta, com contagem e limpeza explícitas;
- quatro KPIs essenciais sempre visíveis e saúde operacional sob demanda;
- tarefas próximas mantidas no contexto do pipeline;
- Kanban com valor total, contagem, probabilidade e automações por etapa;
- cards com ação primária “Atender”, atalhos úteis e ações perigosas em menu;
- skeleton de carregamento e estados de erro/vazio preservados;
- layout mobile com KPIs em duas colunas, filtros legíveis e accordion de etapas;
- remoção de `backdrop-filter` e sombras pesadas da tela operacional, reduzindo
  custo de composição e eliminando o artefato escuro observado nas capturas.

## Arquivos da fatia

- `core/app/javascript/dashboard/routes/dashboard/crm/pages/CrmIndex.vue`
- `core/app/javascript/dashboard/components/crm/CRMDealCard.vue`
- `qa/e2e/tests/crm-redesign.spec.ts`

## Evidências executadas

| Verificação                                          | Resultado                      |
| ---------------------------------------------------- | ------------------------------ |
| ESLint dos componentes alterados                     | aprovado                       |
| Prettier dos componentes alterados                   | aprovado                       |
| Vitest CRM (paginação, dinheiro, resultado e drawer) | 19/19                          |
| build Vite de produção                               | 4.547 módulos; aprovado        |
| hierarquia, teclado e responsividade Playwright      | 10/10 em cinco viewports       |
| Axe critical/serious                                 | 0 violações em cinco viewports |
| rodada combinada final                               | 15/15                          |
| revalidação após refinamento mobile                  | 6/6 em desktop e 360×800       |

Viewports validados: `360×800`, `768×1024`, `1024×768`, `1366×768` e
`1920×1080`.

## Decisões de UX aplicadas

1. Informação recorrente fica visível; configuração e manutenção ficam em
   menus contextuais.
2. A tela mostra quatro indicadores prioritários e revela diagnósticos apenas
   quando solicitados.
3. Ações destrutivas deixam de competir visualmente com o atendimento.
4. O board continua horizontal no desktop e vira navegação vertical sem drag no
   mobile.
5. Superfícies sólidas substituem vidro/desfoque em uma tela de uso prolongado.
6. O teclado `/` foca a busca e `Escape` limpa o termo sem exigir mouse.

## Pendências para concluir a F3D

- tema escuro e regressão visual versionada;
- Firefox e WebKit na suíte específica desta fatia;
- tabela/lista equivalente ao Kanban;
- views salvas, deep links completos e alternativa acessível de movimentação no
  desktop;
- reconciliação financeira entre board, lista, relatório e exportação;
- carga e medição com 1.000 deals;
- telemetria de uso e performance;
- UAT com vendedor, operador e gestor;
- redesign das telas de detalhe, métricas, automações, cadências, agenda e
  configurações do CRM;
- gates de tenancy, RBAC e jornada composta ainda pertencentes à F0.

## Operação local

O serviço contínuo `core-vite` permanece desligado. A validação usa build
pontual de produção para evitar o consumo elevado de CPU e memória já observado.
