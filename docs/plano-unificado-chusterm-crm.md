# Plano Unificado ChusteRM CRM Conversacional

> Versao: 1.12
> Atualizado em: 2026-05-06
> Fontes consolidadas:
> - `docs/crm-improvements-plan.md`
> - `docs/projeto_melhorias_chatwoot_fork_socialhub_kommo (1).md`

Este documento unifica o PRD Kommo/SocialHub, o plano tecnico do CRM juridico e o historico de execucao ja registrado no projeto. A partir daqui, ele deve ser usado como documento vivo principal para check-up, continuidade automatica de fases e priorizacao dos proximos blocos.

## 1. Decisao de Arquitetura

O CRM oficial do ChusteRM vive dentro do `core/`, reaproveitando as entidades e fluxos nativos do Chatwoot. Servicos paralelos como `services/crm-service` e `services/crm-ui` ficam apenas como legado/prototipo tecnico e nao devem receber novas funcionalidades de produto.

Fontes de verdade principais:

- `Contact`: identidade, Lead/Cliente, ciclo de vida, responsavel CRM, atributos adicionais, origem/lista e opt-out.
- `Conversation`: atendimento, responsavel da conversa, mensagens, anexos e contexto operacional.
- `CrmDeal`: funil juridico, etapa, status operacional, origem, descarte, arquivamento e Cliente Base.
- `Label`: taxonomia juridica governada, aplicavel a contato e conversa.
- `CrmActivity`: tarefas, agenda, follow-up, reunioes e sincronizacao Google.
- `Campaign`: campanhas WhatsApp/SMS, audiencia, preview, eventos de entrega e metricas.
- `Captain`: IA com contexto CRM, playbooks, conhecimento versionado e entendimento de midia.

## 2. Leitura de Status

- `[x]` Entregue e registrado no historico recente.
- `[~]` Parcial, implementado em parte ou aguardando validacao visual/operacional.
- `[ ]` Pendente, ainda nao implementado ou nao confirmado.

Quando um checklist antigo contradiz o historico mais recente, prevalece o historico mais recente das fases 8 a 27 e da secao "Status de execucao no ChusteRM Core".

## 3. Resumo Executivo Consolidado

O ChusteRM ja deixou de ser apenas um fork de atendimento e passou a ter um CRM conversacional juridico dentro do Core. Os blocos mais importantes de funil, contatos, ficha 360, campanhas, cadencias, Google Workspace, opt-out, metricas iniciais, auditoria e contexto do Capitao ja foram implementados.

Ainda faltam tres frentes grandes para completar a visao Kommo/SocialHub:

- Automacoes visuais mais proximas de Salesbot, com builder amigavel para etapas, condicoes e acoes.
- Email marketing completo, com editor, templates, infraestrutura SMTP/dominio, tracking e IA de criacao.
- Passada final de UI/UX e design system em todas as paginas, validando tema claro/escuro, menus, cabecalhos, espacamentos e responsividade com dados reais.

## 4. O Que Ja Foi Feito

### 4.1 Core CRM, funil e operacao juridica

- [x] Direcao corrigida para implementar tudo dentro de `core/`.
- [x] Lifecycle de contato e classificacao Lead/Cliente.
- [x] Responsavel CRM (`crm_owner_id`) separado do atendente da conversa.
- [x] Regras de preenchimento de responsavel por assignee e area juridica.
- [x] Alerta de lead quente sem responsavel.
- [x] Kanban juridico com etapas configuraveis.
- [x] Campos obrigatorios por etapa do funil.
- [x] Renomeacao inline do lead no card.
- [x] Busca por telefone normalizado/parcial no pipeline e no endpoint de deals.
- [x] Bulk actions no Kanban/lista: mover etapa, arquivar, descartar, mudar origem, atribuir responsavel e aplicar etiqueta.
- [x] Origem estruturada do lead com detalhe livre (`source_detail`).
- [x] Status operacional: Cliente Base, Cliente Convertido, Retorno de Cliente, spam, invalido, duplicado, nao lead e arquivado.
- [x] Descarte rapido no card com motivo padronizado, auditoria e preservacao de metricas.
- [x] Cliente Base e reabertura sem apagar historico.
- [x] Relatorios de saneamento: origem, status operacional, clientes da base e descartes.

### 4.2 Labels, taxonomia e governanca de etiquetas

- [x] Labels juridicas padronizadas por categoria.
- [x] Nome visual humano (`display_title`) sem quebrar slugs tecnicos.
- [x] Sincronizacao de labels de contato e conversa.
- [x] Agrupamento de labels por categoria nos seletores.
- [x] Ocultacao de labels juridicas sistemicas do menu principal.
- [x] Labels documentais automaticas a partir de OCR/descricao de midia.
- [x] Contexto do Capitao usando slugs padronizados.

### 4.3 Conversa, sidebar CRM e ficha 360

- [x] Sidebar CRM dentro da conversa conectando Chat, Contato e CRM.
- [x] Criar/vincular lead a partir da conversa.
- [x] Exibir e editar Lead/Cliente, owner CRM, atendente responsavel, etiquetas, lead vinculado e tarefa contextual.
- [x] Ficha 360 do lead com contato, conversas, ultimas mensagens, anexos, eventos de campanha, atividades, auditoria e dados LGPD.
- [x] Abas operacionais, labels humanizadas e delegacao do responsavel por responder.
- [x] Historico completo preservado para retornos e Cliente Base.

### 4.4 Contatos, listas, importacao e segmentacao

- [x] Importacao CSV com nome da lista, etiquetas padrao, area juridica, Lead/Cliente e responsavel.
- [x] Processamento de CSV com `labels`, `source_list`, `relationship_status`, `lifecycle_stage`, `legal_area` e `crm_owner_email`.
- [x] Label de lista criada/aplicada automaticamente.
- [x] Historico visual de importacoes com status, totais, falhas e download de erros.
- [x] Preview de colunas e primeiras linhas antes da importacao.
- [x] Mapeamento avancado de colunas.
- [x] Politicas de duplicidade: atualizar, ignorar ou criar novo preservando dados originais.
- [x] Filtros avancados de contato por Lead/Cliente, etapa, responsavel, lista de origem, area juridica e etiqueta.
- [x] Segmentos/listas salvos a partir de filtros.
- [x] Exportacao direta CSV respeitando filtros, segmentos e listas.
- [x] Exportacao para Google Sheets/Drive via OAuth.
- [~] Validacao visual final da pagina de contatos com listas reais, etiquetas reais e exportacao por segmento.

### 4.5 Campanhas, audiencias, metricas e opt-out

- [x] Campanhas WhatsApp e SMS por etiqueta, lista importada e segmento salvo.
- [x] Resolucao de audiencia por `ContactSegment` e `SourceList`.
- [x] Contador de audiencia antes do disparo.
- [x] Preview de audiencia com amostra de contatos.
- [x] Campanhas registram estatisticas iniciais: total, enviado, ignorado e falhou.
- [x] Eventos de entrega por contato com provider e `external_id`.
- [x] Webhooks WhatsApp Cloud, Evolution, Twilio e Bandwidth alimentando metricas.
- [x] Tracking de `delivered`, `read`, `failed`, respostas e conversoes.
- [x] Opt-out automatico por respostas como SAIR, STOP, CANCELAR, DESCADASTRAR e UNSUBSCRIBE.
- [x] Audiencias excluem contatos com opt-out em contagem, preview e envio.
- [x] Disparos fazem checagem defensiva e registram `skipped` com motivo `campaign_opt_out`.

### 4.6 Cadencias e automacoes tecnicas

- [x] Cadencias com passos e canais.
- [x] Condicionais avancadas por deal, etapa, contato, atributos adicionais e opt-out.
- [x] Operadores `eq`, `not_eq`, `in`, `not_in`, `present`, `blank`, `gt`, `gte`, `lt`, `lte`.
- [x] Comportamento quando condicao falha: pular passo, pausar enrollment ou cancelar enrollment.
- [x] Auditoria de passos ignorados por condicao.
- [x] UI com campo `Condicoes JSON` e seletor de comportamento.
- [x] Builder visual inicial de condicoes para automacoes, sem exigir JSON manual para regras comuns.
- [~] Canvas completo estilo Salesbot, simulador visual e publicacao guiada ainda pendentes.

### 4.7 Agenda, Google Calendar e Meet

- [x] Atividades CRM com filtros, status, prioridade, periodo, responsavel e caso.
- [x] Exportacao `.ics` respeitando filtros da agenda.
- [x] Link direto para criar evento no Google Agenda.
- [x] OAuth Google Calendar/Meet.
- [x] Criacao e atualizacao de evento Google com `event_id`, link e Meet.
- [x] Importador de eventos Google Calendar para criar/atualizar atividades CRM.
- [x] Botao `Importar Google` na tela de atividades.
- [x] Agendamento por IA deterministico com sugestoes de horarios, aceite, criacao de atividade e sincronizacao opcional Google Calendar/Meet.
- [~] Validacao operacional com conta Google real, templates de lembrete e UX de reagendamento ainda pendentes.

### 4.8 Capitao, IA, audio, imagem e documentos

- [x] `Captain::CrmContextBuilder` com contexto de deal, responsavel, documentos e proxima acao.
- [x] Tools de CRM no Core.
- [x] Handoff com resumo CRM.
- [x] Acoes essenciais do Capitao em modo deterministico compativel com Gemini.
- [x] Playbooks por area juridica.
- [x] Knowledge Base com fontes versionadas e snapshots.
- [x] Modo Analista CRM inicial para perguntas em linguagem natural sobre contatos, listas, campanhas e funil.
- [x] Provider de transcricao/midia separado do provider de chat.
- [x] Jobs de transcricao de audio e entendimento de midia.
- [x] OCR/descricao salvos em `Attachment#meta`.
- [x] Midia incluida em `Message#content_for_llm`.
- [x] UI de status de processamento.
- [~] Bot visual com blocos, qualificacao, score e handoff visual ainda pendente.

### 4.9 Relatorios e saude operacional

- [x] Check-up operacional via rake task.
- [x] Medicao de contatos sem Lead/Cliente/lifecycle/responsavel.
- [x] Medicao de leads quentes sem responsavel.
- [x] Medicao de labels sistemicas visiveis no menu.
- [x] Medicao de midia parada em processamento.
- [x] Medicao de atividades pendentes, vencidas e do dia.
- [x] Painel visual de metricas dentro do CRM.
- [x] Alerta recorrente para saude `attention`.
- [x] Dashboard executivo com KPIs, insights, funil, area, urgencia e prioridade.
- [x] Relatorios de campanha com metricas de entrega.
- [~] ROI por origem, SLA e dashboard de IA precisam maturacao com dados reais.

### 4.10 UI/UX e design system

- [x] Paginas CRM principais passaram por ajustes de overflow, responsividade e filtros: pipeline, atividades, relatorios, checklists, automacoes, cadencias, scoring, ficha 360, pipelines, motivos de perda e metricas.
- [x] Tela de contatos reorganizada para segmentacao, filtros rapidos e leitura CRM.
- [x] Ajustes recentes de tema claro/escuro, hover do menu, cabecalhos de configuracao, busca lateral, botao de composicao e opcao de recolher menu lateral.
- [x] Passada adicional de design system em menus, cabecalhos de configuracao, superficies, foco, disabled, popovers, contraste e responsividade.
- [~] Falta validacao visual completa em todas as paginas com dados reais, principalmente fluxos profundos, dialogs raros e tema claro/escuro em navegacao real.

## 5. O Que Ainda Precisa Ser Feito

### 5.1 Pendencias P0

- [ ] Validar visualmente `/app/accounts/1/contacts` com listas importadas reais, etiquetas reais e exportacao por segmento.
- [ ] Fazer check-up visual completo em tema claro e escuro nas paginas principais.
- [~] Revisar todos os menus e cabecalhos restantes para remover textos em ingles, padronizar icones, espacamentos e hierarquia.
- [~] Validar menu lateral recolhido somente com icones em todas as rotas principais.
- [x] Testar hover/focus/active dos menus em claro e escuro com contraste acessivel via CSS global e build.
- [~] Validar que dialogs, tooltips, selects e popovers nao estouram largura nem ficam sem contraste.

### 5.2 Pendencias P1

- [x] Agendamento por IA integrado a atividades, Google Calendar e Meet.
- [~] Builder visual de automacoes mais proximo de Salesbot.
- [ ] Builder visual de bot com blocos de conversa, qualificacao, score e transferencia humana.
- [~] Editor visual de email marketing.
- [~] Templates de email com IA de criacao.
- [ ] Infraestrutura SMTP/dominio proprio.
- [~] Tracking de email: entregas, aberturas, cliques, respostas e conversao.
- [ ] Cadencias multicanal incluindo email.
- [ ] Dashboard de ROI por origem, campanha, area juridica e responsavel.
- [ ] Dashboard de IA com qualidade de respostas, handoffs e uso por area.

### 5.3 Pendencias P2

- [ ] Permissoes granulares de CRM por papel.
- [ ] Politicas LGPD completas: consentimento, retencao, mascaramento e logs sensiveis.
- [ ] Biblioteca visual de playbooks e automacoes juridicas.
- [ ] Templates juridicos por area, etapa e campanha.
- [ ] Integracoes brasileiras inspiradas na SocialHub: pagamentos, ecommerce, ERP/financeiro e webhooks publicos.
- [ ] API publica documentada para operacoes CRM essenciais.
- [ ] Otimizacoes de performance para bases maiores, Kanban grande e audiencias extensas.

## 6. Roadmap Unificado

### Bloco A - Estabilizacao visual e check-up de produto

Objetivo: garantir que o sistema esteja profissional em tema claro e escuro antes de abrir novas frentes grandes.

- [~] Rodar validacao visual das paginas: contatos, pipeline, conversa, ficha 360, atividades, campanhas, cadencias, automacoes, relatorios, configuracoes e usuarios.
- [~] Conferir menu lateral aberto/recolhido em desktop e telas estreitas.
- [x] Padronizar cabecalhos com icone, titulo em portugues, breadcrumb/voltar e acoes nas superficies de configuracao.
- [x] Remover textos residuais em ingles como "Operational Path" e "Unified settings surface" dos cabecalhos ajustados.
- [x] Corrigir contraste de hover, active e disabled.
- [x] Registrar evidencias do check-up no final deste documento.

### Bloco B - Agendamento inteligente

Objetivo: transformar a agenda atual em fluxo operacional com IA.

- [x] Sugerir horarios com base em disponibilidade, tipo de atendimento e responsavel.
- [x] Criar atividade e evento Google/Meet a partir de sugestao da IA.
- [x] Registrar auditoria da sugestao e aceite.
- [ ] Permitir templates juridicos de confirmacao e lembrete.

### Bloco C - Automacoes visuais e Salesbot juridico

Objetivo: tornar regras e cadencias configuraveis sem JSON manual.

- [~] Criar canvas/lista visual de gatilho, condicoes e acoes.
- [x] Permitir condicoes por etapa, status, area, etiqueta, origem, responsavel, opt-out e campos adicionais.
- [ ] Permitir acoes: criar tarefa, mudar etapa, aplicar etiqueta, atribuir responsavel, enviar mensagem, webhook e pausar/cancelar cadencia.
- [ ] Adicionar validacao antes de publicar regra.
- [ ] Exibir simulacao da automacao em um lead real.

### Bloco D - Email marketing integrado

Objetivo: completar a cobertura SocialHub com canal de email.

- [~] Editor visual simples.
- [~] Templates por area juridica e etapa.
- [~] IA para assunto/corpo com guardrails juridicos.
- [ ] SMTP/dominio proprio.
- [ ] Tracking de email.
- [~] Inclusao de email em segmentos, campanhas e cadencias.

### Bloco E - Governanca, seguranca e escala

Objetivo: preparar uso comercial com auditoria, LGPD e operacao grande.

- [ ] Permissoes CRM por modulo e acao.
- [ ] Logs/auditoria para mudancas sensiveis.
- [ ] Consentimento, retencao e mascaramento.
- [ ] Relatorios de SLA, ROI e qualidade de IA.
- [ ] Performance para funis, contatos e audiencias grandes.

## 7. Checklist Mestre Consolidado

### CRM

- [x] Pipeline juridico.
- [x] Etapas configuraveis.
- [x] Kanban com operacao rapida.
- [x] Lista de leads/contatos com filtros CRM.
- [x] Ficha 360.
- [x] Origem de lead.
- [x] Origem por dropdown.
- [x] Busca por telefone.
- [x] Busca por telefone normalizado.
- [x] Bulk actions.
- [x] Spam/Lixeira no card.
- [x] Arquivar com motivo.
- [x] Cliente Base.
- [x] Reingresso/retorno de cliente.
- [x] Responsavel CRM.
- [x] Tags/labels governadas.
- [x] Campos obrigatorios por etapa.
- [x] Renomeacao inline.
- [~] Valor de oportunidade e campos comerciais avancados.
- [~] Deteccao automatica de nome generico.
- [ ] Multiplos pipelines com experiencia completa de administracao.

### Conversa

- [x] Sidebar de lead.
- [x] Criar lead da conversa.
- [x] Vincular conversa ao lead.
- [x] Criar tarefa contextual.
- [x] Timeline operacional na ficha 360.
- [~] Criar nota/agendamento diretamente por todos os pontos de entrada.
- [~] Composer com acoes rapidas totalmente padronizado.

### Automacao

- [x] Regras tecnicas por etapa.
- [x] Condicoes avancadas em cadencias.
- [x] Acoes de tarefa, etiqueta, responsavel, mensagem e webhook em automacoes juridicas.
- [x] Alertas de inatividade e saude operacional.
- [~] Interface visual completa para criar/editar regras.
- [ ] Simulador visual de automacao.

### Bot e IA

- [x] Contexto CRM no Capitao.
- [x] Playbooks juridicos.
- [x] Base de conhecimento versionada.
- [x] Resumo/handoff CRM.
- [x] Analista CRM inicial.
- [x] Audio, imagem e documento no contexto.
- [~] Sugestao de resposta e qualificacao guiada por UI final.
- [ ] Builder visual de bot.
- [ ] Score visual configuravel.
- [ ] Transferencia humana configuravel no builder.

### Agenda

- [x] Eventos.
- [x] Tarefas.
- [x] Lembretes.
- [x] Exportacao ICS.
- [x] Google Calendar.
- [x] Google Meet.
- [x] Importacao Google Calendar.
- [x] Agendamento por IA.

### Campanhas

- [x] Campanhas WhatsApp.
- [x] Campanhas SMS.
- [x] Importacao CSV/XLSX.
- [x] Listas importadas.
- [x] Segmentos salvos.
- [x] Preview de audiencia.
- [x] Cadencias.
- [x] Templates.
- [x] Condicionais.
- [x] Relatorios.
- [x] Opt-out.
- [x] Metricas por provedor.
- [ ] Revisao final pre-disparo mais completa.

### Email

- [~] Editor visual.
- [~] Templates.
- [~] IA para criacao.
- [ ] SMTP.
- [ ] Dominio proprio.
- [ ] Tracking.
- [ ] Cadencias com email.

### Relatorios

- [x] Pipeline/funil inicial.
- [x] Atividades.
- [x] Campanhas.
- [x] Saneamento de base.
- [x] Origem.
- [x] Descartes por motivo.
- [x] Clientes da base/retornos.
- [x] Responsavel.
- [~] Atendimento/SLA.
- [~] Agentes.
- [~] IA.
- [~] Exportacao de todos os dashboards.
- [ ] ROI por origem.

### Seguranca e LGPD

- [x] Auditoria de mudancas CRM principais.
- [x] Dados LGPD visiveis na ficha 360.
- [~] Permissoes granulares.
- [~] Consentimento formal.
- [~] Retencao.
- [~] Mascaramento.
- [~] Logs sensiveis revisados.

## 8. Validacoes Ja Registradas

As fases recentes registraram as seguintes validacoes:

- ESLint nos componentes Vue alterados.
- Prettier nos arquivos frontend alterados.
- Sintaxe Ruby em models, services, controllers, rotas e migracoes.
- Build Vite.
- Build Docker `core` e `sidekiq`.
- Rebuild/restart dos servicos `core`, `sidekiq` e `core-vite`.
- Smoke HTTP em `http://localhost:3010/` retornando `200`.
- `crm:health_check ACCOUNT_ID=1` retornando `status: ok`.
- Rotas Google Calendar/Sheets/OAuth confirmadas via `rails routes`.
- Migracao `20260506000001` aplicada e confirmada como `up`.

## 9. Proximo Check-up Recomendado

Antes de abrir o Bloco B, o check-up recomendado e:

- [ ] Abrir o sistema em tema claro e escuro.
- [ ] Percorrer menu lateral aberto e recolhido.
- [ ] Validar cabecalhos, icones, textos em portugues e botoes de acao.
- [ ] Testar `/app/accounts/1/contacts` com listas/etiquetas reais.
- [ ] Criar/exportar um segmento para CSV e Google Sheets.
- [ ] Abrir uma conversa real e conferir sidebar CRM.
- [ ] Abrir um lead na ficha 360 e conferir mensagens, anexos, campanhas, atividades e auditoria.
- [ ] Criar uma campanha com preview de audiencia e validar exclusao de opt-out.
- [ ] Criar/editar uma cadencia com condicoes.
- [ ] Sincronizar uma atividade com Google Calendar/Meet e importar eventos.

## 10. Regra de Manutencao do Documento

Ao fechar cada bloco:

- Atualizar a secao correspondente em "O Que Ja Foi Feito".
- Mover pendencias concluidas para `[x]`.
- Registrar validacoes executadas.
- Adicionar o proximo bloco natural ao roadmap, se surgir.
- Manter os documentos antigos como referencia historica, mas usar este arquivo como fonte principal de acompanhamento.

## 11. Execucao automatica - 2026-05-06

Esta rodada leu novamente os tres documentos abertos no IDE e executou os blocos naturais do plano unificado dentro do `core/`, mantendo o ChusteRM Core como fonte unica do CRM.

### Bloco A - UI/UX e design system

- [x] Ajustados cabecalhos de configuracao para remover textos residuais em ingles, melhorar hierarquia, quebra de titulo e status em portugues.
- [x] Fortalecido o CSS global do tema ChusteRM para menus, hover, active, focus, disabled, popovers, superficies, tema claro e tema escuro.
- [x] Reforcados contrastes do menu lateral e estados recolhidos/expandidos para reduzir os problemas vistos nos prints.
- [~] Ainda precisa de check-up visual humano em navegacao real, principalmente dialogs raros, telas com muitos dados e comparacao fino entre claro/escuro.

Arquivos principais:

- `core/app/javascript/dashboard/assets/css/chusterm-theme.css`
- `core/app/javascript/dashboard/routes/dashboard/settings/SettingsWrapper.vue`
- `core/app/javascript/dashboard/routes/dashboard/settings/SettingsHeader.vue`
- `core/app/javascript/dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue`

### Bloco B - Agendamento inteligente

- [x] Criado servico `Crm::ScheduleSuggestionService` para sugerir horarios uteis, respeitando janela comercial, duracao, responsavel, prioridade e conflitos de atividades.
- [x] Criados endpoints `suggest_schedule` e `schedule_suggestion` em atividades CRM.
- [x] A tela de atividades ganhou painel de sugestoes de horario, aceite de slot e opcao de sincronizar Google Calendar/Meet.
- [x] Aceite de sugestao registra auditoria `activity_scheduled_by_ai`.
- [~] Falta validar com uma conexao Google real e evoluir templates juridicos de confirmacao/lembrete.

Arquivos principais:

- `core/app/services/crm/schedule_suggestion_service.rb`
- `core/app/controllers/api/v1/accounts/crm/activities_controller.rb`
- `core/config/routes.rb`
- `core/app/javascript/dashboard/api/crm.js`
- `core/app/javascript/dashboard/routes/dashboard/crm/pages/Activities.vue`

### Bloco C - Automacoes visuais

- [x] Automacoes de etapa passaram a avaliar condicoes antes da execucao, reaproveitando `Crm::CadenceConditionEvaluator`.
- [x] Quando uma condicao falha, a automacao registra auditoria `automation_skipped_by_condition`.
- [x] Tela de regras recebeu builder visual de condicoes por campo, operador e valor, evitando JSON manual para casos comuns.
- [~] Canvas completo estilo Salesbot, simulador em lead real e publicacao guiada seguem como proximo endurecimento do bloco.

Arquivos principais:

- `core/app/services/crm/stage_automation.rb`
- `core/app/javascript/dashboard/routes/dashboard/crm/pages/AutomationRules.vue`

### Bloco D - Email marketing integrado

- [x] Campanhas passaram a aceitar inbox do tipo `Email` para disparo one-off.
- [x] Criado `CampaignMailer` com personalizacao Liquid basica e corpo HTML/texto.
- [x] Criado `Email::OneoffCampaignService` para resolver audiencia, respeitar bloqueios/opt-out e registrar entregas, pulos e falhas.
- [x] Campanhas ganharam rota e pagina `Email`, com formulario de assunto, conteudo, inbox, audiencia, agendamento, preview e rascunho assistido.
- [~] Ainda faltam SMTP/dominio proprio, editor visual robusto, tracking real de abertura/clique/resposta e cadencias multicanal com email.

Arquivos principais:

- `core/app/models/campaign.rb`
- `core/app/mailers/campaign_mailer.rb`
- `core/app/services/email/oneoff_campaign_service.rb`
- `core/app/services/campaigns/audience_resolver.rb`
- `core/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignDialog.vue`
- `core/app/javascript/dashboard/components-next/Campaigns/Pages/CampaignPage/EmailCampaign/EmailCampaignForm.vue`
- `core/app/javascript/dashboard/routes/dashboard/campaigns/pages/EmailCampaignsPage.vue`

### Bloco E - Governanca e escala

- [x] Resolvedor de audiencia passou a expor contatos com email, sem email e bloqueados.
- [x] Audiencias de campanha agora ignoram contatos bloqueados, alem dos contatos com opt-out ja tratados.
- [x] Servicos de email registram motivos de skip como `missing_email`, `campaign_opt_out` e falhas de entrega.
- [~] Permissoes granulares, retencao, mascaramento e revisao completa de logs sensiveis seguem como P2 de governanca.

### Validacoes desta rodada

- [x] Sintaxe Ruby validada nos services, controller, model, mailer e rotas alterados.
- [x] ESLint aprovado nos componentes Vue/JS alterados.
- [x] Prettier aprovado nos componentes Vue/JS/CSS alterados.
- [x] `pnpm exec vite build` executado com sucesso.
- [x] Smoke HTTP em `http://localhost:3010/` retornou `200`.
- [~] `rails routes` nao foi executado localmente porque o bundle Ruby do Windows esta sem gems nativas (`stackprof` e `io-console`); a validacao de rotas ficou coberta por sintaxe Ruby e build frontend.

### Proxima revisao recomendada

- [ ] Fazer check-up visual humano no navegador em tema claro e escuro.
- [ ] Criar uma atividade real usando sugestao de horario e testar sincronizacao Google/Meet.
- [ ] Criar uma regra com condicoes visuais e simular em um lead real.
- [ ] Criar campanha de email em ambiente de teste com inbox Email configurada.
- [ ] Medir pontos restantes de design system depois do uso real.

## 12. Proximo passo executado - Hardening de entrega - 2026-05-06

Apos a conclusao dos blocos A a E, o proximo passo foi transformar a entrega em algo mais seguro para check-up operacional.

### Cobertura adicionada

- [x] Criado spec de `Crm::ScheduleSuggestionService` cobrindo sugestoes em horario comercial e exclusao de janelas ocupadas.
- [x] Criado spec de `Campaigns::AudienceResolver` cobrindo contatos elegiveis, bloqueados, opt-out, email e preview.
- [x] Criado spec de `Email::OneoffCampaignService` cobrindo envio, skip por email ausente e estatisticas iniciais.

Arquivos:

- `core/spec/services/crm/schedule_suggestion_service_spec.rb`
- `core/spec/services/campaigns/audience_resolver_spec.rb`
- `core/spec/services/email/oneoff_campaign_service_spec.rb`

### Correcao de empacotamento Docker

- [x] Corrigido `core/Dockerfile` para copiar `app/services/email/` para dentro da imagem.
- [x] Corrigido `core/Dockerfile` para copiar `app/mailers/campaign_mailer.rb` para dentro da imagem.
- [x] Rebuild de `core` e `sidekiq` executado apos a correcao.
- [x] Containers `core` e `sidekiq` recriados com a nova imagem.

### Validacoes do hardening

- [x] Sintaxe Ruby dos specs novos validada localmente.
- [x] Imagem Docker confirmou a presenca de `Crm::ScheduleSuggestionService`, `Email::OneoffCampaignService` e `CampaignMailer`.
- [x] `rails routes` dentro do container confirmou `suggest_schedule` e `schedule_suggestion`.
- [x] Smoke HTTP em `http://localhost:3010/` retornou `200` apos rebuild/restart.
- [~] RSpec nao foi executado porque o bundle da imagem atual nao possui o executavel `rspec`; os specs ficam prontos para rodar quando o ambiente de teste estiver com dependencias de desenvolvimento instaladas.

### Proximo passo natural

- [ ] Check-up visual humano no navegador usando dados reais.
- [ ] Teste operacional real de sugestao de horario com Google Calendar/Meet conectado.
- [ ] Teste operacional real de campanha Email usando MailHog ou inbox Email configurada.

## 13. Proximo passo executado - Smoke operacional Rails - 2026-05-06

Como a etapa seguinte era validar os fluxos novos em ambiente real, foi executado um smoke operacional dentro do container `core`, usando `rails runner` e transacao com rollback para evitar sujeira permanente na base.

### Fluxos validados

- [x] `Crm::ScheduleSuggestionService` gerou 5 sugestoes de horario em janela comercial.
- [x] `Campaigns::AudienceResolver` resolveu audiencia por label com 1 contato elegivel e email presente.
- [x] `Email::OneoffCampaignService` renderizou 1 email usando `ActionMailer::Base.delivery_method = :test`.
- [x] Campanha de email chegou ao status `completed` durante o smoke.
- [x] Smoke HTTP em `http://localhost:3010/` retornou `200` apos o teste.
- [x] Containers `core` e `sidekiq` permaneceram `healthy`.

Resultado do smoke:

```json
{
  "schedule_suggestions": 5,
  "audience_total": 1,
  "rendered_emails": 1,
  "campaign_status": "completed"
}
```

### Observacao de log

- [~] O smoke criou contatos dentro de transacao rollback. O callback automatico de avatar enfileirou jobs para esses contatos e, apos o rollback, o Sidekiq descartou os jobs com `ActiveJob::DeserializationError`. Isso nao afeta produto nem deixou container unhealthy, mas deve ser evitado nos proximos smokes usando contatos persistentes de teste ou desabilitando callbacks de avatar no script.
- [x] Checagem posterior de logs recentes nao mostrou novos erros.

## 14. Proximo passo executado - Task de smoke reutilizavel - 2026-05-06

Para evitar repeticao manual e eliminar o problema de jobs descartados por rollback, foi criada uma task oficial de smoke operacional.

### Entrega

- [x] Criada task `crm:operational_smoke`.
- [x] A task valida agendamento inteligente, resolucao de audiencia e campanha Email em um fluxo unico.
- [x] A task usa `ActiveJob::Base.queue_adapter = :test` durante a execucao para nao enviar jobs temporarios ao Sidekiq.
- [x] A task usa `ActionMailer::Base.delivery_method = :test` para renderizar email sem disparo externo.
- [x] A task limpa dados temporarios ao final: campanha, inbox, canal, contato, label e horarios de trabalho do inbox.
- [x] `core/Dockerfile` passou a copiar `lib/tasks/crm_smoke.rake` para dentro da imagem.

Arquivos:

- `core/lib/tasks/crm_smoke.rake`
- `core/Dockerfile`

### Validacoes

- [x] Sintaxe Ruby validada em `lib/tasks/crm_smoke.rake`.
- [x] Rebuild de `core` e `sidekiq` executado.
- [x] Containers `core` e `sidekiq` recriados e ficaram `healthy`.
- [x] `docker compose exec -T core bundle exec rails crm:operational_smoke` retornou `status: ok`.
- [x] Smoke retornou 5 sugestoes de agenda, 1 contato elegivel, 1 email renderizado e campanha `completed`.
- [x] Checagem posterior confirmou zero sobras `smoke-*` em labels, contatos, inboxes e campanhas.
- [x] Logs recentes do Sidekiq nao mostraram erros apos a task.
- [x] Smoke HTTP em `http://localhost:3010/` retornou `200`.

Comando de check-up operacional:

```bash
docker compose exec -T core bundle exec rails crm:operational_smoke
```

## 15. Proximo passo executado - Reformulacao da tela de login - 2026-05-06

A tela de login foi refeita do zero para remover o visual pesado, o hero gigante, a rolagem desnecessaria e os problemas de hierarquia/espacamento apontados no check-up visual.

### Entrega

- [x] Reescrita completa de `core/app/javascript/v3/views/login/Index.vue`.
- [x] Novo layout compacto em duas areas: acesso da equipe e painel operacional do produto.
- [x] Hero reduzido e enquadrado, sem texto exagerado ocupando a tela inteira.
- [x] Formulario redesenhado com campos proprios, icones, foco visivel, validacao inline, estado de erro e botao de mostrar/ocultar senha.
- [x] Fluxos preservados: login por email/senha, Google OAuth, SSO/SAML, MFA, signup, reset de senha e login por token SSO.
- [x] `data-testid` de email, senha e submit preservados para compatibilidade com testes.
- [x] Responsividade ajustada para desktop e mobile, ocultando o painel lateral em telas menores.
- [x] Paleta e componentes locais ajustados para evitar o visual quebrado do tema escuro antigo.

Arquivo principal:

- `core/app/javascript/v3/views/login/Index.vue`

### Validacoes

- [x] `pnpm exec prettier --write app/javascript/v3/views/login/Index.vue`
- [x] `pnpm exec eslint app/javascript/v3/views/login/Index.vue`
- [x] `pnpm exec vite build`
- [x] `docker compose build core sidekiq`
- [x] `docker compose up -d core sidekiq`
- [x] Smoke HTTP em `http://localhost:3010/app/login` retornou `200`.
- [~] Validacao visual final no navegador fica para o check-up humano, porque a automacao disponivel nesta sessao nao expos ferramenta de screenshot/browser local.

## 16. Proximo passo executado - Login simples e sem rolagem - 2026-05-06

Apos o check-up visual, a tela de login foi simplificada novamente para remover o painel operacional falso, as metricas sem contexto e a rolagem lateral que aparecia no navegador.

### Entrega

- [x] Login convertido para uma tela unica, centralizada e mais simples.
- [x] Removidos painel lateral, fila comercial, cards de metricas e textos decorativos sem utilidade.
- [x] CSS revisado com `position: fixed`, `height: 100dvh`, `overflow: hidden`, card compacto e regras responsivas por largura e altura.
- [x] Campos de e-mail e senha redesenhados com fundo unico, icones sem bloco visual separado e foco mais claro.
- [x] Preload trocado por estado compacto com spinner circular e copy objetiva.
- [x] Paleta trocada para base clara com faixa azul escura, acento coral e links em verde.
- [x] Copy principal reescrita em `pt_BR` e `en` para ser direta e menos promocional.
- [x] Chaves de traducao de metricas/fila removidas dos idiomas principais porque nao sao mais usadas.

Arquivos principais:

- `core/app/javascript/v3/views/login/Index.vue`
- `core/app/javascript/dashboard/i18n/locale/pt_BR/login.json`
- `core/app/javascript/dashboard/i18n/locale/en/login.json`

### Validacoes

- [x] `pnpm exec prettier --write app/javascript/v3/views/login/Index.vue app/javascript/dashboard/i18n/locale/pt_BR/login.json app/javascript/dashboard/i18n/locale/en/login.json`
- [x] `pnpm exec eslint app/javascript/v3/views/login/Index.vue`
- [x] `pnpm exec vite build`
- [x] `docker compose build core sidekiq`
- [x] `docker compose up -d core sidekiq`
- [x] Containers `core` e `sidekiq` ficaram `healthy`.
- [x] Smoke HTTP em `http://localhost:3010/app/login` retornou `200`.
- [~] Checagem visual automatizada por viewport nao foi executada porque `playwright` nao esta instalado neste workspace.

## 17. Proximo passo executado - Login moderno em duas colunas - 2026-05-06

Apos novo check-up visual, a tela de login foi reformulada novamente para ficar mais moderna, mais equilibrada e alinhada ao pedido de manter o formulario do lado esquerdo e as informacoes do sistema do lado direito.

### Entrega

- [x] Login reorganizado em duas colunas no desktop: acesso da conta a esquerda e contexto do sistema a direita.
- [x] Painel direito refeito com copy objetiva sobre atendimento, CRM, funil juridico, historico e controle de acesso.
- [x] Design system local atualizado com superficies claras, painel lateral escuro, acentos azul/verde/coral, borda de 8px, foco visivel e hierarquia de texto mais limpa.
- [x] Inputs de e-mail e senha normalizados para evitar o fundo escuro herdado do browser/tema.
- [x] Placeholder, texto digitado, autofill e caret padronizados com `color-scheme: light`, `background: transparent !important` e cores consistentes.
- [x] Preload mantido compacto, com spinner circular e texto de validacao de acesso.
- [x] Responsividade revisada com empilhamento em telas menores e reducao de detalhes em alturas baixas, mantendo a pagina sem rolagem.
- [x] Fluxos preservados: e-mail/senha, Google OAuth, SSO, MFA, reset de senha e signup quando habilitado.

Arquivos principais:

- `core/app/javascript/v3/views/login/Index.vue`
- `core/app/javascript/dashboard/i18n/locale/pt_BR/login.json`
- `core/app/javascript/dashboard/i18n/locale/en/login.json`

### Validacoes

- [x] `pnpm exec eslint app/javascript/v3/views/login/Index.vue`
- [x] `pnpm exec vite build`
- [x] Smoke HTTP em `http://localhost:3010/app/login` retornou `200`.
- [~] Restart via `docker compose up -d rails sidekiq vite` nao foi executado porque `core/.env` nao existe neste checkout; o servidor local em `3010` esta ativo e respondeu normalmente.
- [~] Validacao visual automatizada por screenshot nao foi executada porque a ferramenta de browser/Playwright nao esta disponivel neste workspace.

## 18. Proximo passo executado - Login refeito com isolamento de inputs - 2026-05-06

A tela de login foi refeita novamente apos o check-up visual apontar que o placeholder/input ainda herdava fundo escuro e que o painel de informacoes ficava quebrado pelo titulo grande.

### Entrega

- [x] `Index.vue` recriado do zero para remover sobras do layout anterior.
- [x] Layout mantido em duas colunas: login a esquerda e informacoes do sistema a direita.
- [x] Painel direito trocado por uma composicao mais compacta, com titulo menor, card de workspace, fluxo em 3 etapas e status operacional.
- [x] Campo de e-mail e senha refeito com classe propria `login-control__input`.
- [x] Inputs ganharam `reset-base`, `no-margin`, `all: unset !important` e seletores de alta especificidade para vencer o CSS global de `input[type]`.
- [x] Placeholder, autofill, caret, foco e fundo do input agora usam cores explicitas e consistentes.
- [x] Copy de PT-BR e EN atualizada para reduzir quebras e remover frases longas no painel direito.
- [x] Responsividade preservada sem rolagem: no mobile o painel informativo e ocultado e o login ocupa a tela.

Arquivos principais:

- `core/app/javascript/v3/views/login/Index.vue`
- `core/app/javascript/dashboard/i18n/locale/pt_BR/login.json`
- `core/app/javascript/dashboard/i18n/locale/en/login.json`

### Validacoes

- [x] `pnpm exec prettier --write app/javascript/v3/views/login/Index.vue app/javascript/dashboard/i18n/locale/pt_BR/login.json app/javascript/dashboard/i18n/locale/en/login.json`
- [x] `pnpm exec eslint app/javascript/v3/views/login/Index.vue`
- [x] `pnpm exec vite build`
- [x] Smoke HTTP em `http://localhost:3010/app/login` retornou `200`.
- [~] Validacao visual automatizada por screenshot segue indisponivel porque nao ha Playwright/browser tool neste workspace.

## 19. Proximo passo executado - Persistencia Lead/Cliente em contatos - 2026-05-06

Foi corrigido o problema em que alterar um contato de Lead para Cliente parecia funcionar na UI, mas a mudanca voltava depois de salvar/recarregar.

### Entrega

- [x] `contact_update_params` agora converte parametros permitidos para hash mutavel antes da normalizacao CRM.
- [x] A normalizacao grava `contact_type` junto com `relationship_status`, impedindo que o callback `Contacts::SyncAttributes` reverta Cliente para Lead durante o `before_save`.
- [x] `lifecycle_stage` agora e alinhado automaticamente quando a troca vem apenas por status ou quando vem com etapa incompativel.
- [x] Adicionados specs cobrindo Lead -> Cliente e Cliente -> Lead no endpoint de update de contatos.

Arquivos principais:

- `core/app/controllers/api/v1/accounts/contacts_controller.rb`
- `core/spec/controllers/api/v1/accounts/contacts_controller_spec.rb`

### Validacoes

- [x] `ruby -c app/controllers/api/v1/accounts/contacts_controller.rb`
- [x] `ruby -c spec/controllers/api/v1/accounts/contacts_controller_spec.rb`
- [~] `bundle exec rspec spec/controllers/api/v1/accounts/contacts_controller_spec.rb:710` nao executou porque o Ruby local nao tem `stackprof-0.2.25` e `io-console-0.6.0` instalaveis nesta maquina.
- [~] Tentativa de instalar as gems falhou na compilacao nativa do Windows/Ruby 3.4.

## 20. Proximo passo executado - Cliente visivel nas listas de contatos - 2026-05-06

Foi corrigido o efeito colateral em que um contato convertido para Cliente sumia da listagem geral e tambem nao aparecia no filtro Cliente.

### Entrega

- [x] `Contact.resolved_contacts(use_crm_v2: true)` agora retorna contatos CRM do tipo Lead e Cliente, em vez de apenas Lead.
- [x] O filtro rapido Cliente/Lead na tela de contatos agora filtra somente por relacionamento, sem aplicar uma etapa de ciclo de vida junto.
- [x] Adicionado teste de request garantindo que Cliente aparece na listagem geral CRM v2 e no filtro `relationship_status=customer`.
- [x] Atualizados specs do modelo para cobrir Lead e Cliente no escopo `resolved_contacts`.

Arquivos principais:

- `core/app/models/contact.rb`
- `core/app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue`
- `core/spec/models/contact_spec.rb`
- `core/spec/controllers/api/v1/accounts/contacts_controller_spec.rb`

### Validacoes

- [x] `ruby -c app/models/contact.rb`
- [x] `ruby -c spec/models/contact_spec.rb`
- [x] `ruby -c spec/controllers/api/v1/accounts/contacts_controller_spec.rb`
- [x] `pnpm exec eslint app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue`
- [x] `pnpm exec vite build`
- [~] Specs Rails seguem bloqueados pelo ambiente local por falha de compilacao das gems nativas `stackprof` e `io-console`.

## 21. Proximo passo executado - Deploy local da correcao de Clientes - 2026-05-06

Foi confirmado que os contatos convertidos para Cliente nao foram perdidos. O banco `chusterm_core` continha 11 contatos, sendo 8 Clientes e 3 Leads. O problema era o container `chusterm-core-1` ainda rodando uma imagem antiga, com `resolved_contacts` filtrando apenas Leads.

### Entrega

- [x] Verificado no banco que os contatos Clientes continuam salvos.
- [x] Rebuild executado para `core` e `sidekiq`.
- [x] Containers `core` e `sidekiq` recriados e saudaveis.
- [x] Confirmado dentro do container novo que `Contact.resolved_contacts(use_crm_v2: true)` usa `contact_type: %i[lead customer]`.
- [x] Confirmado via Rails runner que a conta 1 retorna os 8 Clientes no escopo resolvido e no filtro Cliente.

### Validacoes

- [x] `docker compose build core sidekiq`
- [x] `docker compose up -d core sidekiq`
- [x] `GET http://localhost:3010/health` retornou `200`.
- [x] Rails runner confirmou `crm_v2: true`, 11 contatos resolvidos e 8 clientes visiveis.

## 22. Proximo passo executado - Documento de melhorias da pagina de contatos - 2026-05-06

Foi criado um documento especifico para a reformulacao profissional da pagina de contatos, com foco em categorias multiplas, importacao de listas, segmentacao e campanhas.

### Entrega

- [x] Criado `docs/melhorias-pagina-contatos-categorias-campanhas.md`.
- [x] Definido conceito de categoria multi-lista para contatos.
- [x] Descrito fluxo de criacao de categorias na hora da importacao.
- [x] Descrito uso de categorias como audiencia de campanhas.
- [x] Incluidos 20 contatos demo com multiplas categorias.
- [x] Incluidas pelo menos 5 categorias principais, com exemplos de localidade, area juridica, campanha, status comercial e restricao.

### Proximo bloco sugerido

Implementar o caminho rapido usando `Label` como categoria de contato, com barra de categorias na pagina de contatos, chips nos cards e importacao por coluna `categorias`.

## 23. Proximo passo executado - Categorias de contatos e base demo - 2026-05-06

Foi iniciado o bloco de implementacao da nova pagina de contatos a partir do documento `docs/melhorias-pagina-contatos-categorias-campanhas.md`, usando o caminho rapido com `Label` como categoria de contato.

### Entrega

- [x] `Label` passou a aceitar categorias CRM adicionais: localidade, campanha, livre e restricao.
- [x] Importacao de contatos passou a aceitar a coluna `categorias`, alem da compatibilidade com etiquetas antigas.
- [x] Modal de importacao agora mostra copy voltada a categorias e sugere `DF`, `Previdenciario` e `Re-marketing`.
- [x] Pagina de contatos ganhou barra/painel de categorias com contagem, filtro rapido, criacao de nova categoria e atalho para campanha com a audiencia filtrada.
- [x] Cards de contato agora exibem categorias em chips com nome amigavel, removendo prefixos tecnicos como `area_` e `status_`.
- [x] CSV exemplo em `public/downloads/import-contacts-sample.csv` foi ajustado para usar `categorias`.
- [x] Criada task idempotente `crm:seed_contact_categories_demo` para gerar 10 categorias e 20 contatos demo.
- [x] Task executada no container local para a conta 1, populando as categorias e contatos de demonstracao.

Arquivos principais:

- `core/app/models/label.rb`
- `core/app/services/data_import/contact_manager.rb`
- `core/app/controllers/api/v1/accounts/contacts_controller.rb`
- `core/app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue`
- `core/app/javascript/dashboard/components-next/Contacts/ContactsCard/ContactsCard.vue`
- `core/app/javascript/dashboard/components-next/Contacts/ContactsForm/ContactImportDialog.vue`
- `core/lib/tasks/crm_contacts.rake`
- `core/public/downloads/import-contacts-sample.csv`

### Validacoes

- [x] `ruby -c app/models/label.rb`
- [x] `ruby -c app/services/data_import/contact_manager.rb`
- [x] `ruby -c app/controllers/api/v1/accounts/contacts_controller.rb`
- [x] `ruby -c lib/tasks/crm_contacts.rake`
- [x] `pnpm exec prettier --write` nos componentes alterados.
- [x] `pnpm exec eslint` nos componentes alterados.
- [x] `pnpm exec vite build`
- [x] `docker compose build core sidekiq`
- [x] `docker compose up -d core sidekiq`
- [x] `GET http://localhost:3010/health` retornou `200`.
- [x] `docker exec chusterm-core-1 bundle exec rails crm:seed_contact_categories_demo ACCOUNT_ID=1` retornou `{"account_id":1,"categories":10,"contacts":20}`.
- [x] Rails runner confirmou 30 contatos totais na conta 1, 19 contatos demo com email `@demo.local` e Douglas Chuster demo vinculado as categorias `df`, `area_previdenciario`, `re-marketing` e `cliente_base`.

### Proximo bloco sugerido

Implementar uma API dedicada de categorias de contato (`contact_categories`) sobre `Label`, com endpoints de listagem/criacao/edicao e acoes em massa para adicionar ou remover categorias de varios contatos.

## 24. Proximo passo executado - API dedicada de categorias de contato - 2026-05-06

Foi implementada uma camada REST dedicada para categorias de contato usando `Label` como armazenamento inicial, preparando a pagina de contatos para acoes em massa e para uma futura UI de gerenciamento de categorias.

### Entrega

- [x] Criado controller `Api::V1::Accounts::ContactCategoriesController`.
- [x] Criadas rotas REST para listar, exibir, criar, atualizar e remover categorias.
- [x] Criadas rotas de massa `bulk_assign` e `bulk_remove`.
- [x] `Label` ganhou escopo `contact_categories` e lista `CONTACT_CATEGORY_TYPES`.
- [x] `LabelPolicy` passou a autorizar `bulk_assign` e `bulk_remove` com a mesma regra de update.
- [x] Dockerfile atualizado para copiar o controller novo e a policy modificada para a imagem local.
- [x] Adicionado spec request para index, create, bulk assign e bulk remove.
- [x] Smoke autenticado confirmou `GET`, `POST` e `bulk_assign` em `localhost:3010`.
- [x] Dados criados pelo smoke foram removidos apos a validacao.

Arquivos principais:

- `core/app/controllers/api/v1/accounts/contact_categories_controller.rb`
- `core/app/models/label.rb`
- `core/app/policies/label_policy.rb`
- `core/config/routes.rb`
- `core/Dockerfile`
- `core/spec/controllers/api/v1/accounts/contact_categories_controller_spec.rb`

### Validacoes

- [x] `ruby -c app/controllers/api/v1/accounts/contact_categories_controller.rb`
- [x] `ruby -c app/models/label.rb`
- [x] `ruby -c app/policies/label_policy.rb`
- [x] `ruby -c config/routes.rb`
- [x] `ruby -c spec/controllers/api/v1/accounts/contact_categories_controller_spec.rb`
- [x] `docker compose build core sidekiq`
- [x] `docker compose up -d core sidekiq`
- [x] `GET http://localhost:3010/health` retornou `200`.
- [x] Rails reconheceu `/api/v1/accounts/1/contact_categories` apontando para `api/v1/accounts/contact_categories#index`.
- [x] Smoke autenticado retornou 27 categorias no index, criou `api_smoke` e aplicou a categoria a 1 contato via bulk assign.
- [x] Cleanup removeu `api_smoke` e retirou a categoria do contato usado no smoke.
- [~] `bundle exec rspec spec/controllers/api/v1/accounts/contact_categories_controller_spec.rb` segue bloqueado no Ruby local por falta das gems nativas `stackprof-0.2.25` e `io-console-0.6.0`.

### Proximo bloco sugerido

Conectar a UI da pagina de contatos a API `contact_categories`, substituindo chamadas diretas de labels onde fizer sentido e adicionando acoes em massa para adicionar/remover categorias.

## 25. Proximo passo executado - UI conectada a API de categorias - 2026-05-06

A pagina de contatos foi conectada ao endpoint dedicado `contact_categories`, reduzindo o acoplamento com o endpoint generico de etiquetas e liberando acoes de categoria em massa.

### Entrega

- [x] Criado cliente JS `ContactCategoriesAPI`.
- [x] A pagina de contatos agora busca categorias em `/contact_categories`.
- [x] A criacao manual de categoria na pagina agora usa `ContactCategoriesAPI.create`.
- [x] O painel de categorias usa nomes amigaveis sem prefixos tecnicos e aproveita `contacts_count` retornado pela API.
- [x] A importacao atualiza tambem a lista de categorias ao concluir.
- [x] A acao em massa de adicionar etiquetas/categorias agora usa `bulk_assign` da API de categorias.
- [x] A barra de selecao em massa ganhou acao para remover os contatos selecionados da categoria ativa.

Arquivos principais:

- `core/app/javascript/dashboard/api/contactCategories.js`
- `core/app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue`
- `core/app/javascript/dashboard/routes/dashboard/contacts/components/ContactsBulkActionBar.vue`

### Validacoes

- [x] `pnpm exec prettier --write app/javascript/dashboard/api/contactCategories.js app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue app/javascript/dashboard/routes/dashboard/contacts/components/ContactsBulkActionBar.vue`
- [x] `pnpm exec eslint app/javascript/dashboard/api/contactCategories.js app/javascript/dashboard/routes/dashboard/contacts/pages/ContactsIndex.vue app/javascript/dashboard/routes/dashboard/contacts/components/ContactsBulkActionBar.vue`
- [x] `pnpm exec vite build`
- [x] `docker compose build core sidekiq`
- [x] `docker compose up -d core sidekiq`
- [x] `GET http://localhost:3010/health` retornou `200`.
- [x] `GET http://localhost:3010/app/accounts/1/contacts?page=1` retornou `200`.
- [x] Smoke autenticado em `/api/v1/accounts/1/contact_categories` retornou 27 categorias.

### Proximo bloco sugerido

Criar preview de importacao de contatos com categorias novas/existentes, duplicados e telefones invalidos antes da confirmacao do upload.
