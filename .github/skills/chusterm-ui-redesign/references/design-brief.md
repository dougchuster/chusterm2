# ChusteRM Design Brief

Fonte consolidada a partir de `docs/chusterm_design_system.md` e `docs/DESIGN.md`.

## Norte criativo
- Estética editorial escura, sofisticada e precisa.
- Sensação de profundidade, silêncio visual e controle operacional.
- Experiência menos "SaaS genérico" e mais "control center editorial".

## Paleta principal
- Fundo base: `#060e20`
- Navegação e áreas largas: `#06122c`
- Cards e superfícies interativas: `#0f1e3f`
- Hover e brilho de interação: `#182b52`
- Primary accent: `#bdc2ff`
- Secondary text: `#b9c8de`
- Tertiary accent: `#c890ff`
- Action purple: `#6366F1`

## Regras visuais obrigatórias
- Evite bordas sólidas para separar grandes regiões.
- Use empilhamento tonal para profundidade.
- Use blur em barras fixas e painéis flutuantes.
- Use gradiente apenas em CTAs principais e pontos de forte destaque.
- Prefira sombras amplas e difusas, não sombras pequenas e agressivas.

## Tipografia
- Títulos e headlines: Manrope.
- Corpo, labels e textos densos: Inter.
- Labels pequenas em caixa alta com tracking amplo.
- Evite hierarquia tipográfica tímida; títulos devem ter presença editorial.

## Componentes
- Botões primários: pill, gradiente suave, alto contraste.
- Botões secundários: superfície tonal, sem outline duro.
- Cards: `rounded-xl` ou acima, sem borda evidente.
- Inputs: fundo mais profundo, placeholder discreto, foco com halo suave.
- Avatares: `ring-2` com acento suave.
- FAB: circular, destacado, brilho controlado.

## Aplicação por tela

### Login
- Estrutura split ou composição equivalente com narrativa visual de marca e formulário claro.
- Mensagem curta, premium e segura.
- Inputs com profundidade, CTA evidente e pouca distração.

### Super login
- Deve compartilhar a mesma base de login.
- Diferença por copy, badge, contexto de segurança e papel administrativo.
- Não criar outra paleta nem outro sistema visual.

### Dashboard
- Cabeçalho com blur.
- Sidebar sem borda dura, separada por tonalidade.
- Grid assimétrico, estilo bento, com áreas de leitura rápida.
- Métricas críticas em destaque e blocos secundários com contraste menor.
- Atividades, insights e ações rápidas devem coexistir sem poluir a tela.

## Critérios finais
- Consistência visual entre autenticação e área logada.
- Boa leitura em tema escuro por longos períodos.
- Espaço negativo suficiente para respiração visual.
- Hierarquia clara entre informação crítica, secundária e contextual.