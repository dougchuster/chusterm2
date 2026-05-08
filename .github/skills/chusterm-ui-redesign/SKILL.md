---
name: chusterm-ui-redesign
description: 'Redesenha a UI e a UX do ChusteRM com base no Midnight Indigo e no Nocturnal Architect. Use quando precisar reformular dashboard, login, super login, área de super login para configuração do sistema principal, navegação, cards, formulários, hierarquia visual e consistência entre telas escuras editoriais.'
argument-hint: 'Informe a tela ou fluxo, o objetivo do redesign, restrições técnicas e a prioridade entre login, super login, configuração principal e dashboard'
user-invocable: true
---

# ChusteRM UI Redesign

## O que esta skill produz
- Um redesign completo e coerente de UI e UX para as superfícies do ChusteRM.
- Uma proposta consistente entre dashboard, login, super login e a área de configuração principal, sem criar linguagens visuais paralelas.
- Diretrizes prontas para implementação em código, com foco em tokens, layout, componentes e qualidade visual.
- Um modo de trabalho tanto para redesign sistêmico quanto para redesign de uma tela por vez.

## Quando usar
- Quando o pedido for reformular o design do sistema inteiro.
- Quando houver necessidade de redesenhar dashboard, login, super login ou a área de configuração principal.
- Quando a interface estiver inconsistente entre autenticação e área logada.
- Quando for necessário converter um layout genérico em uma experiência editorial escura, sofisticada e funcional.
- Quando o objetivo for melhorar UI e UX de forma prática, com impacto direto em clareza, navegação e percepção de qualidade.

## Referência obrigatória
Antes de propor ou editar qualquer tela, use [design-brief](./references/design-brief.md).

## Procedimento
1. Identifique as telas e fluxos afetados.
2. Audite a interface atual e separe o que deve ser mantido, removido ou reestruturado.
3. Defina o modo de atuação:
   - Redesign sistêmico: quando o pedido envolver todo o produto ou múltiplas áreas acopladas.
   - Redesign pontual: quando o pedido envolver uma única tela por vez.
4. Aplique os princípios do design brief aos contextos centrais:
   - Login: confiança, clareza, atmosfera editorial e foco em conversão.
   - Super login: mesma linguagem visual do login principal, com diferenciação apenas de contexto, papel e criticidade.
   - Super login de configuração principal: mesma base visual do super login, porém com sinais mais explícitos de segurança, governança e acesso avançado.
   - Dashboard: leitura rápida, hierarquia forte, grid assimétrico, profundidade tonal e ações visíveis.
5. Reestruture a UX antes da estética:
   - simplifique navegação
   - destaque ações primárias
   - reduza ruído visual
   - organize blocos por prioridade operacional
6. Traduza o redesign para implementação:
   - tokens de cor
   - tipografia
   - spacing
   - elevação
   - estados interativos
   - componentes reutilizáveis
7. Garanta responsividade sem perder a identidade visual.
8. Valide o resultado com os critérios de qualidade abaixo.

## Decisões e ramificações
- Se a tela for de autenticação, use composição editorial com forte contraste entre área narrativa e área funcional.
- Se a tela for administrativa ou analítica, priorize escaneabilidade, cabeçalho fixo com blur, cards tonais e uma grade bento.
- Se a tela for super login, preserve exatamente a mesma base visual do login padrão; altere apenas copy, badges, sinais de segurança e contexto do papel.
- Se a tela for a área de configuração principal, mantenha a mesma família visual do super login e aumente a sobriedade operacional, o peso das labels e a clareza de permissões e estados críticos.
- Se houver conflito entre o layout atual e o design system, priorize o design system.
- Se a tela ficar carregada, remova elementos antes de adicionar novos ornamentos.
- Se o mobile perder legibilidade, reduza densidade e reorganize blocos, sem abandonar a hierarquia tipográfica ou a paleta.

## Critérios de qualidade
- Não use bordas duras para contenção de layout.
- Separe áreas por mudança tonal, blur e espaçamento.
- Use Manrope para títulos e Inter para corpo e labels.
- Evite branco puro em texto contínuo; prefira as variações suaves do sistema.
- Use CTA primário em pill com gradiente apenas para ações de maior impacto.
- Mantenha cards com cantos arredondados e profundidade por camadas tonais.
- Faça login, super login e super login de configuração parecerem partes do mesmo produto.
- Mantenha consistência entre navegação lateral, top bar, cards, inputs e FAB.
- Preserve boa leitura em desktop e mobile.
- Em redesign por tela, resolva a tela inteira, e não apenas detalhes cosméticos isolados.

## Entregáveis esperados
- Diagnóstico dos problemas de UI e UX.
- Proposta de reorganização da informação.
- Direção visual consolidada para dashboard, login, super login e configuração principal.
- Mudanças concretas em componentes, layout e tokens.
- Lista curta de ambiguidades restantes para validação humana.

## Perguntas que esta skill deve levantar quando necessário
- O redesign deve ser aplicado primeiro em HTML estático, componentes do app ou no sistema inteiro de uma vez?
- Há alguma tela que precise manter compatibilidade visual com partes legadas?
- A área de configuração principal deve parecer mais restrita e operacional que o restante do sistema, ou apenas mais avançada?

## Exemplos de uso
- `/chusterm-ui-redesign Reformule a dashboard principal do ChusteRM com foco em métricas, atividades e ações rápidas.`
- `/chusterm-ui-redesign Redesenhe a tela de login e a tela de super login com a mesma base visual e diferenciação apenas por contexto.`
- `/chusterm-ui-redesign Redesenhe a tela de super login da configuração principal mantendo a mesma linguagem visual, mas com maior ênfase em segurança e governança.`
- `/chusterm-ui-redesign Audite a UI atual do sistema e proponha uma unificação completa usando o design system do projeto.`