# Mapa QA Completo do CRM ChusteRM

Atualizado em: 07/05/2026

## Objetivo

Este documento mapeia as paginas, funcoes e fluxos criticos do CRM ChusteRM para orientar um QA em uma validacao ponta a ponta do sistema. O foco e garantir que as areas de CRM, contatos e integracoes operacionais funcionem de forma consistente, sem perda de dados, sem filtros vazando entre paginas e com boa experiencia em tema claro, tema escuro, desktop e mobile.

Use este arquivo como roteiro de teste manual. Cada pagina possui rota, objetivo, permissoes, funcoes, integracoes e checklist de validacao.

## Escopo

Incluido neste QA:

- CRM completo: Pipeline, Todos os Leads, Agenda, Atividades, Relatorios, Metricas, Pipelines, Checklists, Automacoes, Cadencias, Scoring, Detalhes do atendimento/deal e Motivos de Perda.
- Integracoes que impactam CRM: Contatos, Categorias, Lista, detalhes de contato, Empresas, Campanhas e Conversas quando alterarem lead, cliente, atendimento ou segmentacao.
- APIs e fluxos de suporte: Google Calendar, atividades, deals, pipelines, categorias, importacao/exportacao, scoring e automacoes.

Fora deste QA:

- Testes automatizados de baixo nivel.
- Validacao de infraestrutura externa fora do sistema, exceto como pre-condicao para Google Calendar, SMTP e canais de atendimento.
- Auditoria de seguranca completa.

## Pre-condicoes de Teste

Ambiente recomendado:

- Aplicacao rodando em `http://localhost:3010`.
- Conta de teste acessivel em `/app/accounts/1`.
- Feature flag `CRM` ativa para a conta.
- Banco com dados de teste ou seed equivalente.

Perfis necessarios:

- Administrador: deve acessar todas as paginas do CRM, configuracoes, relatorios e recursos de gestao.
- Agente: deve acessar operacao CRM permitida, como Pipeline, Todos os Leads, Atividades, Agenda, Detalhes e Contatos, respeitando bloqueios de paginas administrativas.
- Usuario sem permissao CRM: deve ser bloqueado nas rotas protegidas.

Dados minimos:

- Pelo menos 2 pipelines ativos, com 5 ou mais etapas cada.
- Pelo menos 10 leads/deals distribuidos em etapas diferentes.
- Pelo menos 20 contatos, com mistura de lead, cliente e sem relacionamento.
- Pelo menos 5 categorias/listas de contato.
- Pelo menos 3 atividades: pendente, vencida e concluida.
- Pelo menos 1 cadencia, 1 checklist, 1 regra de automacao e 1 configuracao de scoring.
- Pelo menos 1 conversa vinculada a contato que possa gerar/atualizar um atendimento CRM.

Integracoes externas:

- Google Calendar desconectado: validar fallback local.
- Google Calendar conectado: validar criacao, importacao e sincronizacao.
- SMTP/Email configurado quando testar campanhas ou envio/recebimento por email.

## Matriz de Rotas CRM

| Area | Rota | Nome da rota | Permissao esperada |
| --- | --- | --- | --- |
| CRM > Pipeline | `/app/accounts/:accountId/crm` | `crm_dashboard` | administrador, agente, contact_manage |
| CRM > Todos os Leads | `/app/accounts/:accountId/crm/leads` | `crm_all_leads` | administrador, agente, contact_manage |
| CRM > Pipelines | `/app/accounts/:accountId/crm/settings/pipelines` | `crm_pipeline_settings` | administrador |
| CRM > Atividades | `/app/accounts/:accountId/crm/activities` | `crm_activities` | administrador, agente, contact_manage |
| CRM > Agenda | `/app/accounts/:accountId/crm/agenda` | `crm_agenda` | administrador, agente, contact_manage |
| CRM > Relatorios | `/app/accounts/:accountId/crm/reports` | `crm_reports` | administrador |
| CRM > Motivos de Perda | `/app/accounts/:accountId/crm/settings/loss-reasons` | `crm_loss_reasons` | administrador |
| CRM > Checklists | `/app/accounts/:accountId/crm/settings/checklist-templates` | `crm_checklist_templates` | administrador |
| CRM > Automacoes | `/app/accounts/:accountId/crm/settings/automation-rules` | `crm_automation_rules` | administrador |
| CRM > Cadencias | `/app/accounts/:accountId/crm/settings/cadences` | `crm_cadences` | administrador |
| CRM > Scoring | `/app/accounts/:accountId/crm/settings/scoring` | `crm_scoring_config` | administrador |
| CRM > Detalhes do Deal | `/app/accounts/:accountId/crm/deals/:dealId` | `crm_deal_details` | administrador, agente, contact_manage |
| CRM > Metricas | `/app/accounts/:accountId/crm/metrics` | `crm_metrics` | administrador, agente, contact_manage |

## Matriz de Rotas Integradas

| Area | Rota | Nome da rota | Permissao esperada |
| --- | --- | --- | --- |
| Contatos > Todos os contatos | `/app/accounts/:accountId/contacts` | `contacts_dashboard_index` | administrador, agente, contact_manage |
| Contatos > Segmentos | `/app/accounts/:accountId/contacts/segments/:segmentId` | `contacts_dashboard_segments_index` | administrador, agente, contact_manage |
| Contatos > Etiquetas | `/app/accounts/:accountId/contacts/labels/:label` | `contacts_dashboard_labels_index` | administrador, agente, contact_manage |
| Contatos > Categorias | `/app/accounts/:accountId/contacts/categories` | `contacts_dashboard_categories` | administrador, agente, contact_manage |
| Contatos > Pasta de categoria | `/app/accounts/:accountId/contacts/categories/:kind` | `contacts_dashboard_category_kind` | administrador, agente, contact_manage |
| Contatos > Categoria especifica | `/app/accounts/:accountId/contacts/categories/:kind/:categoryId` | `contacts_dashboard_category_detail` | administrador, agente, contact_manage |
| Contatos > Lista | `/app/accounts/:accountId/contacts/list` | `contacts_dashboard_list` | administrador, agente, contact_manage |
| Detalhe/edicao de contato | `/app/accounts/:accountId/contacts/:contactId` | `contacts_edit` | administrador, agente, contact_manage |

## Padrao Visual Global

Validar em todas as telas CRM e integradas:

- [ ] Tema claro sem texto branco em fundo claro.
- [ ] Tema escuro sem texto escuro em fundo escuro.
- [ ] Botoes com hover, foco e disabled visiveis.
- [ ] Campos de busca com icone sem sobrepor placeholder ou texto digitado.
- [ ] Selects, inputs de data, chips, badges e tooltips com contraste correto.
- [ ] Layout sem sobreposicao em 1366px, 1920px, tablet e mobile.
- [ ] Paginas com conteudo longo rolam corretamente ate o final.
- [ ] Side menu expandido e recolhido mantem icones, labels e estado ativo corretos.
- [ ] Estados vazios e erros mostram mensagens compreensiveis.
- [ ] Acoes destrutivas pedem confirmacao.

## CRM > Pipeline

Rota: `/app/accounts/1/crm`

Objetivo: operar o funil comercial em formato Kanban, acompanhando leads/deals por pipeline e etapa.

Funcoes principais:

- Selecionar pipeline ativo.
- Buscar por deal, contato, telefone ou dados relevantes.
- Filtrar leads por responsavel, origem, etapa, status e demais filtros do funil.
- Arrastar deal entre etapas.
- Abrir ficha 360/detalhe do atendimento.
- Criar novo lead quando permitido.
- Executar acoes rapidas: mover, marcar ganho, marcar perdido, arquivar, descartar, cliente base e recalcular score quando disponivel.
- Limpar deals orfaos quando a acao estiver disponivel.

Integracoes:

- `GET /crm/dashboard`
- `GET /crm/deals`
- `POST /crm/deals`
- `POST /crm/deals/:id/move`
- `POST /crm/deals/:id/mark_won`
- `POST /crm/deals/:id/mark_lost`
- `POST /crm/deals/:id/archive`
- `POST /crm/deals/:id/discard`
- `POST /crm/lead-scores/recompute`

Checklist QA:

- [ ] Abrir a pagina com pelo menos 2 pipelines ativos.
- [ ] Alternar entre pipelines e confirmar que etapas/deals nao se misturam.
- [ ] Buscar por nome do lead e confirmar resultado correto.
- [ ] Buscar por contato/telefone e confirmar resultado correto.
- [ ] Limpar busca e confirmar retorno da lista completa.
- [ ] Arrastar lead para outra etapa e recarregar a pagina; a etapa deve permanecer salva.
- [ ] Abrir ficha 360 pelo card.
- [ ] Criar novo lead e confirmar que ele aparece na etapa inicial do pipeline selecionado.
- [ ] Marcar lead como ganho e validar saida/alteracao visual conforme regra da tela.
- [ ] Marcar lead como perdido com motivo quando exigido.
- [ ] Validar cards vazios por etapa e pagina sem dados.
- [ ] Validar responsividade: Kanban deve permitir leitura/rolagem horizontal ou empilhamento sem quebrar.

## CRM > Todos os Leads

Rota: `/app/accounts/1/crm/leads`

Objetivo: listar todos os leads de forma ampla, com etapas, categorias, responsaveis, score, tarefas e valor.

Funcoes principais:

- Buscar por lead, contato, telefone e area.
- Filtrar por status, etapa, area, urgencia, responsavel, origem, situacao e score.
- Visualizar KPIs: leads carregados, abertos, quentes, sem responsavel e valor estimado.
- Selecionar leads individualmente e em massa.
- Criar novo lead.
- Atualizar origem/categoria via acao em massa quando disponivel.
- Abrir ficha 360, conversa e acoes rapidas do lead.

Integracoes:

- `GET /crm/deals`
- `POST /crm/deals`
- `PATCH /crm/deals/:id`
- `POST /crm/deals/bulk_action`
- `POST /crm/deals/:id/mark_base_client`
- `POST /crm/deals/:id/discard`
- `POST /crm/lead-scores/recompute`

Checklist QA:

- [ ] Abrir a pagina e validar carregamento dos KPIs.
- [ ] Aplicar cada filtro individualmente.
- [ ] Combinar filtros e validar contagem da tabela.
- [ ] Limpar filtros e confirmar retorno ao estado inicial.
- [ ] Buscar por nome do lead.
- [ ] Buscar por nome do contato.
- [ ] Buscar por telefone.
- [ ] Criar novo lead e confirmar exibicao na lista.
- [ ] Selecionar um lead e validar barra de acoes em massa.
- [ ] Selecionar todos os visiveis e limpar selecao.
- [ ] Abrir ficha 360.
- [ ] Abrir conversa vinculada.
- [ ] Recalcular score e verificar badge/valor atualizado.
- [ ] Validar que a pagina nao herda filtros de Contatos > Categorias.

## CRM > Agenda

Rota: `/app/accounts/1/crm/agenda`

Objetivo: gerenciar reunioes e compromissos do CRM com contexto de atendimento e sincronizacao opcional com Google Calendar.

Funcoes principais:

- Alternar visualizacao Dia, Semana e Mes.
- Criar reuniao com titulo, descricao, data/hora, prioridade, lembrete, contato, atendimento/deal e responsavel.
- Sincronizar com Google Calendar quando conectado.
- Gerar/abrir link do Google Calendar e Meet quando disponivel.
- Importar eventos do Google no intervalo visivel.
- Editar, reagendar, concluir e excluir reuniao.
- Buscar por reuniao, contato, telefone, etapa ou responsavel.
- Ver status Google conectado/desconectado.

Integracoes:

- `GET /crm/google_authorization`
- `POST /crm/google_authorization`
- `GET /crm/activities`
- `POST /crm/activities`
- `PATCH /crm/activities/:id`
- `DELETE /crm/activities/:id`
- `POST /crm/activities/:id/complete`
- `POST /crm/activities/:id/sync_google_calendar`
- `POST /crm/activities/import_google_calendar`
- `POST /crm/activities/suggest_schedule`

Checklist QA:

- [ ] Abrir Agenda com Google desconectado.
- [ ] Criar reuniao local sem Google e validar mensagem de fallback.
- [ ] Editar reuniao criada.
- [ ] Reagendar reuniao e confirmar nova posicao na grade/lista.
- [ ] Excluir reuniao com confirmacao.
- [ ] Conectar Google com credenciais configuradas.
- [ ] Sincronizar intervalo visivel.
- [ ] Criar reuniao com Google conectado e validar link de calendario/Meet.
- [ ] Importar eventos do Google e confirmar que nao duplica no segundo sync.
- [ ] Buscar reuniao por nome, contato, telefone e responsavel.
- [ ] Validar evento vencido, futuro, concluido e prioridade alta com cores adequadas.
- [ ] Validar mobile: a grade deve virar lista por dia ou manter leitura sem sobreposicao.

## CRM > Atividades

Rota: `/app/accounts/1/crm/activities`

Objetivo: controlar tarefas, follow-ups, ligacoes, documentos e retornos ligados a leads/deals.

Funcoes principais:

- Criar atividade.
- Editar atividade.
- Excluir atividade com confirmacao.
- Concluir atividade.
- Adiar por 24h ou 72h.
- Importar Google Calendar.
- Exportar ICS.
- Sugerir horario.
- Filtrar por aba: pendentes, hoje, vencidas, concluidas e todas.
- Buscar por atividade, contato, caso ou responsavel.
- Filtrar por tipo, prioridade e intervalo de datas.

Integracoes:

- `GET /crm/activities`
- `POST /crm/activities`
- `PATCH /crm/activities/:id`
- `DELETE /crm/activities/:id`
- `POST /crm/activities/:id/complete`
- `POST /crm/activities/:id/snooze`
- `GET /crm/activities/calendar`
- `POST /crm/activities/import_google_calendar`
- `POST /crm/activities/:id/sync_google_calendar`
- `POST /crm/activities/suggest_schedule`

Checklist QA:

- [ ] Validar KPIs de pendentes, hoje, vencidas, alta prioridade e sem responsavel.
- [ ] Alternar abas e conferir contagem/lista.
- [ ] Buscar por titulo e garantir que retorna atividades de qualquer status quando aplicavel.
- [ ] Buscar por contato, caso/deal e responsavel.
- [ ] Aplicar filtro de tipo.
- [ ] Aplicar filtro de prioridade.
- [ ] Aplicar intervalo de datas.
- [ ] Criar atividade completa com contato/deal/responsavel.
- [ ] Editar titulo, prioridade, prazo e responsavel.
- [ ] Concluir atividade.
- [ ] Adiar atividade.
- [ ] Excluir atividade e confirmar remocao da lista.
- [ ] Validar botoes, icones e prioridades em tema claro e escuro.

## CRM > Detalhes do Deal/Atendimento

Rota: `/app/accounts/1/crm/deals/:dealId`

Objetivo: exibir a ficha 360 do atendimento, com contato, etapa, score, atividades, checklist, historico e dados juridicos/operacionais.

Funcoes principais:

- Visualizar resumo do caso.
- Ver contato principal, telefone, e-mail e relacionamento.
- Ver etapa atual, pipeline e score.
- Criar tarefa/atividade relacionada.
- Ver e aplicar checklist quando disponivel.
- Visualizar historico/auditoria quando disponivel.
- Atualizar campos operacionais do deal.
- Validar informacoes LGPD, consentimento e retencao quando exibidas.

Integracoes:

- `GET /crm/deals/:id`
- `PATCH /crm/deals/:id`
- `GET /crm/activities`
- `POST /crm/activities`
- `GET /crm/audit-events`
- `POST /crm/lead-scores/recompute`

Checklist QA:

- [ ] Abrir a ficha a partir de Pipeline.
- [ ] Abrir a ficha a partir de Todos os Leads.
- [ ] Validar dados do contato.
- [ ] Validar dados do atendimento/deal.
- [ ] Criar atividade pela ficha e confirmar em Atividades.
- [ ] Alterar campo do deal e recarregar.
- [ ] Recalcular score quando disponivel.
- [ ] Confirmar que dados sensiveis nao aparecem para perfil sem permissao.

## CRM > Pipelines

Rota: `/app/accounts/1/crm/settings/pipelines`

Objetivo: administrar funis, etapas, probabilidades, duracoes esperadas e scoring por pipeline.

Funcoes principais:

- Criar pipeline.
- Editar pipeline.
- Arquivar pipeline.
- Restaurar pipeline arquivado.
- Deletar permanentemente quando permitido.
- Criar etapa.
- Editar etapa.
- Reordenar etapas por arrastar e soltar.
- Arquivar/restaurar/deletar etapa.
- Configurar pesos de scoring.
- Alternar entre multiplos pipelines sem misturar etapas.

Integracoes:

- `GET /crm/pipelines`
- `POST /crm/pipelines`
- `PATCH /crm/pipelines/:id`
- `DELETE /crm/pipelines/:id`
- `GET /crm/pipelines/archived`
- `PATCH /crm/pipelines/:id/restore`
- `DELETE /crm/pipelines/:id/purge`
- `GET /crm/pipelines/:pipeline_id/stages`
- `POST /crm/pipelines/:pipeline_id/stages`
- `PATCH /crm/pipelines/:pipeline_id/stages/:id`
- `DELETE /crm/pipelines/:pipeline_id/stages/:id`

Checklist QA:

- [ ] Criar pipeline novo.
- [ ] Editar nome e padrao do pipeline quando disponivel.
- [ ] Criar etapa com probabilidade `0%`.
- [ ] Criar etapa com probabilidade `50%`.
- [ ] Criar etapa com probabilidade `100%`.
- [ ] Editar etapa criada.
- [ ] Reordenar etapas e recarregar pagina.
- [ ] Arquivar etapa e validar que sai do funil ativo.
- [ ] Restaurar etapa arquivada.
- [ ] Arquivar pipeline sem deals vinculados quando permitido.
- [ ] Validar bloqueio/erro amigavel ao arquivar/deletar pipeline com deals vinculados.
- [ ] Configurar scoring e salvar.
- [ ] Conferir que as alteracoes refletem em Pipeline, Todos os Leads e Scoring.
- [ ] Validar rolagem ate a ultima etapa.
- [ ] Validar botoes desativados, hovers e icones em tema claro/escuro.

## CRM > Relatorios

Rota: `/app/accounts/1/crm/reports`

Objetivo: consolidar indicadores operacionais do funil, atividades, areas, origem, urgencia e saneamento.

Funcoes principais:

- Filtrar por periodo, pipeline, etapa, area, urgencia, origem e status.
- Visualizar distribuicao do funil.
- Visualizar atividades por prioridade.
- Visualizar areas juridicas, origem e urgencia.
- Exibir insights operacionais.
- Exportar relatorio em CSV quando disponivel.

Integracoes:

- `GET /crm/dashboard`
- `GET /crm/deals`
- `POST /crm/deals/export`

Checklist QA:

- [ ] Abrir como administrador.
- [ ] Confirmar bloqueio para perfil sem permissao.
- [ ] Aplicar filtros individualmente.
- [ ] Combinar filtros e validar indicadores.
- [ ] Exportar CSV e confirmar download/conteudo.
- [ ] Validar estado sem dados.
- [ ] Validar graficos/cards em tema claro e escuro.

## CRM > Metricas

Rota: `/app/accounts/1/crm/metrics`

Objetivo: acompanhar metricas avancadas do CRM e usar o analista CRM para perguntas operacionais.

Funcoes principais:

- Ver visao geral de metricas.
- Ver funil por etapa.
- Ver tempo em etapa.
- Ver tendencia ganho/perda.
- Ver principais motivos de perda.
- Ver score por etapa.
- Ver distribuicao por area.
- Ver principais deals e deals parados.
- Fazer perguntas ao analista CRM quando disponivel.

Integracoes:

- `GET /crm/metrics/overview`
- `GET /crm/metrics/stage_funnel`
- `GET /crm/metrics/time_in_stage`
- `GET /crm/metrics/win_loss_trend`
- `GET /crm/metrics/top_loss_reasons`
- `GET /crm/metrics/score_by_stage`
- `GET /crm/metrics/area_distribution`
- `GET /crm/metrics/top_deals`
- `GET /crm/metrics/stale_deals`
- `POST /crm/analyst/ask`

Checklist QA:

- [ ] Abrir pagina e validar carregamento de todos os blocos.
- [ ] Alterar filtros globais quando existirem.
- [ ] Validar estados de loading e erro.
- [ ] Enviar pergunta ao analista e validar resposta ou erro amigavel.
- [ ] Conferir que metricas batem com os dados visiveis em Pipeline/Todos os Leads.

## CRM > Checklists

Rota: `/app/accounts/1/crm/settings/checklist-templates`

Objetivo: criar modelos de checklist para padronizar etapas de atendimento e documentos.

Funcoes principais:

- Criar checklist.
- Editar checklist.
- Arquivar/excluir checklist.
- Filtrar por busca e status.
- Configurar itens do checklist, tipos e obrigatoriedade quando disponivel.
- Aplicar checklist em deals quando integrado pela ficha.

Integracoes:

- `GET /crm/checklist-templates`
- `POST /crm/checklist-templates`
- `PATCH /crm/checklist-templates/:id`
- `DELETE /crm/checklist-templates/:id`

Checklist QA:

- [ ] Criar checklist com pelo menos 3 itens.
- [ ] Editar nome, descricao e itens.
- [ ] Validar obrigatoriedade de campos.
- [ ] Arquivar/excluir com confirmacao.
- [ ] Buscar checklist por nome.
- [ ] Validar filtro de status.
- [ ] Confirmar disponibilidade na ficha do deal quando aplicavel.

## CRM > Automacoes

Rota: `/app/accounts/1/crm/settings/automation-rules`

Objetivo: configurar regras para automatizar acoes do CRM com base em gatilhos e condicoes.

Funcoes principais:

- Criar automacao.
- Editar automacao.
- Ativar/desativar automacao.
- Excluir automacao.
- Filtrar/buscar regras.
- Configurar gatilhos, condicoes e acoes.
- Validar execucao indireta em mudancas de deal/etapa/atividade.

Integracoes:

- `GET /crm/automation-rules`
- `POST /crm/automation-rules`
- `PATCH /crm/automation-rules/:id`
- `DELETE /crm/automation-rules/:id`

Checklist QA:

- [ ] Criar regra com nome, gatilho e acao.
- [ ] Editar regra criada.
- [ ] Desativar regra e confirmar que nao executa.
- [ ] Reativar regra.
- [ ] Excluir regra com confirmacao.
- [ ] Validar mensagens de erro para regra incompleta.
- [ ] Testar acao gerada ao mover lead de etapa quando aplicavel.

## CRM > Cadencias

Rota: `/app/accounts/1/crm/settings/cadences`

Objetivo: configurar sequencias de nutricao e follow-up para leads/clientes.

Funcoes principais:

- Criar cadencia manual.
- Criar cadencia a partir de modelos rapidos.
- Editar cadencia.
- Ativar/pausar cadencia.
- Arquivar cadencia.
- Configurar passos com canal, acao, espera, mensagem/instrucao e condicoes.
- Inscrever/remover deal em cadencia quando disponivel.

Integracoes:

- `GET /crm/cadences`
- `POST /crm/cadences`
- `PATCH /crm/cadences/:id`
- `DELETE /crm/cadences/:id`
- `POST /crm/cadences/enroll_deal`
- `POST /crm/cadences/unenroll_deal`

Checklist QA:

- [ ] Criar cadencia manual com 2 passos.
- [ ] Criar cadencia a partir de cada modelo rapido disponivel.
- [ ] Salvar modelo e confirmar exibicao na lista.
- [ ] Editar passos, espera e canal.
- [ ] Ativar e pausar cadencia.
- [ ] Arquivar com confirmacao.
- [ ] Buscar por nome/canal/status.
- [ ] Validar empty state e tema claro/escuro.

## CRM > Scoring

Rota: `/app/accounts/1/crm/settings/scoring`

Objetivo: configurar pesos para classificacao de leads por pipeline e campanha.

Funcoes principais:

- Visualizar pipelines e campanhas com configuracao de scoring.
- Ajustar pesos de criterios.
- Salvar configuracao por pipeline.
- Salvar configuracao por campanha quando disponivel.
- Restaurar padroes.
- Validar soma/peso total e impacto em score.

Integracoes:

- `GET /crm/pipelines`
- `PATCH /crm/pipelines/:id`
- `POST /crm/lead-scores/recompute`
- APIs de campanhas quando a tela exibir campanhas.

Checklist QA:

- [ ] Abrir como administrador.
- [ ] Alterar pesos de um pipeline e salvar.
- [ ] Restaurar padrao.
- [ ] Validar erro quando configuracao estiver invalida.
- [ ] Recalcular score de lead e confirmar reflexo em Todos os Leads.
- [ ] Validar textos e controles em tema escuro.

## CRM > Motivos de Perda

Rota: `/app/accounts/1/crm/settings/loss-reasons`

Objetivo: manter motivos padronizados para fechamento perdido.

Funcoes principais:

- Listar motivos.
- Criar motivo quando disponivel.
- Editar motivo.
- Ativar/desativar ou ordenar quando disponivel.
- Usar motivo ao marcar lead como perdido.

Integracoes:

- `GET /crm/loss-reasons`
- `POST /crm/loss-reasons`
- `PATCH /crm/loss-reasons/:id`
- `POST /crm/deals/:id/mark_lost`

Checklist QA:

- [ ] Criar motivo de perda.
- [ ] Editar motivo.
- [ ] Marcar lead como perdido usando o motivo.
- [ ] Confirmar motivo em relatorios/metricas quando exibido.
- [ ] Validar bloqueio para agente sem permissao administrativa.

## Contatos > Todos os Contatos

Rota: `/app/accounts/1/contacts`

Objetivo: gerenciar base de contatos e relacionamento CRM.

Funcoes principais:

- Buscar contatos.
- Filtrar por relacionamento, etapa, categoria, responsavel e outros filtros disponiveis.
- Visualizar cards/lista de contatos.
- Alterar relacionamento: lead, cliente ou sem classificacao.
- Alterar responsavel.
- Abrir detalhes do contato.
- Selecionar contatos e aplicar acoes em massa.
- Enviar mensagem quando disponivel.

Integracoes:

- API de contatos.
- API de labels/categorias.
- `ContactCategoriesAPI`.
- Bulk actions.
- CRM quando relacionamento/owner/lifecycle altera lead/cliente.

Checklist QA:

- [ ] Buscar por nome, telefone e e-mail.
- [ ] Filtrar por lead.
- [ ] Filtrar por cliente.
- [ ] Mover contato de Lead para Cliente e recarregar.
- [ ] Confirmar que o contato nao some de Todos os Contatos.
- [ ] Confirmar que o contato aparece nos filtros corretos.
- [ ] Alterar responsavel e validar persistencia.
- [ ] Abrir detalhes do contato.
- [ ] Selecionar varios contatos e limpar selecao.
- [ ] Validar tema claro/escuro e hover do menu lateral.

## Contatos > Lista

Rota: `/app/accounts/1/contacts/list`

Objetivo: exibir todos os contatos em tabela CRM, com foco em leitura rapida, filtros e selecao em massa.

Funcoes principais:

- Mostrar tabela com checkbox, nome, relacionamento, etapa, categorias, responsavel, empresa, telefone e e-mail.
- Usar telefone como `tel:` e e-mail como `mailto:`.
- Mostrar `-` quando dado estiver vazio.
- Abrir contato ao clicar no nome.
- Selecionar contato individualmente ou todos os visiveis.
- Aplicar filtros proprios da Lista sem herdar estado de Categorias.

Integracoes:

- API de contatos.
- API de categorias/labels para chips.
- Bulk actions.

Checklist QA:

- [ ] Abrir `/contacts/list?page=1`.
- [ ] Confirmar que a pagina mostra tabela, nao cards.
- [ ] Confirmar que filtros de Categorias nao sao herdados.
- [ ] Aplicar filtro de relacionamento Lead.
- [ ] Aplicar filtro de relacionamento Cliente.
- [ ] Aplicar filtro de categoria.
- [ ] Aplicar filtro de etapa.
- [ ] Aplicar filtro de responsavel e sem responsavel.
- [ ] Clicar no nome e abrir detalhes.
- [ ] Validar links `tel:` e `mailto:`.
- [ ] Selecionar todos os visiveis e limpar selecao.
- [ ] Validar paginacao.

## Contatos > Categorias

Rotas:

- `/app/accounts/1/contacts/categories`
- `/app/accounts/1/contacts/categories/:kind`
- `/app/accounts/1/contacts/categories/:kind/:categoryId`

Objetivo: organizar listas/categorias em pastas e permitir importar/exportar contatos segmentados sem alterar a pagina Lista.

Pastas esperadas:

- Setor juridico.
- Localidade.
- Campanhas e listas.
- Origem.
- Restricoes.
- Outras categorias.

Funcoes principais:

- Ver pastas com quantidades.
- Abrir pasta.
- Criar categoria/lista.
- Editar categoria: nome, tipo, cor e descricao.
- Excluir categoria com confirmacao.
- Abrir lista/categoria especifica.
- Ver contatos da categoria.
- Importar contatos para a categoria.
- Exportar CSV.
- Exportar Google Sheet quando configurado.
- Ver historico de importacao e contadores de duplicados.

Integracoes:

- `ContactCategoriesAPI`
- `ContactAPI.importContacts`
- `ContactAPI.exportContactsCsv`
- `ContactAPI.exportContactsGoogleSheet`
- `data_imports.metadata` para historico/duplicados quando disponivel.

Checklist QA:

- [ ] Abrir Categorias e validar as pastas.
- [ ] Conferir icone em todas as pastas.
- [ ] Abrir cada pasta.
- [ ] Criar categoria em cada tipo principal.
- [ ] Editar nome, tipo, cor e descricao.
- [ ] Excluir categoria vazia.
- [ ] Excluir categoria com contatos vinculados e confirmar limpeza dos vinculos.
- [ ] Entrar em uma categoria e validar contatos associados.
- [ ] Importar CSV dentro da categoria.
- [ ] Importar contato duplicado e validar estrategia atualizar/sinalizar.
- [ ] Exportar CSV e conferir que contem apenas contatos da categoria.
- [ ] Exportar Google Sheet quando configurado.
- [ ] Abrir Contatos > Lista depois de usar Categorias e confirmar que a Lista mostra todos os contatos, sem filtro herdado.

## Detalhe e Edicao de Contato

Rota: `/app/accounts/1/contacts/:contactId`

Objetivo: editar dados cadastrais e relacionamentos de um contato que impactam CRM, segmentacao e atendimento.

Funcoes principais:

- Editar nome, telefone, e-mail, empresa e atributos.
- Ver/alterar labels/categorias.
- Ver conversas relacionadas.
- Ver resumo CRM quando disponivel.
- Mesclar ou tratar duplicidade quando a UI permitir.
- Atualizar relacionamento lead/cliente e responsavel CRM.

Checklist QA:

- [ ] Abrir contato a partir de Todos os Contatos.
- [ ] Abrir contato a partir de Lista.
- [ ] Editar telefone e e-mail.
- [ ] Alterar categorias/labels.
- [ ] Validar que as alteracoes aparecem em Lista e Categorias.
- [ ] Validar que relacionamento Lead/Cliente nao perde o contato.
- [ ] Confirmar que conversas vinculadas continuam visiveis.

## Empresas

Objetivo: validar impacto de empresas associadas aos contatos e leads.

Funcoes principais esperadas:

- Listar empresas.
- Buscar empresa.
- Criar/editar empresa quando disponivel.
- Vincular contato a empresa.
- Validar que empresa aparece em Contatos > Lista e Todos os Leads.

Checklist QA:

- [ ] Criar ou editar empresa de teste.
- [ ] Vincular contato a empresa.
- [ ] Confirmar empresa na tabela de contatos.
- [ ] Confirmar empresa em leads/deals vinculados quando aplicavel.
- [ ] Remover empresa e validar fallback `-` onde estiver vazio.

## Campanhas

Objetivo: validar segmentacao e disparos que dependem de contatos, categorias e CRM.

Funcoes principais esperadas:

- Criar campanha quando disponivel.
- Escolher audiencia por categoria/lista.
- Validar contato elegivel e contato restrito.
- Acompanhar entrega/eventos quando disponivel.
- Confirmar que campanhas nao alteram indevidamente relacionamento Lead/Cliente.

Checklist QA:

- [ ] Criar audiencia a partir de uma categoria.
- [ ] Confirmar quantidade de contatos esperada.
- [ ] Validar que contatos duplicados nao entram duas vezes.
- [ ] Validar opt-out/restricoes.
- [ ] Enviar campanha de teste somente se SMTP/canal estiver configurado.

## Conversas e Atendimento

Objetivo: validar criacao/atualizacao de CRM a partir de conversa real ou simulada.

Funcoes principais esperadas:

- Receber mensagem.
- Criar contato ou vincular contato existente.
- Gerar atendimento/deal via triagem CRM quando disponivel.
- Abrir contexto CRM pela conversa.
- Atualizar labels/categorias e relacionamento sem perder historico.

Integracoes:

- `POST /crm/triage/from-conversation/:conversation_id`
- Conversas, mensagens, labels e contato.

Checklist QA:

- [ ] Abrir conversa nova de numero conhecido.
- [ ] Confirmar contato vinculado.
- [ ] Acionar triagem CRM quando disponivel.
- [ ] Confirmar criacao/atualizacao de atendimento em Pipeline e Todos os Leads.
- [ ] Enviar nova mensagem do mesmo numero e confirmar que nao duplica contato indevidamente.
- [ ] Validar que historico de mensagens permanece acessivel.

## Fluxos Criticos Ponta a Ponta

### QA-FLUXO-001 - Contato vira Lead e Cliente

- [ ] Criar contato com nome, telefone e e-mail.
- [ ] Marcar como Lead.
- [ ] Validar em Contatos, Lista e Todos os Leads quando aplicavel.
- [ ] Mudar relacionamento para Cliente.
- [ ] Recarregar pagina.
- [ ] Confirmar que o contato continua visivel em Todos os Contatos e filtro Cliente.
- [ ] Confirmar que nao fica perdido fora das abas.

### QA-FLUXO-002 - Lead completo no funil

- [ ] Criar lead em Todos os Leads.
- [ ] Vincular contato existente.
- [ ] Abrir Pipeline e confirmar card na etapa correta.
- [ ] Mover para proxima etapa.
- [ ] Criar atividade.
- [ ] Concluir atividade.
- [ ] Marcar lead como ganho ou perdido.
- [ ] Validar reflexo em Relatorios e Metricas.

### QA-FLUXO-003 - Pipeline e etapas

- [ ] Criar pipeline `QA Comercial`.
- [ ] Criar 3 etapas.
- [ ] Editar uma etapa.
- [ ] Reordenar etapas.
- [ ] Criar lead nesse pipeline.
- [ ] Alternar para outro pipeline e confirmar isolamento.
- [ ] Arquivar etapa sem deal.
- [ ] Tentar arquivar etapa com deal e validar comportamento esperado.

### QA-FLUXO-004 - Agenda com Google

- [ ] Abrir Agenda com Google desconectado.
- [ ] Criar reuniao local.
- [ ] Conectar Google.
- [ ] Sincronizar reuniao.
- [ ] Validar link Meet/Calendar.
- [ ] Reagendar e sincronizar de novo.
- [ ] Importar eventos do Google sem duplicar.

### QA-FLUXO-005 - Categorias, importacao e duplicados

- [ ] Criar categoria `QA Remarketing`.
- [ ] Importar CSV com 5 contatos.
- [ ] Importar novamente com 2 contatos duplicados e dados atualizados.
- [ ] Confirmar que duplicados foram atualizados, nao clonados.
- [ ] Exportar categoria.
- [ ] Abrir Lista e confirmar que nao herdou filtro da categoria.

### QA-FLUXO-006 - Automacao, checklist e cadencia

- [ ] Criar checklist de documentos.
- [ ] Criar automacao vinculada a mudanca de etapa.
- [ ] Criar cadencia de follow-up.
- [ ] Mover lead para etapa gatilho.
- [ ] Confirmar criacao de atividade/cadencia/checklist conforme configuracao.
- [ ] Pausar/arquivar cadencia e validar que nao segue executando.

## Checklist de Permissoes

- [ ] Administrador acessa todas as paginas CRM.
- [ ] Agente acessa paginas operacionais permitidas.
- [ ] Agente nao acessa configuracoes administrativas quando bloqueadas.
- [ ] Usuario sem `CRM` ou sem permissao recebe bloqueio/redirect adequado.
- [ ] Acoes destrutivas exigem permissao correta.

## Checklist de Busca Global e Local

Validar nas paginas: Pipeline, Todos os Leads, Atividades, Agenda, Cadencias, Checklists, Automacoes, Contatos, Lista e Categorias.

- [ ] Placeholder nao sobrepoe icone.
- [ ] Texto digitado fica legivel.
- [ ] Busca com acento e sem acento quando aplicavel.
- [ ] Busca por nome parcial.
- [ ] Busca por telefone parcial.
- [ ] Busca sem resultado mostra estado vazio correto.
- [ ] Limpar busca restaura a lista.
- [ ] Busca nao aplica filtros invisiveis de outra pagina.

## Checklist de Tema Claro e Escuro

- [ ] Menu lateral ativo legivel.
- [ ] Hover de menu legivel.
- [ ] Cards com bordas e icones visiveis.
- [ ] Badges de prioridade/score/categoria legiveis.
- [ ] Inputs com placeholder e texto em contraste correto.
- [ ] Modais/drawers sem fundo transparente indevido.
- [ ] Tabelas com header, linhas, links e checkbox legiveis.
- [ ] Scrollbars nao escondem conteudo.

## Checklist Mobile/Responsivo

Testar em largura aproximada de 390px, 768px, 1366px e 1920px.

- [ ] Menu recolhido nao cobre conteudo.
- [ ] Filtros empilham sem sobrepor.
- [ ] Tabelas permitem rolagem horizontal quando necessario.
- [ ] Cards nao cortam textos essenciais.
- [ ] Botoes de acao ficam acessiveis.
- [ ] Drawers/modais cabem na tela e rolam internamente.
- [ ] Agenda continua utilizavel em mobile.

## Estados de Erro e Recuperacao

Validar sempre que possivel:

- [ ] API retorna erro e tela mostra mensagem amigavel.
- [ ] Loading nao bloqueia a pagina indefinidamente.
- [ ] Acao de salvar com erro preserva dados digitados.
- [ ] Exclusao cancelada nao altera dados.
- [ ] Google desconectado permite salvar localmente.
- [ ] SMTP/canal nao configurado bloqueia envio com mensagem clara.
- [ ] Sem internet/servidor indisponivel nao quebra layout.

## Dados Sensíveis

Durante o QA:

- Nao registrar senhas, tokens, refresh tokens, client secrets ou chaves de API em prints, comentarios ou tickets.
- Ao testar Google, SMTP ou campanhas, usar contas de teste.
- Ao exportar CSV/Sheets, remover arquivos gerados se contiverem dados reais.

## Criterios de Aceite do QA

O CRM deve ser considerado aprovado quando:

- Todas as rotas principais carregam sem erro 500/404.
- Nenhuma pagina critica perde dados ao salvar/editar/excluir.
- Contatos movidos entre Lead e Cliente continuam visiveis e filtraveis.
- Pipelines e etapas criados aparecem nas telas operacionais corretas.
- Atividades e Agenda persistem, sincronizam quando configurado e falham de forma recuperavel quando nao configurado.
- Categorias nao interferem nos filtros da Lista.
- Busca funciona sem layout quebrado nas paginas principais.
- Tema claro e tema escuro estao legiveis.
- Mobile nao impede execucao dos fluxos principais.

## Anexo: APIs CRM Mapeadas

Base: `/api/v1/accounts/:account_id/crm`

- `GET /google_authorization`
- `POST /google_authorization`
- `GET /dashboard`
- `GET /health`
- `GET /pipelines`
- `POST /pipelines`
- `PATCH /pipelines/:id`
- `DELETE /pipelines/:id`
- `GET /pipelines/archived`
- `PATCH /pipelines/:id/restore`
- `DELETE /pipelines/:id/purge`
- `GET /pipelines/:pipeline_id/stages`
- `POST /pipelines/:pipeline_id/stages`
- `PATCH /pipelines/:pipeline_id/stages/:id`
- `DELETE /pipelines/:pipeline_id/stages/:id`
- `GET /pipelines/:pipeline_id/stages/archived`
- `PATCH /pipelines/:pipeline_id/stages/:id/restore`
- `DELETE /pipelines/:pipeline_id/stages/:id/purge`
- `GET /deals`
- `GET /deals/:id`
- `POST /deals`
- `PATCH /deals/:id`
- `DELETE /deals/:id`
- `POST /deals/export`
- `POST /deals/bulk_action`
- `DELETE /deals/purge_orphans`
- `POST /deals/:id/move`
- `POST /deals/:id/mark_won`
- `POST /deals/:id/mark_lost`
- `POST /deals/:id/reopen`
- `POST /deals/:id/archive`
- `POST /deals/:id/discard`
- `POST /deals/:id/mark_base_client`
- `GET /loss-reasons`
- `POST /loss-reasons`
- `PATCH /loss-reasons/:id`
- `GET /activities`
- `POST /activities`
- `PATCH /activities/:id`
- `DELETE /activities/:id`
- `GET /activities/calendar`
- `POST /activities/import_google_calendar`
- `POST /activities/suggest_schedule`
- `POST /activities/schedule_suggestion`
- `POST /activities/:id/complete`
- `POST /activities/:id/snooze`
- `POST /activities/:id/sync_google_calendar`
- `GET /audit-events`
- `GET /checklist-templates`
- `POST /checklist-templates`
- `PATCH /checklist-templates/:id`
- `DELETE /checklist-templates/:id`
- `GET /automation-rules`
- `POST /automation-rules`
- `PATCH /automation-rules/:id`
- `DELETE /automation-rules/:id`
- `GET /cadences`
- `POST /cadences`
- `PATCH /cadences/:id`
- `DELETE /cadences/:id`
- `POST /cadences/enroll_deal`
- `POST /cadences/unenroll_deal`
- `POST /lead-scores/recompute`
- `POST /triage/from-conversation/:conversation_id`
- `POST /analyst/ask`
- `GET /metrics/overview`
- `GET /metrics/stage_funnel`
- `GET /metrics/time_in_stage`
- `GET /metrics/win_loss_trend`
- `GET /metrics/top_loss_reasons`
- `GET /metrics/score_by_stage`
- `GET /metrics/area_distribution`
- `GET /metrics/top_deals`
- `GET /metrics/stale_deals`

## Registro de Execucao QA

Use esta tabela para registrar uma rodada.

| Data | Ambiente | QA | Perfil | Resultado geral | Observacoes |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |

Use esta tabela para registrar bugs.

| ID | Pagina/fluxo | Severidade | Passos para reproduzir | Resultado esperado | Resultado atual | Evidencia |
| --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |
