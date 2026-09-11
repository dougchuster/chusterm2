# Plano Mestre de Reformulação de UI/UX e Roadmap de Experiência do Usuário — ChusteRM

**Versão:** 1.0 — Master Plan  
**Data:** Agosto de 2026  
**Status:** Histórico; sucedido pelo plano Obsidian + Mineral aprovado em `docs/design/reformulacao-2026-09/PLANO.md`
**Documentos Relacionados:** `docs/PLANO-DESIGN-SYSTEM-2026.md`, `core/AGENTS.md`, `.github/skills/chusterm-ui-redesign/references/design-brief.md`

---

## 1. Sumário Executivo & Visão de Produto

### 1.1 Visão Estratégica

O **ChusteRM** nasceu da integração pioneira entre atendimento multicanal conversacional (baseado no motor do Chatwoot) e um CRM de vendas operacional e ágil. O objetivo estratégico desta reformulação de UI/UX é consolidar o ChusteRM como uma **referência global em velocidade, elegância e facilidade de uso** para equipes de vendas e atendimento de alta performance.

Inspirado pelos produtos mais admirados do mundo — a agilidade sub-50ms e fluidez keyboard-first do **Linear**, a flexibilidade de dados e estética editorial do **Attio**, a ergonomia de contatos e simplicidade do **Folk**, e o cockpit integrado de comunicação do **Close** —, o ChusteRM deixará de ser uma justaposição de módulos legados para se tornar um **espaço de trabalho coeso, hiper-rápido e intuitivo**.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             CHUSTERM UX NORTH STAR                               │
├───────────────────┬───────────────────┬───────────────────┬──────────────────────┤
│    VELOCIDADE     │  KEYBOARD-FIRST   │  DADOS REATIVOS   │   OMNICHANNEL REAL   │
│  Interações <50ms │    Cmd+K Global   │ Inline Editing em │ Atendimento & Vendas │
│   Optimistic UI   │ Atalhos Unificados│  Grade Virtual    │  em Cockpit Único    │
└───────────────────┴───────────────────┴───────────────────┴──────────────────────┘
```

### 1.2 Metas de Experiência do Usuário (UX Goals)

1. **Velocidade Percebida Sub-50ms:** Toda ação comum (abrir conversa, trocar etapa de funil, editar campo, aplicar filtro) deve ter resposta visual instantânea via _Optimistic UI_ e cache inteligente.
2. **Operação 100% Keyboard-First:** Qualquer vendedor ou agente deve conseguir navegar, buscar e executar rotinas críticas sem tocar no mouse, através de uma Paleta de Comandos unificada (`Cmd+K` / `Ctrl+K`) e atalhos mnemônicos universais.
3. **Ergonomia Sem Fricção (Zero Full-Page Reloads):** Adoção de painéis contextuais deslizantes (_Peek Drawers_) e edição inline para contatos, negócios e empresas, mantendo o usuário sempre no contexto da tarefa.
4. **Identidade Visual Icônica (Midnight Indigo / Nocturnal Architect):** Eliminar as três gerações de UI conflitantes no código e estabelecer uma linguagem visual editorial escura, sofisticada, com profundidade tonal, micro-interações táteis e tipografia equilibrada (Manrope + Inter).
5. **Automação e Configuração Acessíveis:** Substituir formulários lineares monolíticos e sobrecarregados por um construtor visual de fluxos baseado em nós e um centro de configurações intuitivo e pesquisável.

---

## 2. Matriz Comparativa de Benchmarks Globais

A tabela abaixo sintetiza a análise aprofundada dos líderes mundiais em design de software B2B e produtividade, contrastando suas melhores práticas com o estado atual e a meta do ChusteRM.

| Critério de Avaliação              | ChusteRM (Estado Atual)                                           | Attio                                                            | Folk                                                   | Linear                                                    | HubSpot                                        | Pipedrive                                              | Close CRM                                       | ChusteRM (Meta do Plano Mestre)                                      |
| ---------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------ | --------------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------ | ----------------------------------------------- | -------------------------------------------------------------------- |
| **Velocidade & Latência de UI**    | Média (200ms–800ms em trocas de rota; recarregamentos pontuais)   | Excepcional (<30ms, sincronização reativa contínua)              | Alta (<80ms, transições suaves)                        | Referência mundial (<50ms, Optimistic UI puro)            | Baixa (lento, múltiplos spinners e reloads)    | Média (animações fluidas, mas trocas pesadas)          | Alta (focado em execução rápida de chamadas)    | **Referência (<50ms com Optimistic UI e prefetching)**               |
| **Navegação & Atalhos de Teclado** | Parcial (Ninja-keys isolado; atalhos Alt+J/K instáveis)           | Excelente (Cmd+K universal + navegação por setas/Tab)            | Boa (Cmd+K para busca e criação rápida)                | Referência mundial (Vim-style, Cmd+K, triagem pura)       | Pobre (navegação tradicional por cliques)      | Regular (atalhos limitados a poucas telas)             | Alta (atalhos para discagem, e-mail e notas)    | **Universal (Cmd+K unificado + J/K/E/R no Inbox e Kanban)**          |
| **Manipulação de Dados & Grids**   | Básica (Tabela HTML estática sem inline edit nem dynamic columns) | Referência mundial (Planilha de alta densidade, filtros ao vivo) | Excelente (Visual estilo Notion, grouping flexível)    | Excelente (Listas virtuais ultrarrápidas, inline actions) | Média (tabelas densas, mas edição em modal)    | Básica (foco em Kanban, lista secundária)              | Regular (listas de leads tradicionais)          | **Planilha Dinâmica (TanStack Table + Virtualização + Inline Edit)** |
| **Visualização de Pipelines**      | Boa no Kanban CRM (`CrmIndexOperational`), mas isolada            | Avançada (Kanban + Lista + Galeria em 1 clique)                  | Avançada (Tabela com agrupamento em colunas)           | Referência (Boards com métricas, SLAs e filtros)          | Complexa (muitos dados, visual sobrecarregado) | Referência histórica (Kanban intuitivo + deal rotting) | Focada em métricas de contato e discagem        | **Híbrida (Tabela / Kanban / Timeline + SLA + Deal Rotting)**        |
| **Cockpit de Comunicação / Inbox** | Forte em WhatsApp, mas com fricção no composer e notas            | Foco em e-mail/timeline relacional                               | Foco em e-mail/LinkedIn e listas de contatos           | Focado em issues/tickets (Inbox triaging ágil)            | Omnichannel pesado, carregamento lento         | E-mail sincronizado integrado ao deal                  | Referência em discagem + SMS + E-mail integrado | **Cockpit Integrado (WhatsApp + Chat + E-mail + Notas unificadas)**  |
| **Construtor de Automações**       | Básico/Monolítico (Formulário modal longo >1100 linhas)           | Referência (Workflows visuais em nós com lógica pura)            | Automações simples baseadas em gatilhos                | Workflows focados em regras de ciclo de vida              | Extremamente poderoso, porém curva íngreme     | Automações sequenciais passo a passo                   | Automações de cadência e discagem               | **Visual Node-based (Gatilho → Condição → Ação + Live Test)**        |
| **Onboarding & Ativação (FTUE)**   | Sem checklist interativo; telas vazias sem guia                   | Excelente (Template gallery, dados de amostra)                   | Excelente (Importação mágica e onboarding em 3 passos) | Referência (Guia de primeiros passos embutido na UI)      | Pesado (tours invasivos com muitos tooltips)   | Muito bom (guia visual passo a passo)                  | Direto ao ponto (setup de canais de voz/email)  | **Interativo (Checklist com progresso + Mock Data playground)**      |

---

### 2.1 Os 10 Padrões de Ouro (Must-Have UI/UX Patterns) para o ChusteRM

1. **Universal Command Palette (`Cmd+K` / `Ctrl+K`):** Busca global contextual que indexa contatos, negócios, conversas, configurações, comandos do sistema e ações rápidas com navegação por teclado.
2. **High-Density Spreadsheet-Grade Grid:** Tabela de dados com edição inline direta na célula (clicar e editar ou navegar via setas e Tab), redimensionamento de colunas, ordenação multi-coluna e virtualização para suportar milhares de registros sem engasgos.
3. **Visualizações Híbridas Coesivas (Hybrid View Switcher):** Alternância instantânea e sem perda de filtros entre visualizações de **Tabela**, **Kanban**, **Calendário** e **Timeline**.
4. **Optimistic UI com Sub-50ms Perception:** Mudanças de estado (mover card no funil, marcar tarefa como concluída, enviar mensagem) refletem na tela imediatamente antes da resposta do servidor.
5. **Contextual Peek Drawer (Slide-Over 360°):** Inspeção de contatos, empresas e negócios através de uma gaveta lateral fluida, sem desmontar a lista ou o kanban de fundo.
6. **Omnichannel Communication Cockpit:** Painel de conversa unificado com histórico de WhatsApp, e-mail, notas internas, chamadas de voz e atalhos rápidos de respostas (`/` slash commands).
7. **Node-Based Visual Workflow Builder:** Construtor visual de automações no padrão _drag-and-drop_ com blocos de Gatilho, Condição e Ação, acompanhado de simulador de teste em tempo real.
8. **Keyboard-First Navigation (Vim/Superhuman Standard):** Navegação entre conversas com `J`/`K`, arquivamento/resolução com `E`, resposta rápida com `R`, criação com `C` e foco de busca com `/`.
9. **Ambient / In-Context AI Assistance:** IA nativa no compositor de mensagens (resumo de histórico longo, refinamento de tom, sugestão de próxima ação e preenchimento de campos de negócios).
10. **Interactive Activation Onboarding (FTUE):** Checklist persistente e recolhível com barra de progresso, orientando o usuário em sua primeira ativação (conectar WhatsApp, importar base, criar funil) e permitindo habilitar dados de demonstração (_mock data_) para explorar o sistema.

---

## 3. Diagnóstico Profundo da Base de Código e Interface

A auditoria transversal realizada nas camadas de frontend, design system e rotas do ChusteRM revelou contrastes expressivos entre fundações arquiteturais sólidas e dívidas técnicas pontuais.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   DIAGNÓSTICO ARQUITETURAL DE UI (3 GERAÇÕES)                   │
├──────────────────────────────────────────────────────────────────────────────────┤
│ [1] GERAÇÃO MODERNA (Ds* + PageTemplates): 17 componentes base, tokens semânticos│
│     Adotada com sucesso nas rotas operacionais do CRM (*Operational.vue).        │
│                                                                                  │
│ [2] GERAÇÃO INTERMEDIÁRIA (components-next): Módulos herdados upstream.          │
│     Estruturalmente aceitáveis, mas com inconsistências de estilo e i18n.        │
│                                                                                  │
│ [3] GERAÇÃO LEGADA (Ad-hoc Scoped CSS): Páginas monolíticas (>1000 linhas),      │
│     cores hex hardcoded, inputs nativos e acoplamento rígido ao DOM.             │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 Pontos Fortes e Diferenciais a Preservar

- **Fundação de Tokens Semânticos e Primitivos `Ds*`:** Existência de 17 componentes atômicos (`DsButton`, `DsInput`, `DsSelect`, `DsModal`, `DsDrawer`, `DsTable`, `DsCard`, etc.) e 6 templates estruturais (`ListPageTemplate`, `BoardPageTemplate`, `ConversationPageTemplate`, `RecordPageTemplate`, `CalendarPageTemplate`, `SettingsPageTemplate`).
- **Motor Multicanal Robusto:** Suporte maduro a canais de WhatsApp (Evolution API, Baileys, Cloud API), LiveChat, E-mail e Webhooks.
- **Kanban Operacional Integrado (`CrmIndexOperational.vue`):** Módulo de CRM com recursos avançados de drag-and-drop, drawer de conversa direto no card de negócio e filtros dinâmicos de pipeline.
- **Eliminação de Camadas Globais Tóxicas:** A remoção completa do antigo `chusterm-theme.css` (que continha centenas de `!important`) abriu espaço para uma estilização 100% utilitária via Tailwind.

---

### 3.2 Diagnóstico de Gargalos Críticos por Domínio

#### A. Navegação, Layout Global e Design System

- **Desconexão entre Buscas:** A barra de busca na sidebar superior e o componente `CommandBar.vue` (`@ChusteRM/ninja-keys`) operam de forma dissociada. O usuário não sabe quando usar a busca visual ou o atalho de teclado.
- **Defasagem da Paleta de Comandos:** O CommandBar atual possui atalhos focados apenas em ações de conversa e snooze, não cobrindo rotas vitais do CRM (Leads, Pipelines, Negócios, Relatórios, Automações e Cadências).
- **Sobrecarga Cognitiva na Sidebar:** Mais de 19 itens de navegação listados de forma plana, sem agrupamento colapsável por domínio (Atendimento, Vendas/CRM, Automação, Configurações) e sem suporte a fixação de favoritos (_pinning_).
- **Fragmentação Visual de Superfícies:** Coexistência das 3 gerações de UI; telas centrais como Contatos e visualizadores de histórico ainda utilizam elementos HTML nativos (`<select>`, `<textarea>`) fora do padrão do design system.

#### B. Contatos, Empresas e Pipelines

- **Tabela de Contatos Estática (`ContactManageView.vue`):** Renderização em HTML simples sem recursos modernos de planilha: ausência de ordenação multi-coluna, colunas redimensionáveis, fixação de colunas (_sticky_), virtualização e seleção em massa ergonômica.
- **Falta de Edição Inline:** Para alterar o e-mail, telefone, empresa ou campo customizado de um contato, o usuário é forçado a abrir um modal ou navegar para outra tela, quebrando o ritmo de trabalho.
- **Visualizador de Empresas Incompleto (`CompaniesListLayout.vue`):** Exibição em cards estáticos sem uma visão 360° detalhada (negócios associados, histórico de conversas consolidadas, contatos vinculados).
- **Pipelines sem Visão Híbrida e Métricas de Etapa:** O módulo CRM opera quase exclusivamente em visualização Kanban. Faltam:
  - Alternador para modo Tabela (essencial para triagem rápida em massa);
  - Indicadores de _Deal Rotting_ (alertas visuais para negócios estagnados há mais de X dias);
  - Métricas consolidadas no cabeçalho das etapas (valor ponderado, quantidade de negócios, tempo médio na etapa).

#### C. Inbox e Gestão de Conversas

- **Navegação por Teclado Acoplada ao DOM:** Atalhos como `Alt+J` e `Alt+K` dependem de elementos visuais renderizados e quebram frequentemente quando a lista de conversas faz scroll ou sofre re-render.
- **Atrito no Compositor de Mensagens:**
  - O menu de respostas rápidas (`/` slash command) apresenta lentidão e falta de _fuzzy search_ imediata;
  - Bloqueio artificial do uso de macros e templates em notas privadas internas;
  - Falta de _Optimistic UI_ no envio de anexos e áudios (o usuário fica travado aguardando o upload).
- **Duplicidade no Modelo Mental de Notas:** Confusão entre notas da conversa (específicas daquele atendimento) e notas do contato/lead (histórico permanente de relacionamento no CRM).

#### D. Configurações, Automações e Relatórios

- **Monólito em `AutomationRules.vue` (>1100 linhas):** Formulário modal longo, repleto de `<select>` nativos e validações complexas em cascata. Alta sobrecarga cognitiva e impossibilidade de visualizar ramificações condicionais.
- **Silos de Automação:** Separação rígida entre regras de atendimento/chat (`automation_rules`) e regras de CRM (`crm_automation_rules`), obrigando o usuário a configurar a mesma lógica em dois lugares distintos.
- **Configurações Planas e Desordenadas:** 19 submenus de configurações sem hierarquia clara, sem categorização lógica e sem busca interna indexada ao `Cmd+K`.
- **Relatórios Desconectados:** Métricas de CSAT, tempo de primeira resposta (FRT) e SLA residem em `Reports.vue`, enquanto volume de vendas e conversão de funil ficam em `CrmMetrics.vue`, sem um painel executivo unificado.
- **Ausência de Onboarding Interativo (FTUE):** Primeiros acessos caem em telas vazias estáticas sem orientação, tornando a conexão de instâncias de WhatsApp (Evolution API) e a criação do primeiro funil barreiras de adoção.

---

## 4. Diretrizes de Arquitetura de Design & Usabilidade

Para assegurar uma experiência de software que compita de igual para igual com os melhores produtos do Vale do Silício, o ChusteRM adotará os seguintes princípios de design e interação:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│             LINGUAGEM VISUAL: MIDNIGHT INDIGO / NOCTURNAL ARCHITECT              │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Canvas Profundo: #060e20 │ Camada de Superfície: #0b132b │ Card Elevado: #111c44 │
│ Ação Principal: #6366F1  │ Acento Primário: #bdc2ff      │ Acento Secundário: #c890ff│
│ Tipografia: Manrope (Headlines & Números KPI) + Inter (Corpo de Texto & Tabelas)  │
│ Filosofia de Superfícies: Glassmorphism sutil, bordas translúcidas e glow focado │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Princípios Visuais e Tokens Semânticos

1. **Separação Tonal e Profundidade em Camadas:**

   - Evitar bordas sólidas pretas ou cinzas duras. A separação entre sidebar, lista, viewport principal e drawer ocorre por transição tonal (`#060e20` → `#0b132b` → `#111c44`) e bordas translúcidas (`border-white/5` a `border-white/10`).
   - Aplicação controlada de _Glassmorphism_ (`backdrop-blur-md bg-slate-900/80`) em barras de ação flutuantes, cabeçalhos fixos e menus de contexto.

2. **Tipografia de Alta Precisão:**

   - **Manrope (Bold/SemiBold):** Utilizada exclusivamente em títulos de páginas, nomes de etapas, indicadores de métricas (KPIs) e cabeçalhos de modais.
   - **Inter (Regular/Medium):** Utilizada em corpo de mensagens, tabelas de dados de alta densidade, formulários e badges.

3. **Mapa de Tokens Semânticos (`_design-tokens.scss` & `tokens.js`):**

```scss
// Contrato de Tokens Midnight Indigo
:root {
  --ds-bg-canvas: #060e20;
  --ds-bg-surface: #0b132b;
  --ds-bg-elevated: #111c44;
  --ds-bg-hover: rgba(255, 255, 255, 0.04);
  --ds-bg-active: rgba(99, 102, 241, 0.12);

  --ds-text-primary: #f8fafc;
  --ds-text-secondary: #94a3b8;
  --ds-text-muted: #64748b;
  --ds-text-accent: #bdc2ff;

  --ds-border-subtle: rgba(255, 255, 255, 0.08);
  --ds-border-focus: #6366f1;

  --ds-accent-primary: #6366f1; // Action Indigo
  --ds-accent-secondary: #bdc2ff;
  --ds-accent-tertiary: #c890ff;

  --ds-status-success: #10b981;
  --ds-status-warning: #f59e0b;
  --ds-status-danger: #ef4444;
  --ds-status-info: #3b82f6;
  --ds-status-rotting: #f97316; // Alerta de estagnação de negócios
}
```

---

### 4.2 Princípios de Interação & Ergonomia

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                            FLUXO DE INTERAÇÃO DO USUÁRIO                         │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   [ Teclado: Cmd+K ] ───► Paleta Universal ───► Ação Rápida / Troca de Rota     │
│          │                                                                       │
│          ├───► [ Teclado: J / K ] ───► Navegação Linear na Lista / Kanban        │
│          │                                                                       │
│          ├───► [ Teclado: Space / Enter ] ───► Peek Drawer (Inspeção 360°)      │
│          │                                                                       │
│          └───► [ Clique / Tab ] ───► Edição Inline Direta na Célula (Auto-save) │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

1. **Keyboard-First & Universal Command Palette:**
   - `Cmd+K` / `Ctrl+K`: Abre a paleta de comandos instantaneamente em qualquer tela.
   - Modos de busca da paleta:
     - `> [comando]`: Ações do sistema (ex.: `> Criar Novo Negócio`, `> Exportar Contatos`, `> Alternar Tema`);
     - `@ [nome]`: Busca instantânea de Contatos e Empresas;
     - `# [título]`: Busca de Negócios e Oportunidades em funis;
     - `? [termo]`: Busca em Artigos da Central de Ajuda e Canned Responses.
2. **Manipulação Reativa de Dados (Spreadsheet-Grade):**
   - Edição com duplo clique ou tecla Enter diretamente sobre qualquer célula da tabela;
   - Salvamento automático com indicador discreto de sincronização (_Saving... / Saved_);
   - Suporte a desfecho e reversão (_Undo / Redo_ via `Cmd+Z`).
3. **Slide-Over Peek Drawer:**
   - Clicar em um lead no Kanban ou em uma linha da tabela abre a gaveta lateral direita (480px a 640px de largura);
   - O usuário pode alternar entre abas contextuais (_Resumo_, _Conversas de WhatsApp_, _Histórico de Atividades_, _Notas_, _Arquivos_) sem perder o scroll da listagem principal.
4. **Optimistic UI Engine:**
   - Ao arrastar um card no funil de _Em Negociação_ para _Ganho_, a UI atualiza a coluna e as somatórias de valor no frame 0ms;
   - Uma requisição de background confirma a transição. Caso ocorra erro de rede, o card retorna com animação suave e um toast com ação de "Tentar Novamente".

---

## 5. Roadmap Priorizado de Implementação (3 Fases)

O plano de execução está estruturado em 3 fases sequenciais e complementares, balanceando ganhos rápidos de usabilidade com transformações estruturais de longo prazo.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                        ROADMAP DE IMPLEMENTAÇÃO EM 3 FASES                       │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│ FASE 1: QUICK WINS & POLIMENTO VISUAL IMEDIATO                 [Sprints 1 a 3]   │
│ ───► Cmd+K Expandido • Sidebar Reorganizada • Atalhos Inbox • Micro-interações   │
│                                                                                  │
│ FASE 2: REDESENHO ESTRUTURAL DOS FLUXOS PRINCIPAIS             [Sprints 4 a 8]   │
│ ───► Grid TanStack Table • Inline Edit • Peek Drawer • Inbox Cockpit Unificado   │
│                                                                                  │
│ FASE 3: RECURSOS AVANÇADOS & DIFERENCIAÇÃO ESTRATÉGICA         [Sprints 9 a 14]  │
│ ───► Visual Workflow Builder • Cockpit Unificado BI • Captain AI • Offline Sync  │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

### Fase 1: Quick Wins & Polimento Visual Imediato (Sprints 1 a 3)

_Foco: Baixo esforço de engenharia, altíssimo impacto na percepção diária de agilidade e limpeza estética._

#### 1.1 Unificação da Busca e Expansão da Command Palette (`Cmd+K`)

- **Ações Técnicas:**
  - Refatorar `core/app/javascript/dashboard/routes/dashboard/commands/commandbar.vue` e composables relacionados (`useGoToCommandHotKeys.js`);
  - Indexar todas as rotas do CRM: Funis (`/crm/board`), Leads (`/crm/leads`), Atividades (`/crm/activities`), Métricas (`/crm/metrics`), Cadências (`/crm/cadences`) e Regras de Automação (`/crm/automation`);
  - Adicionar provedor de busca de contatos e negócios recentes dentro da paleta;
  - Fundir a busca visual do topo da sidebar com o acionador do `Cmd+K`.
- **Entregáveis de UX:** Atalho `Cmd+K` funcional em 100% das telas com busca rápida e feedback visual com ícones Lucide padronizados.

#### 1.2 Reorganização e Limpeza da Sidebar Global

- **Ações Técnicas:**
  - Reestruturar o menu lateral em 4 blocos recolhíveis:
    1. **Principal:** Inbox de Mensagens, Notificações;
    2. **Vendas & CRM:** Funis de Negócios, Contatos & Empresas, Atividades, Cadências;
    3. **Automação & IA:** Central do Captain AI, Campanhas, Automações;
    4. **Gestão:** Relatórios & BI, Configurações do Sistema.
  - Implementar sistema de **Fixação de Favoritos (_Pinning_)** para acesso direto a funis e inboxes mais usados;
  - Adicionar modo compacto colapsável (somente ícones) com tooltips rápidos (`DsTooltip`).
- **Entregáveis de UX:** Redução da poluição visual da sidebar de 19 itens planos para 4 grupos elegantes com suporte a favoritos.

#### 1.3 Padronização dos Atalhos de Teclado no Inbox de Conversas

- **Ações Técnicas:**
  - Desacoplar os atalhos de eventos do DOM direto e migrá-los para um gerenciador global reativo (`useKeyboardNavigation.js`);
  - Padronizar as teclas de atalho:
    - `J` / `K` ou `Seta Baixo` / `Seta Cima`: Navegar entre conversas da lista;
    - `E`: Resolver / Arquivar conversa ativa;
    - `R`: Focar no compositor de mensagem;
    - `/`: Abrir popover de respostas rápidas (_canned responses_) com filtro fuzzy;
    - `Alt + P`: Alternar entre Mensagem Pública e Nota Privada.
- **Entregáveis de UX:** Operação completa do Inbox sem necessidade de mouse.

#### 1.4 Checklist Interativo de Onboarding (FTUE) & Empty States Guiados

- **Ações Técnicas:**
  - Criar o componente `DsOnboardingChecklist.vue` (widget flutuante/recolhível no canto inferior direito para novos usuários);
  - 4 passos essenciais de ativação: Conectar WhatsApp/Canal → Importar Contatos → Criar Primeiro Funil → Enviar Primeira Mensagem;
  - Adicionar botão de "Habilitar Dados de Demonstração" nas telas vazias de CRM e Contatos (`DsEmptyState`).
- **Entregáveis de UX:** Redução imediata no atrito de primeiros passos para novos usuários e equipes de teste.

---

### Fase 2: Redesenho Estrutural dos Fluxos Principais (Sprints 4 a 8)

_Foco: Modernização dos componentes centrais de manipulação de dados, pipelines e atendimento._

#### 2.1 Novo Data Grid de Contatos & Empresas (Estilo Attio/Folk)

- **Ações Técnicas:**
  - Substituir a tabela HTML estática de `ContactManageView.vue` e `CompaniesListLayout.vue` por um novo componente `DsDataGrid.vue` construído sobre `@tanstack/vue-table` e virtualização via `@vueuse/core`;
  - Implementar suporte a:
    - Edição inline com duplo clique em células (Texto, Seleção de Etapa, Responsável, Tags e Valores monetários);
    - Colunas dinâmicas (ocultar, exibir, reordenar por drag-and-drop e redimensionar largura);
    - Barra de ações em massa flutuante (`DsBulkActionBar.vue`) para exclusão, atribuição de responsável, adição de tags ou exportação;
    - Filtros rápidos multifacetados persistidos na URL e no localStorage.
- **Entregáveis de UX:** Gerenciamento de milhares de contatos com velocidade de planilha eletrônica e zero troca de página.

#### 2.2 Visualizador Peek Drawer 360° para Contatos, Empresas e Negócios

- **Ações Técnicas:**
  - Expandir `DsDrawer.vue` para suportar visualização detalhada com abas:
    - **Visão Geral:** Campos principais e customizados com edição direta;
    - **Linha do Tempo Multicanal:** Histórico unificado de conversas de WhatsApp, e-mails trocados, notas internas, tarefas e ligações;
    - **Ações Rápidas de Vendas:** Botão de envio de WhatsApp direto, agendamento de atividade e alteração de etapa no funil.
- **Entregáveis de UX:** Fim dos recarregamentos completos de página para checar detalhes de leads ou contatos.

#### 2.3 Visualização Híbrida de Funis (Tabela / Kanban / Timeline) & Métricas

- **Ações Técnicas:**
  - Integrar alternador de visualização no cabeçalho de `CrmIndexOperational.vue`;
  - Adicionar cabeçalhos de etapa enriquecidos:
    - Total de negócios e valor financeiro somado (com cálculo ponderado por probabilidade);
    - Indicador de SLA da etapa e alertas de estagnação (_Deal Rotting_ com badge pulsante laranja para cards sem interação há mais de N dias);
  - Implementar filtros instantâneos por Responsável, Etapa, Valor, Tag e Data de Fechamento Prevista sem reload.
- **Entregáveis de UX:** Gestão de vendas visual, analítica e operacional unificada no mesmo painel.

#### 2.4 Cockpit Unificado do Inbox e Compositor de Mensagens

- **Ações Técnicas:**
  - Reestruturar o layout do Inbox com três colunas fluidas e redimensionáveis: Lista de Conversas (320px), Chat Central (flex) e Gaveta de Contexto do Contato/Deal (360px);
  - Otimizar o compositor de texto:
    - Suporte a gravação de áudio com visualizador de onda sonora e cancelamento rápido;
    - Inserção de templates de WhatsApp e variáveis dinâmicas (`{{contact.name}}`) com preview instantâneo;
    - Habilitar uso de respostas rápidas tanto em mensagens públicas quanto em notas internas privadas;
    - _Optimistic UI_ no envio de mensagens e uploads de mídia.
- **Entregáveis de UX:** Atendimento multicanal ultrarrápido com contexto de CRM imediatamente visível ao lado do chat.

---

### Fase 3: Recursos Avançados & Diferenciação Estratégica (Sprints 9 a 14)

_Foco: Automações visuais, inteligência analítica consolidada e diferenciação por IA._

#### 3.1 Construtor Visual de Automações Baseado em Nós (Node-Based Builder)

- **Ações Técnicas:**
  - Substituir o formulário linear `AutomationRules.vue` por uma interface de diagrama visual interativo utilizando `@vue-flow/core`;
  - Tipos de nós padronizados:
    - **Gatilhos (Triggers):** Mensagem recebida, Negócio criado, Etapa alterada, Tag adicionada, Tempo de inatividade;
    - **Condições (Branches):** Horário de atendimento, Valor do negócio > X, Canal de entrada == WhatsApp, Score do lead;
    - **Ações (Actions):** Enviar mensagem de WhatsApp, Atribuir a vendedor, Mover de etapa no funil, Notificar via Webhook, Disparar cadência.
  - Simulador de testes em tempo real: testar o fluxo inserindo um contato simulado para verificar o caminho percorrido pelos nós.
  - Unificação definitiva das regras de chat (`automation_rules`) e regras de CRM (`crm_automation_rules`).
- **Entregáveis de UX:** Criação e manutenção de regras complexas de atendimento e vendas de forma totalmente visual e à prova de erros.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   EXEMPLO DO CONSTRUTOR DE AUTOMAÇÃO EM NÓS                      │
├──────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   [ GATILHO: Novo Lead WhatsApp ]                                                │
│                 │                                                                │
│                 ▼                                                                │
│   [ CONDIÇÃO: Score do Lead ≥ 70? ]                                              │
│        │                          │                                              │
│     (Sim)                       (Não)                                            │
│        │                          │                                              │
│        ▼                          ▼                                              │
│   [ AÇÃO: Criar Negócio       [ AÇÃO: Enviar Mensagem                            │
│     no Funil Enterprise ]       de Qualificação ]                                │
│        │                                                                         │
│        ▼                                                                         │
│   [ AÇÃO: Atribuir a SDR                                                         │
│     em Round-Robin ]                                                             │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

#### 3.2 Cockpit Integrado de Inteligência & Relatórios (Sales & Support BI)

- **Ações Técnicas:**
  - Unificar `Reports.vue` e `CrmMetrics.vue` em uma central de inteligência analítica única (`AnalyticsCenter.vue`);
  - Painéis estruturados em abas:
    - **Visão Geral Executiva:** Receita gerada, volume de conversas, taxa de conversão e tempo de resposta;
    - **Funil de Vendas & Eficiência:** Taxa de passagem entre etapas, motivos de perda frequentes, velocidade do ciclo de vendas por vendedor;
    - **Performance de Atendimento & SLA:** CSAT por canal, tempo de primeira resposta (FRT), conversas resolvidas no primeiro contato (FCR).
  - Filtros globais de período (Hoje, Últimos 7 dias, Este Mês, Personalizado) com atualização reativa instantânea dos gráficos.
- **Entregáveis de UX:** Eliminação total dos silos analíticos entre vendas e suporte.

#### 3.3 Assistente de IA Contextual (Captain AI Copilot)

- **Ações Técnicas:**
  - Integrar o assistente de IA diretamente na barra lateral do Inbox e nos cards de negócio do CRM;
  - Funcionalidades contextuais:
    - **Smart Summary:** Resumo em 3 tópicos de conversas longas de WhatsApp;
    - **Reply Assistant:** Sugestão de respostas empáticas e persuasivas baseadas na base de conhecimento da empresa;
    - **Deal Insights:** Análise preditiva do sentimento do cliente e recomendação da próxima melhor ação (_Next Best Action_).
- **Entregáveis de UX:** Ganho expressivo de produtividade para atendentes e vendedores com IA embutida no fluxo natural de trabalho.

---

## 6. Especificações Técnicas e KPIs de Sucesso

### 6.1 Recomendações de Stack e Componentes

| Necessidade de Interface                  | Biblioteca / Solução Recomendada                        | Justificativa Técnica                                                                                                                                       |
| ----------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Data Grid & Tabelas de Alta Densidade** | `@tanstack/vue-table` + `@vueuse/core` (useVirtualList) | Padrão da indústria para tabelas headless, suporte nativo a ordenação multi-coluna, filtros customizados, virtualização e total flexibilidade com Tailwind. |
| **Workflow Builder (Automações em Nós)**  | `@vue-flow/core`                                        | Biblioteca moderna para diagramas e grafos interativos em Vue 3, leve, altamente customizável e compatível com a estética Midnight Indigo.                  |
| **Command Palette Universal**             | Refatoração de `@ChusteRM/ninja-keys` + Fuse.js         | Manutenção do componente existente com adição de busca fuzzy precisa e injeção dinâmica de provedores de dados.                                             |
| **Drag and Drop (Kanban & Listas)**       | `@formkit/drag-and-drop` ou `vuedraggable`              | APIs modernas de drag-and-drop com suporte a acessibilidade e alta performance de renderização.                                                             |
| **Gráficos e Visualização de Dados**      | `chart.js` + `vue-chartjs` com tokens `--ds-chart-*`    | Renderização em Canvas ultrarrápida, temas escuros consistentes e excelente suporte a tooltips customizados.                                                |
| **Ícones do Sistema**                     | `lucide-vue-next`                                       | Pacote de ícones limpos, geométricos e consistentes, substituindo gradualmente ícones heterogêneos legados.                                                 |

---

### 6.2 Matriz de Esforço vs. Impacto do Roadmap

```
  ALTO IMPACTO │  [F1.1] Cmd+K Universal      │  [F2.1] Data Grid TanStack
               │  [F1.2] Sidebar Reorganizada │  [F2.3] Funil Híbrido & Métricas
               │  [F1.3] Atalhos Inbox        │  [F3.1] Visual Workflow Builder
               │                              │  [F3.2] Cockpit BI Unificado
  ─────────────┼──────────────────────────────┼─────────────────────────────────
  BAIXO IMPACTO│  [F1.4] Ajuste Micro-tokens  │  [F3.4] Cache Offline IndexedDB
               │  [F1.5] Onboarding Checklist │
               └──────────────────────────────┴─────────────────────────────────
                            BAIXO ESFORÇO                  ALTO ESFORÇO
```

---

### 6.3 Métricas de Sucesso e KPIs de Adoção

O sucesso da execução deste plano mestre será medido através de métricas quantitativas de performance técnica, produtividade do usuário e satisfação:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             PAINEL DE KPIS DE SUCESSO                            │
├──────────────────────────────────────┬─────────────┬─────────────┬───────────────┤
│ Métrica de UX / Desempenho           │ Baseline    │ Meta        │ Método        │
├──────────────────────────────────────┼─────────────┼─────────────┼───────────────┤
│ Tempo Médio de Execução por Tarefa   │ 18.4s       │ < 6.0s      │ Telemetria de │
│ (Criar negócio / responder lead)     │             │ (-67%)      │ Rota / Eventos│
├──────────────────────────────────────┼─────────────┼─────────────┼───────────────┤
│ Latência de Troca de Visualização    │ 420ms       │ < 40ms      │ Performance   │
│ (Tabela ◄► Kanban ◄► Detalhes)       │             │ (-90%)      │ API (Chrome)  │
├──────────────────────────────────────┼─────────────┼─────────────┼───────────────┤
│ Adoção de Atalhos de Teclado / Cmd+K │ ~4%         │ ≥ 40% das   │ Analytics de  │
│ sobre o total de ações               │             │ interações  │ Eventos       │
├──────────────────────────────────────┼─────────────┼─────────────┼───────────────┤
│ Time to Value (FTUE Onboarding)      │ 48 min      │ < 8 min     │ Funil de      │
│ (Tempo até 1º WhatsApp + 1º Lead)    │             │ (-83%)      │ Ativação      │
├──────────────────────────────────────┼─────────────┼─────────────┼───────────────┤
│ Conformidade com Design System Ds*   │ ~28%        │ 100% de     │ Script de     │
│ (Zero selects nativos e zero scoped) │             │ conformidade│ Auditoria CI  │
├──────────────────────────────────────┼─────────────┼─────────────┼───────────────┤
│ CSAT de Usabilidade e Satisfação     │ 72%         │ ≥ 94%       │ Pesquisa      │
│ (NPS Interno / Externo)              │ (NPS +28)   │ (NPS +70)   │ In-App        │
└──────────────────────────────────────┴─────────────┴─────────────┴───────────────┘
```

---

## 7. Governança e Diretrizes para o Time de Desenvolvimento

1. **Princípio da Não-Regressão Funcional:** Nenhuma migração de interface pode avançar sem testes E2E/Vitest cobrindo os fluxos de ponta a ponta.
2. **Proibição Estrita de CSS Scoped e Cores Hardcoded:** Conforme estabelecido no `core/AGENTS.md`, todo novo componente deve utilizar classes utilitárias do Tailwind e tokens semânticos `--ds-*`.
3. **Internacionalização Obrigatória (i18n):** Zero _bare strings_ em código Vue. Todos os textos devem ser registrados em `en.json` e `en.yml`.
4. **Design Tokens como Única Fonte de Verdade:** Alterações visuais devem ser realizadas exclusivamente via `_design-tokens.scss` e `tokens.js`, assegurando coerência absoluta entre o modo claro e o modo escuro (_Midnight Indigo_).

---

_Documento consolidado a partir das pesquisas de mercado globais e das auditorias técnicas completas do workspace ChusteRM._
