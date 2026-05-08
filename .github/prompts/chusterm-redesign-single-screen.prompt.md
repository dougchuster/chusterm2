---
name: "ChusteRM Redesign Single Screen"
description: "Redesenha uma unica tela do ChusteRM por vez com foco em UI e UX, usando o design system Midnight Indigo / Nocturnal Architect."
argument-hint: "Informe a tela, o objetivo, os problemas atuais, o tipo de usuario e as restricoes tecnicas"
agent: "agent"
---

Redesenhe uma unica tela do ChusteRM por vez.

Use obrigatoriamente estas referencias:
- [Skill de redesign](../skills/chusterm-ui-redesign/SKILL.md)
- [Design brief](../skills/chusterm-ui-redesign/references/design-brief.md)
- [Diretrizes do projeto](../core/AGENTS.md)

Objetivo:
- Melhorar UI e UX da tela informada sem criar uma linguagem visual paralela ao restante do sistema.

Siga este fluxo:
1. Identifique a tela, o papel do usuario, a tarefa principal e o contexto operacional.
2. Liste os principais problemas atuais de hierarquia, navegacao, densidade, legibilidade e consistencia.
3. Proponha um redesign completo da tela, e nao apenas ajustes cosmeticos.
4. Descreva layout, estrutura de blocos, componentes, estados interativos e prioridade de informacao.
5. Aplique o design system Midnight Indigo / Nocturnal Architect com consistencia tipografica, tonal e espacial.
6. Se a tela for login, super login ou configuracao principal, preserve a mesma familia visual e diferencie apenas contexto, copy, seguranca e criticidade.
7. Se a tela for dashboard ou tela operacional, priorize leitura rapida, grid assimetrico e foco em acoes principais.
8. Entregue orientacoes prontas para implementacao no codigo.

Formato de saida:
- Diagnostico
- Direcao visual
- Estrutura e UX
- Componentes e estados
- Regras de implementacao
- Riscos ou ambiguidades

Se houver HTML, componente ou mock atual, use-o apenas como ponto de partida e nao como limite criativo.