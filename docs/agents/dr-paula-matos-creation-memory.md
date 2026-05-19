# Memoria de criacao - Agente Dra. Paula Matos

Atualizado em: 2026-05-18

## Objetivo

Criar um agente Captain/IA para triagem inicial de planejamento previdenciario, com postura de atendimento juridico humanizado, base RAG/FAQ, memoria persistente por conversa e score proprio por agente/campanha.

## Agente

- Nome publico: Dra. Paula Matos
- Especialidade: planejamento previdenciario antes da aposentadoria
- Escritorio/campanha: Coimbra & Ruas, campanha `planejamento-previdenciario`
- URL base pesquisada: https://planejamento.coimbraeruas.com.br/
- Papel: triagem inicial, organizacao do caso, identificacao de risco, coleta de documentos e encaminhamento humano quando necessario

## Fontes usadas na base inicial

- Landing page Coimbra & Ruas: proposta de diagnostico previdenciario, riscos, processo, FAQ, contato e linguagem da campanha.
- INSS: orientacao para conferir CNIS e simulacao antes do pedido.
- INSS: simulacao de aposentadoria e aviso de que demonstrativo nao garante direito ao beneficio.
- INSS: extrato CNIS como documento com vinculos, remuneracoes e contribuicoes.
- INSS: regra de contribuinte individual/facultativo/MEI e alerta sobre aliquotas reduzidas.

## Decisoes de arquitetura

- Runtime principal no `services/orchestrator`, pois ja existe rota `/agent/message`, skills e banco `chusterm_ai`.
- Memoria persistente nova em tabela `agent_conversation_memories`, por `accountId + conversationId + profileSlug`.
- RAG inicial hibrido: corpus curado em codigo para resposta imediata + script/seed para publicar os mesmos documentos na base `knowledge_*`.
- Score especializado implementado como skill independente, com modelo especifico para `dr-paula-matos` e campanha `planejamento-previdenciario`.
- O agente nao promete resultado, nao calcula beneficio final sem documentos e prioriza handoff humano quando houver prazo, negativa, exigencia, pedido em analise, CNIS critico ou score alto.

## Etapas

- [x] Mapear arquitetura atual de AgentBot/Captain/orchestrator/score.
- [x] Pesquisar fontes da campanha e fontes oficiais do INSS.
- [x] Criar memoria de execucao.
- [x] Implementar perfil, RAG, FAQ e scoring previdenciario no orchestrator.
- [x] Implementar memoria persistente por conversa.
- [x] Criar seed/tarefa para Captain e documentos.
- [x] Validar build e endpoints locais.

## Estado aplicado

- Orchestrator migrado com `agent_conversation_memories`.
- RAG/FAQ publicado no account `1` em `knowledge_collections`.
- Captain Assistant criado no Core: `Dra. Paula Matos`, `assistant_id=5`.
- Captain seed criou 3 documentos, 3 playbooks e 2 cenarios.
- Skill validada: `/skills/previdenciario-triage/run`.
- Core rebuildado com shim `Captain::Document::SYNC_STALE_TIMEOUT` para compatibilidade com `chatwoot:latest`.

## Pendencias conhecidas

- Confirmar depois qual `ACCOUNT_ID`/inbox deve receber o assistant em producao.
- Se houver ferramenta de agenda integrada, conectar o handoff/agendamento ao fluxo real.
- Se for exigido RAG vetorial, evoluir o corpus curado para embeddings; a primeira versao usa recuperacao lexical auditavel e deterministica.
