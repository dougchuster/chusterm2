# Plano Mestre de Reformulação do ChusteRM

**Versão:** 1.0

**Data-base:** 2026-07-09

**Status:** plano mestre completo; execução deve iniciar pela Fase 0, ainda aberta

**Execução UI/UX:** piloto controlado da F3D iniciado em 2026-07-14 por
priorização explícita do produto; a validação da primeira fatia está registrada
em `docs/execution/F3D-CRM-REDESIGN-PILOT.md`, sem encerrar os gates pendentes da
F0 nem o gate completo da F3D.

**Documento orientador:** `prompt-reformulacao-crm.md`

**Regra de ouro:** nenhuma fase avança sem evidência de que a fase anterior preservou os fluxos existentes.

---

## 1. Finalidade deste documento

Este é o plano executável para transformar o ChusteRM em um centro operacional moderno que una:

- atendimento omnichannel;
- relacionamento com contatos e clientes;
- CRM comercial, pipeline, atividades e previsibilidade;
- automações rastreáveis;
- CAPITÃO como agente de atendimento e qualificação assistida;
- controle humano, segurança, métricas e melhoria contínua.

O plano não é uma lista de ideias. Cada fase contém objetivo, escopo, dependências, entregáveis, testes, evidências e gate de saída. A execução deve permanecer incremental, reversível e compatível com o fork do Chatwoot.

### 1.1 Resultado esperado

Ao final, um operador deve conseguir:

1. receber uma conversa de qualquer canal;
2. entender imediatamente quem é a pessoa e seu histórico;
3. saber se o CAPITÃO está atendendo, por que tomou cada decisão e quando precisa de ajuda;
4. assumir ou devolver o atendimento com um clique;
5. criar ou reutilizar uma oportunidade sem sair da conversa;
6. acompanhar próxima ação, score, risco e valor;
7. mover o negócio até ganho ou perda com dados completos;
8. consultar uma timeline única de mensagens, notas, atividades, mudanças, IA e resultados;
9. medir atendimento, vendas e IA com definições confiáveis.

### 1.2 Contrato de execução

- Respeitar a ordem dos gates e o grafo de dependências. Pesquisa, inventário, protótipo não mutável e scaffolding de testes podem antecipar trabalho; código/migration de uma fase posterior não é promovido antes de seus pré-requisitos explícitos.
- Não misturar redesign amplo com correções críticas de segurança no mesmo lote.
- Não substituir componentes centrais do Chatwoot quando houver extensão compatível.
- Verificar o overlay `core/enterprise/` antes de mudar comportamento em `core/app/`.
- Usar feature flags, migrations aditivas, shadow mode e rollback explícito.
- Não realizar migrations destrutivas no mesmo deploy em que um contrato novo é ativado.
- Não declarar uma tela, fluxo, score ou integração como aprovado apenas porque o código existe.
- Registrar decisões em `DECISOES.md` e evidências nos relatórios da fase.
- Commits e PRs devem ser pequenos, temáticos e testáveis.

---

## 2. Fontes lidas e autoridade das evidências

Todos os documentos abaixo foram relidos antes da criação deste plano.

| Fonte | Papel | Linhas | SHA-256 do recorte |
|---|---|---:|---|
| `prompt-reformulacao-crm.md` | requisitos e fases originais | 170 | `E43BE28B2D88C03DC6A5F16C0DC3FB627ED98EC9C18905070A3E752A3FF50533` |
| `AUDITORIA.md` | baseline consolidado da Fase 0 | 262 | `85F78FDB024C9E9D9089DD469531CF34327F7A3FF3D7CFB7715992295EF641A5` |
| `AUDITORIA-CSS.md` | cascata, tokens, responsividade e dívida visual | 402 | `88B7749AB9DA2BB8F5122BB199BFB2F3DEE56CB8C1349676809B3769BD4DB655` |
| `AUDITORIA-FUNCIONAL.md` | fluxos, cobertura e matriz E2E | 350 | `E3E88F00CD880D117A00A098EED024A291ABBC945E8283094C1AD2D6E96119FB` |
| `DECISOES.md` | ADRs vigentes | 67 | `A9982251989E8AD5D61B831E688AB7416B6634B3589BFAA14D134B9FB0340A17` |
| `SETUP.md` | operação, build, backup e runtime | 108 | `30723CC3FF80A91D35568C1B50724402667C16F315B51ECF1BA2FA7C5B8863EA` |
| `docs/audit/INVENTARIO-ROTAS.md` | 877 rotas Rails e 161 rotas Vue | 437 | `4852241C23E289E4ED5EF08F82837BE107B835814A0FCEA172FB9B86FD01B6C5` |

Também foram inspecionados:

- `core/AGENTS.md` e a skill local `chusterm-ui-redesign`;
- o design brief Midnight Indigo / Nocturnal Architect em `.github/skills/chusterm-ui-redesign/references/design-brief.md`;
- controllers, models, services, jobs, rotas e componentes do CRM e CAPITÃO;
- configuração Docker e health checks;
- dados agregados do banco local, sem leitura ou exposição de segredos;
- documentação oficial de concorrentes e do Chatwoot.

### 2.1 Hierarquia das fontes de verdade

Quando duas fontes divergirem, a execução deve usar esta precedência:

1. o escopo e as restrições de `prompt-reformulacao-crm.md`, incluindo somente adendos aprovados explicitamente pelo Product Owner/usuário;
2. ADRs aceitos em `DECISOES.md`;
3. código, schema, migrations aplicadas e runtime realmente ativos;
4. auditorias e inventário como evidência do recorte em que foram produzidos;
5. README, planos anteriores e documentos históricos apenas como contexto.

Uma divergência relevante não deve ser resolvida silenciosamente. Ela precisa gerar atualização documental ou ADR, responsável e evidência. Isso é especialmente importante porque documentos antigos ainda podem descrever a Fase 0 como concluída, o design anterior ou serviços já aposentados.

### 2.2 Limitações das fontes atuais

- As auditorias documentais foram produzidas durante um worktree em evolução e já contêm itens desatualizados.
- Paginação acima de 200, valores no Kanban, ganho/perda, testes do Orchestrator e alguns testes CRM já avançaram após o primeiro recorte.
- Não existe baseline visual autenticado completo.
- Não existe suíte E2E de produto executando toda a jornada crítica.
- Os documentos `docs/chusterm_design_system.md` e `docs/DESIGN.md`, citados no guia interno, não existem no worktree; `.github/skills/chusterm-ui-redesign/references/design-brief.md` é a referência provisória.
- Integrações externas ainda não foram comprovadas em sandboxes controlados.

Por isso, a primeira entrega da Fase 0 é reconciliar documentação, código e runtime antes de iniciar qualquer redesign.

### 2.3 Protocolo de leitura durante a execução

Este arquivo é o ponto de entrada. No início da execução:

1. reler integralmente este plano e `prompt-reformulacao-crm.md`;
2. conferir hashes/data dos sete documentos-fonte da tabela;
3. reler `DECISOES.md`, `SETUP.md` e os documentos da fase ativa;
4. comparar com código, schema, migrations, runtime e worktree;
5. registrar qualquer divergência antes de implementar;
6. incorporar ao índice novos entregáveis aprovados.

Uma mudança de hash não significa erro; significa que a fonte evoluiu e precisa ser reconciliada. O executor não deve seguir cegamente um número histórico deste plano quando o runtime atual demonstrar outra realidade.

---

## 3. Snapshot real do ambiente em 2026-07-09

### 3.1 Runtime

| Serviço | Estado observado | Função |
|---|---|---|
| Core Rails/Vue | saudável | atendimento, CRM, contatos, CAPITÃO e administração |
| Sidekiq | saudável | jobs assíncronos |
| PostgreSQL | saudável | persistência principal |
| Redis | saudável | filas, cache e realtime |
| Evolution API | saudável | canal WhatsApp |
| Orchestrator | saudável, mas não é o runtime ativo do CAPITÃO | skills e agente externo |
| Mailhog | ativo | captura de e-mail local |
| `core-vite` | opt-in | build frontend; não deve rodar continuamente por padrão |

### 3.2 Dados agregados atuais

| Entidade | Quantidade/estado |
|---|---|
| Contas | 1 |
| Usuários | 2 |
| Inboxes | 4, todas `Channel::Api` |
| Contatos | 37: 25 leads e 12 clientes |
| Lifecycle | 15 lead, 10 triage, 12 customer |
| Conversas | 4, todas pending |
| Mensagens | 36 |
| Negócios | 6, todos open/active |
| Pipelines / etapas | 4 / 35 |
| Atividades CRM | 29 |
| Média de score dos negócios | 61,83 |
| Registros históricos de score | 11: 6 baixo potencial, 5 qualificados |
| Assistentes CAPITÃO | 3 |
| Inboxes vinculadas ao CAPITÃO | 1 |
| Estados CAPITÃO | 4, todos auto |
| Handoffs com código estruturado | 0 |

### 3.3 Interpretação correta do snapshot

O ambiente atual é suficiente para smoke tests, mas insuficiente para validar escala, previsão ou calibração estatística:

- não há negócios ganhos ou perdidos para medir precisão do score;
- não há handoffs estruturados para medir causas e qualidade;
- não há volume suficiente para inferir performance do Kanban;
- todas as inboxes locais são API, portanto a matriz omnichannel não está representada.

O plano precisa criar fixtures e datasets controlados antes de usar números do ambiente como evidência de qualidade.

### 3.4 Evidências técnicas recentes, ainda parciais

| Verificação | Resultado observado | Interpretação |
|---|---:|---|
| RSpec focado | 27 exemplos aprovados | cobre recortes CRM/CAPITÃO, não regressão Rails |
| Vitest focado | 25 testes aprovados | cobre componentes/contratos tocados, não todas as rotas |
| Orchestrator | 9 testes aprovados | corrige o diagnóstico histórico de “zero”, sem provar integração real |
| Lint frontend incremental | 35 arquivos aprovados | não equivale a limpar todo o legado |
| Rails Zeitwerk | aprovado | autoload consistente no recorte atual |
| Build frontend | aprovado, 4.655 módulos processados | prova compilação, não UX/E2E |

Esses resultados devem ser preservados como baseline focada. A execução precisa registrar comando, commit, ambiente e saída completa antes de promovê-los a gate.

### 3.5 Estado correto das melhorias presentes no worktree

| Área | Estado |
|---|---|
| contrato `database_id/display_id` | implementado e testado de forma focada; E2E pendente |
| reforços de tenancy | parcialmente implementados; matriz multiaccount pendente |
| Kanban acima de 200 | paginação implementada; volume/runtime pendentes |
| valor, somas e won/lost | implementados no worktree; reconciliação E2E pendente |
| exportação assíncrona | implementada; autorização, volume e download pendentes |
| AI Center | implementação existente; denominadores/atribuição precisam ser revistos |
| CAPITÃO | núcleo e testes internos existentes; score, identidade, handoff e provedor real pendentes |
| runtime local | smoke saudável; não prova as jornadas |
| CI | ainda divergente da arquitetura e versões ativas |

Até os respectivos gates, o status desses itens é **implementado, não validado**.

---

## 4. Visão de produto e posicionamento recomendado

### 4.1 Visão

> O ChusteRM será um sistema operacional de relacionamento conversacional: cada conversa, contato, oportunidade, tarefa e decisão da IA compartilhará contexto, histórico e responsabilidade, sem exigir que o usuário navegue entre produtos desconectados.

### 4.2 Posicionamento recomendado

- Núcleo horizontal e configurável para operações de atendimento e vendas.
- WhatsApp-first para o mercado brasileiro, sem perder omnicanalidade.
- Domínio jurídico preservado como primeiro pacote vertical, não como hardcode global.
- Uma única aplicação para atendimento, CRM e IA.
- CAPITÃO como agente auditável e controlável, não como caixa-preta.

### 4.3 Diferencial competitivo

| Mercado | Força observada | Oportunidade do ChusteRM |
|---|---|---|
| Attio | registro flexível, timeline, velocidade e ações contextuais | aplicar flexibilidade sem perder o fluxo operacional do atendimento |
| HubSpot | lifecycle, associações, score e automações | separar identidade, relacionamento, oportunidade e score |
| Pipedrive | pipeline orientado à próxima ação e rotting | transformar o Kanban em instrumento de execução, não apenas visualização |
| Intercom/Crisp | inbox de IA, handoff, sandbox e operação humana | integrar esses padrões ao CRM comercial profundo |
| Salesforce/Zendesk | governança, explicabilidade, triagem e roteamento | oferecer controle forte com UX mais simples |
| RD Station/Kommo/Zenvia | WhatsApp, CRM conversacional e mercado brasileiro | operar CRM diretamente dentro da conversa, inclusive a partir de áudio |

### 4.4 Princípios de experiência

1. **Contexto antes de navegação:** o usuário deve resolver a tarefa onde já está.
2. **Próxima ação visível:** cada conversa e negócio deve mostrar o que fazer agora.
3. **Complexidade progressiva:** configuração básica primeiro; opções avançadas sob demanda.
4. **Uma fonte de verdade:** estados equivalentes não podem divergir entre módulos.
5. **IA transparente:** decisão, confiança, evidência, versão e override precisam ser visíveis.
6. **Humano no controle:** takeover imediato e IA silenciosa durante controle humano.
7. **Velocidade percebida:** feedback instantâneo, otimista quando seguro e reversível.
8. **Acessibilidade por padrão:** teclado, foco, contraste e toque não são acabamento posterior.
9. **Design coerente:** uma linguagem visual nos fluxos de login, dashboard, CRM, CAPITÃO e administração.

### 4.5 Personas e trabalhos principais

| Persona | Trabalho principal | Indicador de sucesso |
|---|---|---|
| Operador de atendimento | responder e resolver com contexto | menor tempo de resposta e retrabalho |
| Vendedor/consultor | qualificar, priorizar e avançar oportunidades | conversão, próxima ação e ciclo menor |
| Gestor | distribuir carga, remover bloqueios e prever resultados | SLA, cobertura, forecast e qualidade |
| Administrador | conectar canais e configurar processos/IA com segurança | tempo até primeiro valor e baixa taxa de erro |
| Auditor/gestor de IA | explicar, testar e melhorar o CAPITÃO | qualidade, segurança e redução de handoff desnecessário |
| Cliente final | receber resposta humana, clara e contínua | resolução, confiança e satisfação |

### 4.6 Síntese preliminar do estudo de mercado

Esta síntese orienta o plano; `BENCHMARK.md` deve validar profundidade, mudanças recentes e evidências com usuários.

| Produto | Padrão útil observado | Decisão preliminar para o ChusteRM | Cuidado |
|---|---|---|---|
| Attio | registros flexíveis, relações e ações contextuais | adaptar Cliente 360 e modelos configuráveis | flexibilidade sem governança vira schema caótico |
| HubSpot | lifecycle, associações, scoring e workflows | adaptar separação de relacionamento, deal e score | evitar configuração extensa antes do primeiro valor |
| Pipedrive | pipeline guiado por atividade e rotting | adotar próxima ação, tempo na etapa e inércia visível | Kanban não pode ser a única forma de operar dados |
| Intercom | Fin em workflows, supervisão e Bot Inbox | adaptar modos shadow/supervised/auto e handoff explícito | “contenção” opaca não prova resolução |
| Crisp | fila automatizada separada e operação simples | adaptar visão/filtro de conversas sob IA | não criar uma segunda Inbox desconectada |
| Salesforce | fatores de score, insights e governança | adaptar explicabilidade, versão e controle | não reproduzir complexidade administrativa |
| Zendesk | triagem por intenção, sentimento e linguagem | adaptar prioridade/roteamento operacional | não misturar sentimento/urgência com probabilidade comercial |
| RD Station CRM | WhatsApp dentro do fluxo comercial | adotar ação CRM no contexto da conversa | preservar consentimento, templates e limites do canal |
| Kommo | automações ligadas ao pipeline | adaptar builder após eventos/idempotência estáveis | automação visual sem auditoria amplia dano |
| Zenvia | operação brasileira multicanal e WhatsApp | adaptar onboarding de canal, templates e diagnóstico | abstração omnichannel não deve esconder falhas do provedor |
| Chatwoot | Inbox madura, command bar, permissões e realtime | estender a base existente | não duplicar command palette, composer ou contato |
| Linear/Notion | velocidade por teclado e complexidade progressiva | usar como referência de navegação/configuração | são referências adjacentes, não benchmark funcional de CRM |

Padrões a rejeitar:

- uma nota única decidindo identidade, urgência, conversão e handoff;
- IA sem identificação clara ou sem takeover imediato;
- automação que move/fecha/contata sem evento, preview ou rollback;
- registro duplicado de contato, conversa e oportunidade em módulos isolados;
- dashboard sem denominador ou drill-down;
- copiar a aparência de concorrentes sem provar melhora na tarefa.

---

## 5. Diagnóstico consolidado

### 5.1 Pontos fortes que devem ser preservados

- Base madura do Chatwoot para inbox, canais, contatos, relatórios, permissões e realtime.
- CRM integrado ao Rails e às tabelas `crm_*`.
- Pipeline, Kanban, atividades, agenda, automações, cadências e relatórios já existentes.
- CAPITÃO V2 nativo com resposta humanizada, ferramentas, playground e estados operacionais.
- Separação explícita entre `database_id` e `display_id` já iniciada.
- Melhorias recentes em paginação, valores, ganho/perda, realtime e testes focados.
- Docker reproduzível, backups documentados e watcher pesado isolado.

### 5.2 Problemas críticos antes do redesign

#### Segurança e tenancy

- Estados do CAPITÃO aceitam `crm_deal_id` sem resolver estritamente o deal pela conta.
- Deals ainda podem receber IDs de pipeline, etapa, contato, inbox e responsáveis de outra conta em caminhos de create/update.
- Validações atuais cobrem a conta da conversa, mas não todas as associações do negócio.
- Endpoints do Orchestrator para skills/conhecimento precisam de autenticação e autorização uniformes.

**Decisão de ordem:** nenhuma onda visual pode ser promovida enquanto os contratos cross-tenant P0 não estiverem cobertos e aprovados.

#### Modelo de pessoa, lead e cliente

- `contact_type`, `relationship_status`, `lifecycle_stage`, `operational_status` e status do deal se sobrepõem.
- Contato salvo na agenda do WhatsApp pode ser promovido a cliente sem contratação comprovada.
- Importações e sincronizações podem gerar combinações contraditórias.
- Cliente pode precisar de suporte, renovação ou uma nova oportunidade; desativar totalmente a IA não representa esse cenário.
- `ex_customer` e `qualified_lead` possuem caminhos praticamente inalcançáveis na lógica atual.

#### Score e qualificação

- Existem quatro algoritmos concorrentes: Rails jurídico, Orchestrator genérico, Orchestrator previdenciário e serviço CRM aposentado.
- A configuração exibida na UI não governa integralmente o calculador ativo.
- O score Rails possui estrutura explicável, mas sinais frágeis e nenhuma calibração contra desfechos reais.
- Urgência, prioridade operacional, intenção, fit e probabilidade de conversão são misturados.
- O handoff usa limite fixo diferente dos thresholds de qualificação.

#### CAPITÃO

- O runtime efetivo é Rails/V2; o Orchestrator não está conectado ao atendimento atual.
- Handoff, retomada e motivos estruturados não têm semântica uniforme.
- A base documental existente não garante RAG utilizável pela assistente ativa.
- Há instruções e pós-processamentos contraditórios.
- Configurações visíveis como estratégia de handoff, memória e score model podem não afetar o runtime.
- Mensagens e lista de conversas ainda não distinguem claramente IA de humano.
- Observabilidade mede execução, mas não precisão, correção humana ou qualidade da triagem.

### 5.3 Dívida de UI e CSS

- 20.661 linhas autorais de CSS/SCSS; 9.206 apenas no CRM.
- `chusterm-theme.css` possui 2.547 linhas e 338 `!important`.
- 146 custom properties são redefinidas; existem conflitos de paleta e dark mode.
- 20 breakpoints autorais competem com os breakpoints Tailwind.
- Agenda, Pipeline Settings e Atividades são componentes monolíticos.
- Há padrões duplicados de page shell, header, formulário, busca, drawer, modal e empty state.
- O guia exige Tailwind, mas o legado possui estilos locais e globais; a migração precisa ser gradual.

### 5.4 Lacunas de validação

- Nenhum Playwright/Cypress de produto.
- Nenhuma aprovação visual autenticada nas cinco larguras obrigatórias.
- WCAG AA, teclado, leitor de tela e contraste ainda não foram comprovados.
- Integrações Evolution, Google e LLM não têm evidência de sandbox completa.
- Cobertura frontend do CRM é pequena em relação às 14 rotas próprias.
- Testes do CAPITÃO não cobrem score, lead/cliente, configurações visíveis ou evals de qualidade.

---

## 6. Modelo conceitual alvo

O plano adota eixos independentes. Nenhum campo deve tentar responder simultaneamente “quem é”, “o que quer”, “quanto vale” e “quem deve atender”.

### 6.1 Identidade

Estado sugerido:

`unknown → provisional → verified → merged`

Evidências possíveis:

- telefone/e-mail verificado;
- identificador do canal;
- CPF/CNPJ ou ID externo protegido;
- vínculo confirmado em sistema autoritativo;
- merge manual ou determinístico auditado.

### 6.2 Relacionamento

Não usar uma única sequência para conceitos diferentes. Contrato recomendado:

| Eixo | Dono | Valores iniciais | Observação |
|---|---|---|---|
| `relationship_status` | contato | `unknown, prospect, customer, former_customer` | relação comercial comprovada |
| `service_status` | vínculo/serviço | `none, active, inactive` | não confundir serviço com identidade |
| `qualification_status` | deal/snapshot de score | `not_evaluated, unqualified, qualified` | nunca é atributo global do contato |
| recorrência | derivado por contato | contagem de contratações ganhas | não precisa de enum concorrente |

Um contato pode ter dois deals com qualificações diferentes. Rótulos de UX são projeções: “cliente ativo” = customer + active; “cliente recorrente” = customer com mais de uma contratação; “lead qualificado” = prospect + deal atual qualified.

Mapeamento obrigatório no dry-run:

| `lifecycle_stage` atual | Projeção-alvo exata |
|---|---|
| `visitor` | relationship unknown |
| `lead` | relationship prospect |
| `qualified_lead` | relationship prospect; qualification pertence ao deal que sustentou a regra |
| `triage` | relationship preservado; conversa/deal em triagem |
| `consultation_scheduled` | relationship preservado; atividade meeting pendente |
| `customer` | relationship customer, somente com evidência |
| `active_customer` | relationship customer + service active |
| `recurring_customer` | relationship customer + won_count ≥ 2 |
| `ex_customer` | relationship former_customer |
| `lost` | resultado do deal; não altera sozinho o relacionamento |
| alias `lead_qualified` | normalizar para `qualified_lead` antes de projetar |
| alias `in_triage` | normalizar para `triage` antes de projetar |
| alias `recurring` | normalizar para `recurring_customer` antes de projetar |
| `contact_type` | projeção temporária de compatibilidade, nunca fonte canônica |

Os nomes físicos de enum são confirmados no ADR da F1; a separação semântica é requisito vinculante. Aliases preservam APIs durante a migração.

Regras:

- negócio ganho, contrato, compra ou ID externo são evidências fortes de cliente;
- afirmação do contato é evidência média até confirmação;
- agenda do WhatsApp e inferência linguística são evidências fracas;
- evidência fraca nunca promove silenciosamente para cliente;
- toda alteração automática registra fonte, confiança, versão e timestamp;
- override humano exige motivo e fica auditado.

### 6.3 Intenção da conversa

Valores configuráveis por conta, com base inicial:

`sales`, `support`, `billing`, `retention`, `renewal`, `complaint`, `information`, `other`

Uma pessoa cliente pode ter intenção de venda; um prospect pode pedir suporte pré-venda. A intenção pertence à conversa, não à identidade permanente.

### 6.4 Oportunidade

Cada deal possui independentemente:

- pipeline e etapa;
- resultado open/won/lost;
- valor e moeda;
- responsável;
- próxima ação;
- tempo na etapa;
- motivo de perda;
- score e versão;
- origem/atribuição;
- checklist e campos obrigatórios.

Um contato pode ter múltiplas oportunidades, desde que o contrato por pipeline e status seja explícito.

### 6.5 Prioridade operacional

Não faz parte do score comercial. Deve considerar:

- SLA e proximidade de violação;
- urgência declarada/detectada;
- sentimento/frustração;
- cliente VIP;
- espera acumulada;
- risco ou tema sensível;
- capacidade e skill dos times.

### 6.6 Controle da IA

Separar configuração de implantação do estado da conversa.

**Modo do assistente por inbox/canal:**

`off | shadow | supervised | auto`

**Controle por conversa:**

`ai_active → handoff_pending → human_controlled → resume_pending → ai_active`

Compatibilidade:

| `ai_mode` atual | Modo do assistente | Controle da conversa |
|---|---|---|
| `auto` | auto | ai_active |
| `supervised` | supervised | ai_active, com aprovação quando configurada |
| `paused` | preserva o modo da inbox | human_controlled, motivo pause/manual |
| `human_only` | preserva o modo da inbox | human_controlled, takeover/handoff |

`off` e `shadow` não devem ser gravados como estado de cada conversa; são política de implantação. A migração mantém leitura dos quatro valores atuais até todos os consumidores usarem os dois eixos.

Cada transição registra:

- evento de origem;
- motivo estruturado e texto legível;
- ator humano ou versão do agente;
- destino/equipe;
- timestamp;
- contexto transferido;
- resultado posterior.

---

## 7. Arquitetura alvo do score

### 7.1 Fonte canônica

- O Core Rails será a fonte canônica do estado de score, histórico e política aplicada.
- O Orchestrator poderá calcular sugestões ou executar modelos em shadow mode, mas não gravar um estado concorrente sem contrato versionado.
- Algoritmos aposentados devem ser removidos do runtime e claramente marcados no código histórico.

### 7.2 Dimensões independentes

| Dimensão | Pergunta | Exemplos de evidência |
|---|---|---|
| Fit | o caso/oportunidade corresponde ao perfil atendido? | segmento, produto, área, critérios configuráveis |
| Intent | há intenção atual de avançar? | pedido de proposta, contratação, reunião, confirmação |
| Engagement | existe interação relevante e recente? | respostas, reuniões, documentos, retornos |
| Completeness | há dados suficientes para a próxima decisão? | campos obrigatórios, documentos, identificação |
| Timing | a oportunidade está no momento adequado? | prazo, janela, recência e próxima ação |
| Risk | há sinais que reduzem viabilidade ou exigem revisão? | conflito, inconsistência, spam, impedimento |

Urgência, sentimento e SLA permanecem como sinais operacionais separados.

### 7.3 Saída obrigatória de todo cálculo

```json
{
  "schema_version": "qualification-score-v2",
  "policy_key": "horizontal-core",
  "policy_version": "2.0.0",
  "crm_deal_id": 0,
  "qualification_score": 0,
  "classification": "not_evaluated|low|medium|qualified|high",
  "confidence": 0.0,
  "data_completeness": 0.0,
  "dimensions": {},
  "positive_factors": [],
  "negative_factors": [],
  "missing_factors": [],
  "evidence_refs": [],
  "input_fingerprint": "sha256",
  "calculated_at": "ISO-8601",
  "expires_at": "ISO-8601|null",
  "calculated_by": "rules|model|hybrid",
  "requires_review": false
}
```

Cada evidência deve indicar origem, mensagem/campo relacionado, confirmação e expiração quando aplicável.

`operational_priority` não faz parte desse payload comercial. Ela possui envelope próprio, ligado à conversa/SLA, com `level, reasons, policy_version, calculated_at` e expiração.

Compatibilidade v1 → v2:

| Campo/valor atual | Campo/valor canônico |
|---|---|
| `crm_deals.score_total`, `crm_lead_scores.total_score`, API `total` | `qualification_score` durante dual-read |
| `score_classification`/`classification` | `classification` |
| `baixo_potencial` | `low` |
| `medio_potencial` | `medium` |
| `qualificado` | `qualified` |
| `prioridade_alta` | `high`; o nome não transforma score em prioridade operacional |
| `factors/evidence` legados | fatores normalizados + `evidence_refs` |

Serializers podem emitir aliases legados durante a janela; persistência nova usa o contrato canônico e registra versão.

### 7.4 Evolução segura

1. Inventariar algoritmos e consumidores.
2. Definir política canônica v2 e schema de fatores.
3. Recalcular em shadow mode sem mover deals ou fazer handoff.
4. Comparar v1/v2 com revisão humana e desfechos.
5. Ajustar thresholds por vertical/pipeline.
6. Ativar exibição da v2, mantendo ação automática desligada.
7. Ativar automações de baixo risco.
8. Ativar auto-move de baixo risco apenas após seu gate quantitativo; handoff permanece governado pela HandoffPolicy, nunca pelo score.
9. Manter rollback para a política anterior por configuração.

### 7.5 Métricas de qualidade do score

- distribuição por bucket e origem;
- conversão por faixa;
- precisão/recall para “qualificado” quando houver amostra suficiente;
- calibração entre score e taxa real de ganho;
- taxa de override humano;
- falsos positivos e falsos negativos revisados;
- tempo entre mudança do score e ação;
- cobertura de evidências e campos ausentes;
- performance por versão/pipeline/vertical.

Até existir histórico suficiente, o score deve ser descrito como **qualificação explicável**, não como probabilidade preditiva.

---

## 8. Arquitetura alvo do CAPITÃO

### 8.1 Princípios

- Preservar o núcleo V2 funcional e melhorar contratos ao redor dele.
- Uma configuração visível deve governar o runtime ou não deve ser oferecida.
- Conhecimento factual, comportamento, automação e ferramentas são camadas distintas.
- Nenhuma inferência sensível deve se tornar fato sem evidência ou confirmação.
- Toda resposta ou ação relevante deve ser auditável.

### 8.2 Configuração unificada

Estrutura recomendada da experiência administrativa:

1. **Identidade e objetivo:** nome, descrição, tom e escopo.
2. **Canais:** toggles por inbox/canal e audiências permitidas.
3. **Conhecimento:** documentos, FAQs, status de indexação e gaps.
4. **Comportamento:** guidelines, guardrails, disclosure e limites.
5. **Triagem:** intenções, atributos, campos obrigatórios e confiança.
6. **Score:** política versionada, dimensões, thresholds e preview.
7. **Handoff:** gatilhos, destino, horário, SLA e mensagem de transição.
8. **Ferramentas:** permissões, parâmetros, sandbox e logs.
9. **Teste:** simulação por persona/canal com trace explicável.
10. **Ativação:** checklist, escopo, shadow/pilot/produção e rollback.

### 8.3 Handoff completo

Gatilhos mínimos:

- pedido explícito por humano;
- baixa confiança ou falta de fonte confiável;
- feedback negativo/frustração;
- repetição sem resolução;
- risco ou tema sensível;
- falha de ferramenta;
- SLA/VIP/urgência;
- regra comercial configurada;
- resposta humana detectada.

Pacote de contexto:

- motivo estruturado;
- resumo curto;
- intenção, sentimento e urgência;
- dados coletados e campos ausentes;
- score e fatores;
- fontes consultadas;
- ações tentadas e resultados;
- time/skill de destino;
- expectativa de espera;
- link para oportunidade e contato.

### 8.4 Base de conhecimento e RAG

- Status explícito por documento: queued, processing, ready, failed, stale.
- Conteúdo só entra em produção após indexação e smoke query.
- Fontes usadas devem ser registradas e exibidas no playground.
- Respostas sem fonte suficiente devem pedir contexto ou transferir.
- Criar conjunto de perguntas ouro por vertical e regressão a cada alteração.
- Separar FAQ aprovada, documento, memória confirmada e conteúdo de conversa.
- Implementar política de atualização, expiração, redaction e exclusão LGPD.

### 8.5 Memória

- Curto prazo: contexto da conversa atual com janela e resumo incremental.
- Longo prazo: fatos confirmados do contato com fonte, confiança e expiração.
- Operacional: ações, ferramentas, erros e estado do fluxo.
- Nunca persistir uma inferência como fato confirmado.
- Correção do usuário invalida ou versiona o fato anterior.
- PII sensível deve ser minimizada antes de telemetria ou chamada externa.

### 8.6 Avaliação contínua

O CAPITÃO precisa de uma suíte offline com casos anonimizados:

- saudações e conversas sem intenção clara;
- leads novos, clientes confirmados e contatos incertos;
- negação, ironia, correção e informações contraditórias;
- pedido explícito de humano;
- baixa confiança e ausência de fonte;
- documentos, áudio, imagem e erro de mídia;
- tentativas de prompt injection;
- temas fora de escopo;
- falhas e timeout de ferramentas;
- retomada após handoff;
- casos por vertical, canal e versão do modelo.

Cada caso avalia: resposta, tom, grounding, ação, score, classificação, handoff, segurança, latência e custo.

---

## 9. Direção de UX e Design System

### 9.1 Linguagem visual

- Direção Midnight Indigo / Nocturnal Architect.
- Manrope para títulos; Inter para corpo, labels e dados densos.
- Profundidade por tons, espaço, blur e elevação suave.
- Bordas duras apenas quando semanticamente necessárias.
- Gradiente reservado para CTA primário ou insight crítico.
- Tema claro semanticamente equivalente; não apenas inversão de cores.
- Densidade configurável para usuários operacionais.

### 9.2 Tokens

Fonte pública única via tokens semânticos `--ds-*`:

- background, surface, surface-raised e overlay;
- text-primary, secondary, muted e inverse;
- primary, success, warning, danger e info;
- focus, selection e disabled;
- spacing em escala de 4px;
- tipografia 12/13/14/16/18/24/32;
- radius e elevação com no máximo três níveis;
- motion, duração e easing;
- z-index por categoria.

Escalas Radix e aliases antigos devem apontar temporariamente para os tokens, não competir com eles.

### 9.3 Primitives prioritárias

- AppShell e PageShell;
- PageHeader e SectionHeader;
- Button, IconButton e SplitButton;
- FormField, Input, Select, Combobox e SearchField;
- SurfaceCard, MetricCard e InsightCard;
- Table/List, FilterBar e BulkActionBar;
- Badge, StatusPill, Avatar e Tooltip;
- Drawer, Modal, Popover e CommandMenu;
- Tabs e SegmentedControl;
- EmptyState, Skeleton, ErrorState e PermissionState;
- Timeline e ActivityItem;
- ConversationContextPanel;
- DealCard e PipelineColumn;
- AIStatus, AIMessageBadge e HandoffEvent.

### 9.4 Arquitetura de informação

Navegação principal recomendada:

1. **Atendimento** — inboxes, views e notificações.
2. **Relacionamentos** — contatos, empresas e segmentos.
3. **CRM** — pipeline, oportunidades, atividades e agenda.
4. **Inteligência** — CAPITÃO, AI Center, conhecimento e avaliações.
5. **Campanhas** — canais e audiências.
6. **Análises** — atendimento, vendas, IA e qualidade.
7. **Configurações** — agrupadas por conta, equipe, canais, automações, integrações e segurança.

O menu deve ser adaptado por papel. Recursos raros permanecem em configurações e command palette, não competem com tarefas diárias.

---

## 10. Experiência-alvo por área

### 10.1 Shell, navegação e busca global

O shell deve reduzir troca de contexto e tornar as ações diárias previsíveis:

- sidebar compacta e orientada por papel, com indicação clara da conta atual;
- persistência do último contexto por módulo, sem perder filtros ou item aberto;
- breadcrumbs apenas quando ajudarem orientação;
- command palette existente, baseada em `@chatwoot/ninja-keys`, ampliada em vez de duplicada;
- busca global por contato, telefone, empresa, conversa, negócio e atividade;
- ações rápidas para nova conversa, contato, negócio e atividade;
- atalhos documentados, com alternativa acessível;
- notificações agrupadas por urgência, origem e possibilidade de ação;
- feedback imediato para navegação, salvamento, erro e desfazer.

Critérios de aceite:

- qualquer entidade principal pode ser encontrada em até três interações;
- trocar de módulo não elimina trabalho em andamento sem confirmação;
- menus, deep links, command palette e API respeitam a mesma permissão;
- uso integral por teclado e foco visível;
- 360 px não produz navegação bloqueada nem overflow horizontal involuntário.

### 10.2 Workspace unificado de atendimento

A Inbox deve operar como um workspace adaptável de três regiões:

1. fila/lista com filtros salvos, SLA, prioridade e estado IA/humano;
2. conversa com composer, mensagens, notas e eventos operacionais;
3. contexto da pessoa com timeline, negócio, score, próxima ação e CAPITÃO.

Em telas menores, as regiões viram uma pilha navegável, preservando o ponto exato da conversa. O painel contextual deve responder sem navegação adicional:

- quem é esta pessoa e qual é o nível de verificação;
- se é prospect, cliente, ex-cliente ou estado ainda incerto;
- qual é a intenção desta conversa;
- se existe oportunidade ativa e quem é o responsável;
- qual é a próxima ação e o risco de atraso;
- se a IA está ativa, supervisionada ou pausada;
- por que ocorreu score, classificação ou handoff;
- quais dados ainda faltam.

Melhorias obrigatórias:

- selo visual e descrição acessível para mensagem do CAPITÃO;
- estado IA/humano na lista e no cabeçalho;
- takeover e retomada em um clique, com confirmação proporcional ao risco;
- nota privada visualmente inequívoca;
- preview, upload progressivo, retry e falha acionável de mídia;
- eventos de score, mudança de lifecycle, deal e handoff na timeline;
- resposta otimista apenas quando houver idempotência e reconciliação;
- realtime testado em duas sessões, sem duplicação.

### 10.3 Contato/Cliente 360

O registro 360 deve reunir:

- identidade e meios de contato;
- evidências do relacionamento e histórico de mudanças;
- conversas, notas, atividades, campanhas e consentimentos;
- oportunidades abertas e encerradas;
- score atual, histórico, fatores e dados faltantes;
- handoffs e intervenções humanas;
- documentos, campos customizados e vínculos externos;
- preferências, opt-out, retenção e solicitações LGPD.

Padrões:

- edição inline para campos de baixo risco;
- confirmação e motivo para merge, lifecycle e alterações sensíveis;
- timeline filtrável por tipo de evento;
- sugestões de duplicidade sem fusão automática destrutiva;
- source badge para distinguir dado humano, integração, regra ou IA;
- acesso ao registro completo sem fechar a conversa.

### 10.4 CRM: Kanban, lista e detalhe

O CRM precisa oferecer duas representações equivalentes:

- Kanban para fluxo e priorização visual;
- lista/tabela para busca, comparação, seleção e operação em massa.

Cada card/linha deve mostrar, conforme densidade:

- contato/empresa;
- valor e moeda;
- etapa e tempo nela;
- responsável;
- score e confiança, sem transformar cor em único sinal;
- próxima atividade e atraso;
- origem e principais tags;
- estado de comunicação/IA quando relevante.

O detalhe do negócio deve manter contexto e permitir:

- atualizar etapa, valor, responsável e campos;
- agendar a próxima ação;
- ganhar, perder, reabrir ou arquivar com histórico;
- registrar motivo de perda estruturado e nota;
- consultar conversas e timeline;
- responder pelo drawer quando autorizado;
- explicar score e alterações recentes.

Funcionalidades-alvo:

- rotting configurável por pipeline/etapa;
- filtros e views salvos;
- somas reconciliadas por coluna e resultado;
- operação com 201 e 1.000 negócios sem itens invisíveis;
- seleção em massa com preview, autorização e desfazer quando seguro;
- drag por mouse/toque, alternativa por teclado e ação explícita de mover;
- deep link que abre e destaca o negócio correto;
- virtualização somente quando profiling demonstrar necessidade.

### 10.5 Atividades e agenda

- visões dia, semana, mês e lista;
- timezone explícito e consistente;
- criação rápida a partir de conversa, contato ou negócio;
- atribuição, lembrete, recorrência e conclusão;
- conflito e atraso visíveis;
- próxima atividade integrada ao Kanban e ao Cliente 360;
- reconexão e diagnóstico da integração Google;
- drawers e formulários compartilhados, não implementações paralelas.

### 10.6 Relatórios e centro de inteligência

Relatórios devem usar vocabulário e denominadores únicos entre atendimento, CRM e IA:

- volume, primeira resposta, resolução, SLA e CSAT;
- pipeline, conversão, ciclo, valor, forecast e motivos de perda;
- atuação da IA, contenção, handoff, reabertura, erro, latência e custo;
- distribuição, cobertura, override e qualidade do score;
- qualidade de dados e atividades atrasadas.

Todo número deve exibir definição, período, timezone, filtros e possibilidade de reconciliação. Dashboards operacionais devem levar à lista de itens que compõe o indicador.

### 10.7 Configurações e onboarding

Configurações devem ser pesquisáveis e agrupadas por:

- conta e identidade;
- usuários, times, papéis e segurança;
- canais e inboxes;
- CRM, pipelines e campos;
- automações e cadências;
- CAPITÃO e conhecimento;
- integrações;
- dados, privacidade e auditoria.

O onboarding deve possuir checklist verificável:

1. criar ou selecionar conta;
2. conectar um canal em sandbox/produção;
3. convidar equipe e revisar permissões;
4. configurar pipeline e próxima ação;
5. configurar CAPITÃO em shadow/playground;
6. enviar e receber uma mensagem de teste;
7. executar handoff;
8. criar e concluir uma oportunidade;
9. consultar o primeiro relatório.

Estados vazios devem ensinar a próxima ação sem esconder restrições ou inventar dados.

---

## 11. Modelo operacional do plano

### 11.1 Legenda de status

| Status | Significado |
|---|---|
| ✅ Verificado | evidência executada e suficiente está anexada ao requisito |
| 🟡 Implementado, não validado | código ou configuração existe, mas falta um ou mais gates |
| ⬜ Pendente | ainda não implementado ou não iniciado |
| ⛔ Bloqueado | impedimento externo ou decisão obrigatória documentada |

Presença de arquivo, teste isolado ou tela renderizada não produz status verificado. O status pertence ao requisito e à sua evidência, não apenas ao código.

### 11.2 Registro mínimo por item executável

Cada épico ou tarefa deve conter:

| Campo | Conteúdo |
|---|---|
| ID | identificador estável, por exemplo `F0-TEN-01` |
| Status | um dos quatro estados acima |
| Problema/evidência | origem concreta do trabalho |
| Resultado esperado | comportamento observável |
| Dependências | tarefas, decisões, dados ou integrações |
| Áreas/arquivos | superfície provável, confirmada no início da tarefa |
| Dados/migration | impacto, backfill e compatibilidade |
| Testes obrigatórios | camadas e cenários |
| Critério de aceite | condição binária de aprovação |
| Evidência | relatório, trace, screenshot, métrica ou log sanitizado |
| Rollback | como desativar/reverter sem perda |
| Responsável | função accountable e executor |

### 11.3 Ledger do worktree

Antes de novos lotes, criar um ledger que classifique cada alteração atual em:

- correção válida do plano vigente;
- melhoria implementada aguardando validação;
- mudança preexistente do usuário;
- resíduo do plano jurídico incorreto;
- artefato incerto que exige decisão.

O ledger deve registrar arquivo, origem, decisão, teste, commit proposto e rollback. É proibido usar reset, checkout global ou limpeza em massa para organizar o worktree.

### 11.4 Caminho crítico

`reconciliar worktree → baseline reproduzível → fixture e harness E2E → tenancy/IDs/RBAC → gate F0 → benchmark + taxonomia → [tokens/primitives || fundação de identidade/eventos] → redesign por fatias → score v2 + CAPITÃO controlável → funcionalidades priorizadas → regressão completa → rollout`

Dependências invariáveis:

- a taxonomia é aprovada na F1 e a fundação de identidade F3-EN precede Inbox/Cliente 360, lifecycle automático, score, automações e métricas;
- contratos de tenant, IDs e permissões precedem qualquer redesign promovido;
- harness E2E precede refatoração ampla;
- design tokens e primitives precedem migração de páginas;
- contratos de eventos e dados precedem dashboards finais;
- configuração única de handoff precede automação do CAPITÃO;
- score em shadow mode precede movimentação automática de deal;
- feature flag e rollback precedem piloto.

### 11.5 Regra de fatiamento

Cada entrega deve ser uma fatia vertical que inclua, quando aplicável:

- migration aditiva;
- regra de domínio;
- API/serializer;
- interface e i18n;
- autorização e tenant;
- telemetria;
- testes unitários, integração e E2E;
- acessibilidade e performance;
- feature flag e rollback;
- atualização documental.

---

## 12. Fase 0 — Reconciliar, proteger e completar a auditoria

**Objetivo:** produzir uma baseline confiável e fechar riscos que tornam qualquer redesign inseguro.

**Estado inicial:** auditoria estática forte; validação autenticada, visual, acessível e E2E ainda incompleta.

**Estimativa relativa:** 4 a 6 semanas com trabalho paralelo de engenharia, QA e design.

### 12.1 Onda F0.0 — Proteger e classificar o estado atual

| ID | Trabalho | Entregável | Aceite |
|---|---|---|---|
| F0-WT-01 | inventariar o diff e aplicar o ledger | `docs/execution/WORKTREE-LEDGER.md` | nenhum diff sem origem/decisão |
| F0-BKP-01 | validar backup e restauração em cópia descartável | relatório de restore | contagens e checksums reconciliados |
| F0-ENV-01 | validar containers, migrations, filas e health checks | baseline de ambiente | stack sobe por `SETUP.md` sem passo implícito |
| F0-DOC-01 | reconciliar README, ADRs, auditorias e serviços ativos | documentos atualizados | nenhuma contradição P0 conhecida |
| F0-CPU-01 | manter `core-vite` opt-in e separar benchmark do watcher | perfil de execução | watcher não contamina medições |

Cuidados:

- o backup cobre dump legível do PostgreSQL, `core-storage`, volumes/dados da Evolution e uma cópia fora do host Docker;
- preservar a migration `20260703000003` já aplicada, mesmo que o campo permaneça temporariamente inerte;
- não usar `docker compose down -v`;
- não misturar serviços aposentados com a arquitetura ativa;
- fracionar mudanças aceitas em commits pequenos depois que o ledger estiver aprovado.

### 12.2 Onda F0.1 — Corrigir CI e contratos de engenharia

O CI deve refletir o produto realmente executado:

- remover ou desativar jobs de `crm-service` e `identity-bridge` aposentados;
- alinhar Rails a Ruby 3.4.4;
- adicionar frontend Core em Node 24 e pnpm 10;
- substituir comandos inexistentes do Orchestrator por instalação, testes, build e auditoria válidos;
- usar lockfiles congelados;
- aplicar lint incremental aos arquivos alterados sem transformar o ruído legado de CRLF/Prettier em falso gate;
- executar Brakeman, bundler-audit, auditoria de dependências, TruffleHog e build;
- publicar artefatos de testes e evidências, sem segredos.

**Gate F0.1:** o selo do CI cobre Core backend, Core frontend e Orchestrator ativos; falhas não são mascaradas por `continue-on-error` ou jobs irrelevantes.

### 12.3 Onda F0.2 — Segurança, tenancy, IDs e permissões

Prioridades P0:

- resolver `crm_deal_id` sempre dentro da conta da conversa;
- validar que pipeline, etapa, contato, inbox, owner e assignee pertencem à mesma conta do deal;
- aplicar escopo de conta em jobs, exportações, websocket, memória, anexos e ferramentas;
- manter `database_id` para relacionamentos internos e `display_id` para navegação/exibição;
- testar colisão controlada de IDs entre contas;
- garantir 403/404 sem revelar a existência do recurso;
- aplicar RBAC e feature flags em menu, deep link, API e jobs;
- autenticar e derivar tenant nas rotas `/skills/*` e `/knowledge/*` do Orchestrator;
- revisar assinatura, replay, idempotência e rate limit de webhooks.

Correções de contrato de rota no mesmo gate:

- `/profile` precisa de destino padrão ou estado contextual, nunca tela vazia;
- ID inválido em ChannelFactory precisa retornar 404 contextual, nunca render vazio;
- o canal Twitter precisa de ADR: expor sob feature gate quando suportado ou deprecar/remover rota; UI e API devem executar a mesma decisão;
- rotas revisadas de reports precisam respeitar a mesma feature flag na UI e API;
- aliases, redirects e installation types precisam de testes de deep link.

Áreas iniciais:

- `core/app/controllers/api/v1/accounts/crm/`;
- `core/app/controllers/api/v1/accounts/captain/`;
- models e services `crm_*`;
- serializers de conversa/deal;
- rotas/policies Vue e Rails;
- jobs e integrações do Orchestrator.

**Gate F0.2:** todos os testes Conta A × Conta B negam leitura, associação, mutation, exportação, websocket e tool call cross-tenant, sem vazamento de metadados.

### 12.4 Onda F0.3 — Fixture canônica e harness de QA

Criar fixture versionada, idempotente e sanitizada com:

- Contas A e B;
- admin, operador, vendedor, gestor, gestor de conhecimento e custom role mínima;
- usuário sem conta, conta suspensa e super-admin;
- IDs interno/display divergentes e colisões numéricas controladas;
- Inbox API/Web determinística e Evolution sandbox;
- CAPITÃO ligado apenas à inbox de teste;
- FAQ, documento pronto/falho, regra de handoff e debounce conhecido;
- pipeline Novo/Qualificação/Proposta/Negociação/Ganho/Perdido;
- motivo de perda conhecido `Sem retorno` em `crm_loss_reasons`;
- deals open, won, lost e archived;
- 201 negócios para regressão e 1.000 para capacidade;
- valores conhecidos para somas e relatórios;
- lead, cliente comprovado, ex-cliente, desconhecido, contato apenas salvo no WhatsApp, duplicado e opt-out;
- conversas longas, texto, áudio, imagem, falha de mídia e webhook duplicado;
- SMTP de captura, Sidekiq, ActionCable e timezone `America/Sao_Paulo`;
- relógio controlável e limpeza pós-teste.

Criar Playwright em projeto próprio:

- storage state por persona;
- Chromium, Firefox e WebKit;
- traces, screenshots e vídeo apenas quando necessário;
- axe nas famílias críticas;
- execução local containerizada e em CI;
- manifesto gerado a partir do inventário de rotas, incluindo drawers, modais, abas e ChannelFactory.

### 12.5 Onda F0.4 — Completar e atualizar auditorias

Atualizar:

- `AUDITORIA.md`;
- `AUDITORIA-CSS.md`;
- `AUDITORIA-FUNCIONAL.md`;
- `docs/audit/INVENTARIO-ROTAS.md`.

Criar:

- `AUDITORIA-CAPITAO.md`;
- `docs/qa/MATRIZ-COBERTURA.md`;
- baseline autenticada de screenshots, axe, performance e segurança.

A auditoria do CAPITÃO deve traçar:

- mensagem recebida → trigger → debounce/locks → contexto → modelo → ferramenta → resposta;
- configuração exibida versus realmente consumida;
- quatro motores de score, thresholds 60/75/80/90 e consumidores;
- lead/cliente/lifecycle;
- memória, resumo, RAG e fontes;
- handoff, takeover e retomada;
- links Inbox/CRM e IDs;
- dados enviados ao LLM;
- métricas, denominadores e falhas silenciosas.

### 12.6 Gate de saída da Fase 0

A Fase 0 só termina quando:

- o worktree possui ledger e backup restaurável;
- CI corresponde à arquitetura ativa;
- fixtures e Playwright são reproduzíveis;
- toda tentativa cross-account crítica é negada;
- todas as famílias de tela foram abertas autenticadas nos cinco viewports;
- light/dark e personas aplicáveis foram exercitados;
- estados loading, vazio, erro, offline, permissão e confirmação foram auditados;
- não há violação axe crítica/séria aberta nos P0;
- o cenário composto E2E-P0-00 (`mensagem → CAPITÃO → handoff → humano → negócio → Kanban → ganho/perda`) executa duas vezes sem falha;
- o 201º negócio é acessível e as somas conferem;
- Evolution, Google e LLM têm ao menos um cenário em sandbox;
- as auditorias indicam data, commit, ambiente e evidências.

---

## 13. Fase 1 — Benchmark, definição do produto e protótipos

**Objetivo:** transformar dores comprovadas em arquitetura de informação, jornadas e requisitos mensuráveis.

**Dependência:** Gate F0.

**Estimativa relativa:** 3 a 5 semanas, parcialmente paralela ao encerramento documental da Fase 0.

### 13.1 Entregáveis

- `BENCHMARK.md` com fontes primárias;
- `PRD-REFORMULACAO-CRM.md`;
- mapa de arquitetura de informação;
- service blueprint das jornadas P0;
- wireframes e protótipos navegáveis;
- inventário “já existe / parcial / ausente”;
- métricas baseline e metas;
- ADRs de domínio, navegação, design e score.

### 13.2 Matriz competitiva obrigatória

Comparar Attio, HubSpot, Pipedrive, Intercom, Crisp, Salesforce, Zendesk, RD Station, Kommo, Zenvia e o Chatwoot atual. Usar Linear e Notion como referências adjacentes de velocidade, navegação e complexidade progressiva, sem tratá-los como CRMs equivalentes. Avaliar:

- navegação e busca;
- Inbox e colaboração;
- registro 360;
- pipeline e próxima ação;
- lifecycle, score e automações;
- IA, handoff e supervisão;
- configuração e onboarding;
- relatórios;
- mobile, acessibilidade e velocidade percebida.

Cada padrão recebe uma decisão:

- **adotar:** serve diretamente ao problema;
- **adaptar:** útil, mas precisa respeitar arquitetura/personas;
- **rejeitar:** aumenta complexidade, duplica recurso ou não atende o contexto;
- **experimentar:** hipótese que exige protótipo ou métrica.

Não copiar aparência isolada; registrar problema, comportamento, trade-off e evidência.

### 13.3 Pesquisa com usuários e tarefas críticas

Entrevistar representantes de operação, vendas, gestão, administração e qualidade de IA. Medir no produto atual:

- taxa de conclusão;
- tempo e quantidade de interações;
- erros e retrocessos;
- pontos de troca de módulo;
- confiança na informação;
- necessidade de treinamento.

Tarefas P0:

1. localizar e responder conversa;
2. assumir atendimento da IA;
3. identificar corretamente o relacionamento;
4. criar/reutilizar deal;
5. registrar próxima ação;
6. mover, ganhar ou perder deal;
7. explicar score e corrigir dado;
8. configurar/testar CAPITÃO;
9. consultar relatório reconciliável.

### 13.4 Decisões que precisam sair da fase

- núcleo horizontal versus pacote jurídico configurável;
- vocabulário canônico de identidade, relacionamento, intenção e oportunidade;
- IA da sidebar e composição da command palette;
- modelo de permissões por papel;
- Manrope/Inter + Midnight Indigo como identidade oficial;
- adendo/ADR-008 para F2A/F2B incremental ou manutenção da ordem estrita do prompt;
- contratos Core ↔ Orchestrator conforme a decisão vinculante da F0, sem criar uma segunda fonte de verdade;
- política canônica de score e handoff;
- browsers suportados e budgets iniciais;
- estratégia de feature flags e rollout.

### 13.5 Gate de saída da Fase 1

- `BENCHMARK.md` aprovado com fontes rastreáveis;
- PRD e não objetivos aprovados;
- jornadas P0 prototipadas e testadas com usuários representativos;
- problemas críticos demonstrados com baseline;
- cada decisão relevante registrada em ADR;
- nenhuma função duplicada sem busca no Chatwoot/Core/Enterprise;
- backlog priorizado por impacto, esforço, risco e dependência;
- critérios de aceite e métrica definidos antes da implementação.

---

## 14. Fase 2 — Design System, CSS e fundação visual

**Objetivo:** criar uma linguagem visual única e uma base técnica que permita redesenhar por família sem um big bang de CSS.

**Dependências:** arquitetura de informação e direção visual aprovadas na Fase 1.

**Estimativa relativa:** 4 a 7 semanas para a fundação; a migração segue nas fases posteriores.

Proposta de execução: dividir a fase em **F2A — fundação** e **F2B — migração/limpeza completa**. Como o prompt original pode ser interpretado como “concluir toda a limpeza antes da F3”, esse paralelismo só é válido após:

1. aprovação explícita do Product Owner/usuário como adendo ao prompt;
2. registro do ADR-008 em `DECISOES.md`;
3. definição dos gates F2A, F2B-RC e F2B-FINAL abaixo.

Sem esse adendo, vale a leitura estrita: F3 fica bloqueada até F2B-FINAL. Com o adendo, F3 pode começar após F2A, F2B migra cada família junto da fatia correspondente, GA preserva um fallback inativo e a reformulação só é encerrada após F2B-FINAL.

### 14.1 Onda F2.0 — Guardrails antes da remoção

- registrar baseline por bundle: tamanho, regras, seletores, especificidade, tokens, hardcodes, breakpoints e `!important`;
- adicionar Stylelint/auditores incrementais apenas sobre arquivos alterados;
- bloquear novo hardcode de cor fora de tokens/assets;
- bloquear novo `!important` sem exceção documentada;
- definir breakpoints oficiais;
- mapear ordem real de importação e especificidade;
- criar visual regression das primitives e primeiras famílias;
- implementar o ADR de identidade visual aprovado no Gate F1; se ele ainda não existir, a F2 fica bloqueada;
- manter aliases antigos apontando para `--ds-*` durante transição.

Baseline a reduzir:

- 20.661 linhas autorais;
- 9.206 linhas no CRM;
- 504 `!important` no conjunto auditado, sendo 338 no tema principal;
- 146 tokens redefinidos;
- 20 breakpoints autorais.

### 14.2 Onda F2.1 — Tokens e integração Tailwind

Criar `docs/chusterm_design_system.md` e `docs/DESIGN.md` como referências vigentes. Definir:

- cores semânticas light/dark;
- tipografia, pesos e line heights;
- espaçamento 4 px;
- radii e elevação;
- motion e reduced motion;
- z-index;
- densidade confortável/compacta;
- estados hover, active, focus, disabled, loading, error e success;
- gráficos e visualização de dados;
- contraste e uso não exclusivo de cor.

`tailwind.config.js` deve consumir os mesmos tokens semânticos. Tailwind será o padrão para novos componentes e migrações; SCSS legado pode permanecer apenas enquanto a família ainda não foi migrada.

**Aceite:** alterar um token light/dark modifica Tailwind e primitives sem reimplementação paralela.

### 14.3 Onda F2.2 — Primitives e catálogo

Implementar as primitives listadas na seção 9.3, começando por:

1. Button/IconButton;
2. FormField/Input/Select/Search;
3. PageShell/PageHeader;
4. SurfaceCard/MetricCard;
5. Empty/Skeleton/Error/Permission;
6. Modal/Drawer/Popover/Confirm;
7. Table/List/FilterBar;
8. Badge/Status/Tooltip;
9. Timeline;
10. elementos de CRM e IA.

Cada primitive deve possuir:

- API mínima e documentada;
- variantes sem duplicar semântica;
- estados light/dark;
- teclado, foco e nomes acessíveis;
- área de toque mínima de 44 × 44 CSS px quando interativa;
- testes Vitest/Vue Test Utils;
- axe no componente;
- stories Histoire ou catálogo equivalente;
- snapshot visual nos estados críticos;
- uso real em ao menos uma fatia piloto.

### 14.4 Onda F2.3 — Migração piloto

Ordem proposta de menor para maior risco:

1. Automation Rules e Checklist Templates;
2. busca, select e button compartilhados;
3. Activities, Cadences, Reports e Pipeline Settings;
4. All Leads e Deal Details;
5. Agenda;
6. CRM Index e drawer/chat do Kanban;
7. Inbox, settings, login e superfícies restantes.

Em cada slice:

1. medir antes;
2. migrar para tokens/primitives;
3. aprovar comportamento, visual e a11y;
4. remover imediatamente sobreposição/override redundante da implementação nova, mantendo apenas o bundle antigo isolado atrás da flag;
5. promover a família e cumprir a janela de segurança;
6. remover o bundle antigo em uma release de limpeza posterior;
7. medir depois e registrar redução da dívida.

Não manter duas cascatas atuando sobre a mesma superfície e não manter o fallback após a janela definida.

### 14.5 Áreas técnicas centrais

- `core/app/javascript/dashboard/assets/css/chusterm-theme.css`;
- `core/app/javascript/dashboard/assets/scss/_next-colors.scss`, `_design-tokens.scss` e `_woot.scss` no mesmo diretório;
- `core/tailwind.config.js` ou configuração Tailwind efetiva;
- entrypoints e `core/app/javascript/dashboard/App.vue`;
- componentes CRM, CAPITÃO e `components-next/`;
- overlays correspondentes em `core/enterprise/`;
- i18n PT-BR e idiomas upstream afetados.

O caminho exato deve ser confirmado no início de cada tarefa; o mapa serve para orientar busca, não autorizar edição cega.

### 14.6 Gate F2A — Fundação

- uma fonte pública de tokens;
- uma cadeia de importação documentada por bundle;
- primitives prioritárias testadas e usadas por uma família piloto;
- nenhum novo `!important` ou hardcode não autorizado;
- dívida CSS total não aumenta e a família migrada reduz dívida;
- somente breakpoints oficiais nos arquivos novos/migrados;
- dark mode, foco, reduced motion, 44 px e 320/360 px aprovados;
- nenhum overflow involuntário;
- catálogo visual e snapshots aprovados;
- orçamento de CSS automatizado;
- ledger global da dívida com meta por família, owner e prazo até F6;
- rollback da família piloto exercitado.

F2A não autoriza chamar a Fase 2 de concluída.

### 14.7 F2B — Migração e limpeza completa

**Gate F2B-RC, obrigatório antes da F6/release candidate:**

- todas as famílias ChusteRM em escopo estão migradas ou possuem exceção assinada e expiração;
- nenhuma cascata/override legado atua sobre a superfície nova;
- tokens, imports e breakpoints possuem uma fonte ativa;
- duplicações, hardcodes e CSS morto identificados nas auditorias foram removidos ou justificados individualmente;
- contagem autoral, especificidade e `!important` estão abaixo da baseline e dentro das metas aprovadas em F2A;
- bundle antigo existe apenas isolado atrás da flag de rollback;
- regressão visual/a11y/performance completa está aprovada.

**Gate F2B-FINAL, obrigatório para encerrar a reformulação:**

- janela de segurança da seção 24.6 cumprida;
- fallback antigo e seus bundles/aliases não necessários removidos em release de limpeza;
- coverage dinâmica confirma ausência de seletor necessário removido;
- build, E2E-P0-00 e visual regression passam sem a flag antiga;
- ledger CSS fecha todos os itens ou registra exceção permanente aprovada;
- sign-off Design + Tech + QA + Operações.

---

## 15. Fase 3 — Redesign por fatias verticais

**Objetivo:** reconstruir a experiência sem perder funcionalidades, usando os contratos e primitives aprovados.

**Dependências:** Gates F0, F1 e F2A. Começar antes de F2B-FINAL exige o adendo/ADR-008 aprovado; sem ele, F2B-FINAL também é dependência.

**Estimativa relativa:** 10 a 16 semanas, com no máximo duas fatias em implementação simultânea.

### 15.1 Método de cada fatia

Antes de codificar:

- confirmar problema, baseline e tarefa do usuário;
- comparar Core e `core/enterprise/`;
- mapear rotas, componentes, API, jobs e permissões;
- criar protótipo e estados;
- definir telemetria e feature flag;
- listar contratos que não podem mudar.

Durante:

- backend, frontend, i18n, autorização e observabilidade caminham juntos;
- estados loading, vazio, erro, offline, conflito e sem permissão são parte do requisito;
- dados otimistas exigem idempotência e reconciliação;
- alterações visuais usam tokens/primitives.

Depois:

- unit/component/request/contract/E2E;
- cinco viewports e light/dark;
- teclado, axe e teste manual de leitor de tela nos P0;
- comparação de performance;
- UAT por persona;
- documentação, flag e rollback;
- remoção do legado apenas após estabilidade.

### 15.2 F3-EN — Fundação de identidade e eventos

Esta é uma fatia habilitadora, definida na F1 e executada antes de F3B/F3C:

- schema aditivo para identidade, relacionamento, evidência, fonte, confiança e override;
- histórico auditável de transições;
- aliases compatíveis entre os nomes atuais e a taxonomia-alvo;
- eventos versionados para lifecycle, score, handoff, deal e atividade;
- API que representa estado incerto sem inventar classificação;
- edição/promoção manual permissionada e com motivo;
- dry-run dos dados atuais, sem reclassificação automática;
- testes Conta A/B, migration e rollback lógico.

Enquanto CAP-02 não automatizar a classificação, Inbox e Cliente 360 devem mostrar estado confirmado, incerto ou “revisão necessária”; não podem inferir silenciosamente cliente.

**Gate F3-EN:** contrato aprovado por Produto/Tech/Privacidade, migrations compatíveis, histórico reproduzível, fixtures lifecycle aprovadas e nenhum consumidor usando agenda do WhatsApp como prova de cliente.

### 15.3 F3A — Shell, navegação e command palette

Entregas:

- sidebar por função e frequência;
- seletor de conta inequívoco;
- arquitetura Atendimento/Relacionamentos/CRM/Inteligência/Campanhas/Análises/Configurações;
- expansão da command palette existente;
- busca global federada;
- ações rápidas permissionadas;
- breadcrumbs e contexto persistente;
- notificação agrupada e acionável.

Casos obrigatórios:

- custom role vê somente recursos autorizados;
- deep link sem permissão não revela dados;
- troca de conta invalida estado e busca;
- 360 px e teclado cobrem navegação completa;
- pesquisa com latência, vazio, erro e resultado parcial.

### 15.4 F3B — Workspace de atendimento

Entregas:

- layout lista/conversa/contexto responsivo;
- filtros salvos e prioridade/SLA;
- cabeçalho com identidade, intenção e IA/humano;
- composer coerente por canal;
- nota privada, anexos, retry e estados de entrega;
- painel Cliente 360 compacto;
- eventos de CRM e CAPITÃO na timeline;
- takeover/retomada;
- realtime sem duplicidade.

Os cards/ações atuais do CAPITÃO precisam substituir resumo placeholder, consumir o link do deal correto e provar navegação Inbox ↔ CRM com IDs divergentes.

Não redesenhar a Inbox como página isolada: ela é o ponto de integração com contato, deal, atividades, score e CAPITÃO.

### 15.5 F3C — Cliente 360 e relacionamentos

Entregas:

- cabeçalho de identidade verificada;
- relacionamento canônico e evidência;
- edição inline;
- timeline unificada e filtrável;
- oportunidades e próxima ação;
- histórico de score/lifecycle;
- alerta de possível duplicidade e merge manual auditado sobre contratos existentes;
- preferências e controles LGPD.

Casos críticos:

- contato salvo no WhatsApp continua sem prova de cliente;
- cliente com nova intenção comercial recebe atendimento adequado;
- ex-cliente é alcançável;
- evidência conflitante produz estado incerto e revisão;
- merge manual preserva conversas, deals, autoria e rollback lógico; matching avançado fica na F5.

### 15.6 F3D — CRM, Kanban, lista e detalhe

> **Registro de execução (2026-07-14):** a primeira fatia de redesign do CRM
> Index/Kanban foi implementada e validada em cinco viewports. Ela cobre
> hierarquia, ações, filtros, KPIs, saúde operacional, colunas, cards, estados e
> responsividade. Evidências, testes e pendências estão em
> `docs/execution/F3D-CRM-REDESIGN-PILOT.md`. Esta entrega é um piloto validado,
> não a conclusão da F3D.

Primeiro validar o que já existe no worktree:

- paginação além de 200;
- valor no card e soma por coluna;
- ganho, perda, motivo e reabertura;
- exportação assíncrona;
- filtros e realtime;
- drawer integrado à conversa.

Definir antes da UI o conjunto operacional do board: quais combinações de `status` e `operational_status` aparecem em abertos, won, lost e archived, e como contagem/soma tratam cada uma.

Depois completar:

- lista/tabela equivalente;
- próxima ação e atraso;
- tempo na etapa e rotting;
- views salvas;
- bulk actions seguras;
- drag acessível e alternativa explícita;
- deep links;
- desempenho com 1.000 deals;
- renderização/validação dos campos e checklists existentes; builder avançado fica na F5;
- forecast explicável.

Completar CRUD e permissões dos motivos de perda; ganhar/perder usa o dialog acessível compartilhado, não `confirm()` nativo.

Aceites financeiros:

- valor e moeda preservados;
- totais do board, lista, relatório e exportação reconciliam;
- ganho/perda registra ator, horário, etapa, motivo e histórico;
- retry não duplica transação;
- update concorrente gera conflito tratável, não perda silenciosa.

### 15.7 F3E — Agenda, atividades, cadências e automações

Entregas:

- agenda dia/semana/mês/lista;
- timezone e recorrência;
- atividades em contexto;
- próxima ação obrigatória/configurável por etapa;
- cadências com pausa, saída e auditoria;
- preservação/redesign das automações existentes, com idempotência, preview e logs;
- integração Google reconectável;
- formulários/drawers compartilhados.

Gates especiais:

- DST/timezone testado;
- reexecução de job/webhook não duplica atividade;
- falha externa é visível e recuperável;
- automação em massa exige preview, permissão e limite.

O builder visual avançado de novas automações pertence à F5.

### 15.8 F3F — Relatórios, configurações e onboarding

Entregas:

- dicionário de métricas;
- dashboards acionáveis e drill-down;
- relatórios CRM/atendimento/IA reconciliados;
- settings pesquisáveis;
- permissões e dependências visíveis;
- onboarding por checklist;
- testes de canal, CAPITÃO e pipeline;
- estados vazios educativos.

O dashboard não deve mascarar ausência de dados. Indicadores sem denominador, período, timezone ou definição não são aprovados.

### 15.9 Gate de saída por fatia

Uma fatia só recebe status verificado quando:

- critérios funcionais e não funcionais estão cobertos;
- unit/component/request/contract passam;
- E2E principal, alternativo e de permissão passa;
- screenshots nas cinco larguras e ambos os temas foram revisadas;
- teclado/axe/manual aplicável foi executado;
- nenhuma regressão de budget sem ADR;
- telemetria aparece no ambiente de validação;
- UAT da persona alvo foi aceita;
- feature flag e rollback foram testados;
- documentação e i18n foram atualizados;
- não há P0/P1 aberto.

### 15.10 Gate consolidado da Fase 3

Para declarar a **Fase 3 completa**, F3-EN e todas as fatias F3A–F3F devem estar verificadas. Uma release intermediária pode promover apenas uma fatia, mas seu status será “fatia F3x concluída”, nunca “Fase 3 concluída”.

O gate consolidado exige:

- matriz de dependências sem consumidor apontando para contrato provisório;
- jornada E2E-P0-00 completa atravessando as fatias;
- UAT por todas as personas primárias;
- métricas de tarefa comparadas à baseline;
- fallback antigo preservado pela janela de segurança;
- F2B-RC aprovado; a Fase 3 não pode ser declarada completa com cascata legada ativa;
- aprovação Product Owner + Tech Lead + Design Lead + QA Owner.

---

## 16. Fase 4 — CAPITÃO, identidade, score, memória e handoff

**Objetivo:** tornar a IA inteligente, explicável, segura e operacionalmente controlável sem reescrever o atendimento que já funciona.

**Dependências:** contratos de tenant/IDs, taxonomia F1, fundação F3-EN e harness de avaliação. CAP-00/CAP-01 podem avançar em paralelo à fundação visual; CAP-02+ dependem de F3-EN.

**Estimativa relativa:** 8 a 14 semanas, com rollout independente por capability.

### 16.1 Decisões arquiteturais obrigatórias

1. Core Rails é a fonte de verdade para conversa, contato, relacionamento, deal, score persistido, memória operacional e handoff.
2. Orchestrator é provedor interno de inferência e skills, não um segundo sistema de registro.
3. O Orchestrator não responde diretamente ao cliente nem altera estado comercial fora do contrato do Core.
4. Respostas passam pelo pipeline protegido do `ResponseBuilderJob`, com supressão após takeover.
5. `crm_lead_scores` guarda snapshots canônicos; `CaptainConversationState` é projeção operacional.
6. Score não decide se alguém é cliente e não causa handoff diretamente.
7. Jurídico/previdenciário é pacote vertical versionado e configurável.
8. CAPITÃO se identifica visual e textualmente como IA; uma persona não deve se passar por profissional humano real.
9. Configuração só aparece publicada quando teste de contrato comprova o efeito real.
10. Toda mudança automática é versionada, idempotente, auditada e reversível.

### 16.2 CAP-00 — Baseline e mapa de efeitos

- inventariar listeners, jobs, tools, flows e serviços que podem responder, pontuar, mover deal, alterar lifecycle ou fazer handoff;
- criar matriz `configuração → consumidor → efeito → teste`;
- registrar os quatro algoritmos e thresholds 60/75/80/90;
- capturar traces anonimizados de texto, mídia, score, tool e handoff;
- ADR formalizando Core como fonte de verdade;
- desligar efeitos concorrentes que possam produzir resposta duplicada.

**Gate:** nenhuma configuração ou efeito colateral sem dono, contrato e teste conhecido.

### 16.3 CAP-01 — Segurança e tenancy da IA

- autenticação de serviço curta e rotacionável para `/agent`, `/skills` e `/knowledge`;
- HMAC ou JWT com timestamp, nonce e proteção contra replay;
- `account_id` derivado da credencial, nunca confiado do body;
- artigo, coleção, memória, skill run e prompt sempre escopados;
- Orchestrator sem porta pública direta em produção;
- assistant, deal, flow, contact e conversation resolvidos pela conta corrente;
- PII redigida de logs, traces e skill runs;
- retenção/criptografia para memória e payload;
- testes de prompt injection, documento malicioso, tool injection, SSRF e exfiltração;
- autorização específica antes de ferramenta com efeito externo.

**Gate:** isolamento por conta de 100%, zero segredo em URL/log e zero tool call não autorizada.

### 16.4 CAP-02 — Classificação assistida de identidade e lifecycle

Esta onda consome o contrato F3-EN. Ela adiciona regras/IA, corrige dados e governa atuação do CAPITÃO; não redefine o schema durante o rollout.

Evidências fortes para cliente:

- deal ganho;
- contrato, faturamento ou serviço confirmado;
- integração autoritativa;
- promoção humana com motivo e autor.

Agenda do WhatsApp é apenas sinal de identidade conhecida. A migração deve:

1. gerar dry-run e relatório;
2. revisar os 12 clientes atuais, pois a base não possui deals ganhos;
3. preservar overrides legítimos;
4. corrigir registros cuja evidência seja inadequada;
5. registrar antes/depois e fonte;
6. corrigir precedência de `ex_customer`;
7. remover bloqueio global da IA para todo cliente;
8. decidir atuação por intenção, canal, regra e controle humano.

Todo estado armazena fonte, autor, timestamp, confiança, evidência, validade e override.

**Gate:** 100% dos clientes da fixture possuem evidência; nenhuma promoção por agenda; ex-cliente alcançável; casos conflitantes não disparam automação destrutiva.

### 16.5 CAP-03 — Score V2 explicável

Contrato mínimo:

| Campo | Finalidade |
|---|---|
| `qualification_score` | potencial comercial 0–100 |
| `data_completeness` | suficiência dos dados |
| `confidence` | confiança da avaliação |
| `classification` | bucket da política |
| fatores positivos/negativos/ausentes | explicação e próxima coleta |
| `evidence_refs` | origem verificável |
| `schema_version/policy_key/policy_version` | reprodução e auditoria |
| `input_fingerprint` | idempotência |
| timestamps/expiração | recência |

Regras:

- urgência não aumenta artificialmente conversão;
- prioridade operacional usa envelope separado por conversa/SLA, conforme seções 6.5 e 7.3;
- ausência vira “não avaliado/baixa confiança”, não zero;
- atributo sensível não entra em score comercial opaco;
- idade só pode existir em cálculo técnico vertical devidamente justificado;
- flows produzem sinais tipados, não um segundo total;
- thresholds vivem em uma configuração canônica;
- override preserva o valor calculado e registra motivo;
- auto-move começa desligado; handoff não é consumidor do score.

Rollout:

1. schema aditivo;
2. score v2 em shadow;
3. comparação offline e humana;
4. exibição supervisionada;
5. recomendação sem efeito;
6. automações de baixo risco por conta/pipeline;
7. movimentação apenas após gate próprio.

Modelo preditivo só deve ser avaliado depois de, no mínimo, 500 deals encerrados, 100 ganhos, 100 perdidos, 90 dias e validação temporal. Antes disso, usar qualificação determinística/explicável.

**Gate para exibição supervisionada:** todas as condições, não apenas uma:

- pelo menos 500 conversas avaliadas **e** 30 dias consecutivos em shadow;
- representação de todas as intenções/canais do escopo piloto;
- 100% dos resultados com schema, versão, evidência e explicação;
- mesma entrada/fingerprint produz o mesmo resultado em 100% das regras determinísticas;
- concordância ≥ 90% com bucket/próxima ação da rubric adjudicada;
- zero divergência crítica de segurança, tenant ou lifecycle;
- p95 do cálculo ≤ 250 ms;
- nenhum efeito automático durante a coleta;
- aprovação AI Owner + Product Owner + QA Owner.

Se o tráfego não atingir a amostra, o dataset offline pode liberar desenvolvimento e UX, mas não libera automação em produção.

**Gate adicional para auto-move:** somente após os mínimos de outcomes acima e validação temporal. Metas iniciais: Brier pelo menos 10% melhor que o baseline de taxa-base, lift do top 20% ≥ 1,5, erro de calibração absoluto ≤ 0,10, override no piloto ≤ 10%, nenhuma disparidade inexplicada > 10 pontos percentuais entre segmentos permitidos e zero P0/P1. Relaxar uma meta exige ADR de AI Owner, Produto, QA e Privacidade. Score nunca executa auto-handoff.

### 16.6 CAP-04 — Memória única e controlada

Memória canônica no Core:

- sessão atual;
- resumo incremental com marcador da última mensagem coberta;
- fatos duráveis confirmados;
- dados canônicos do CRM;
- ações/falhas operacionais;
- preferências consentidas.

Precedência:

`CRM confirmado > operador confirmado > declaração explícita do cliente > extração automática > inferência`

Cada fato inclui origem, confiança, confirmação, sensibilidade, validade, expiração e versão. Inferência não sobrescreve dado confirmado. Notas privadas nunca entram na resposta ao cliente. Contexto usa janela recente + resumo, com orçamento de tokens e redaction.

A memória do Orchestrator deve ser cache descartável escopado ou removida; não pode manter uma verdade paralela.

**Gate:** precisão factual mínima definida no dataset, zero exposição de nota privada e exportação/exclusão/retenção LGPD aprovadas.

### 16.7 CAP-05 — RAG unificado

- usar documentos/FAQs do CAPITÃO no Core como catálogo canônico;
- retirar conteúdo hardcoded do caminho produtivo;
- ingestão versionada de URL, PDF, FAQ e material interno;
- hash, versão, idioma, validade, escopo e aprovador;
- conteúdo gerado nasce pending;
- revisar as respostas atualmente aprovadas antes do cutover;
- busca híbrida lexical/vetorial, threshold e reranking;
- registrar chunks e versões consultados;
- perguntar, declarar incerteza ou transferir quando não houver evidência;
- documento recuperado nunca substitui system prompt/guardrails;
- teste de isolamento por conta.

Dataset inicial: pelo menos 200 perguntas respondíveis, ambíguas, sem resposta, desatualizadas e adversariais.

Metas propostas para piloto:

- Recall@5 ≥ 90%;
- precisão de fonte ≥ 95%;
- abstention correto ≥ 95%;
- afirmação factual sem suporte ≤ 1%;
- isolamento por conta = 100%;
- recuperação p95 ≤ 500 ms.

As metas serão recalibradas com baseline; redução exige ADR.

### 16.8 CAP-06 — Handoff como máquina de estados

Centralizar origens em `HandoffPolicy` e um comando idempotente. Motivos:

- pedido explícito de humano;
- humano assumiu;
- risco/urgência;
- baixa confiança;
- ausência de conhecimento;
- repetição;
- falha de mídia/provedor/tool;
- política da inbox;
- ação manual;
- regra do flow.

O comando deve:

1. validar conta e política;
2. alterar estado com lock;
3. cancelar ou suprimir resposta pendente;
4. executar handoff do bot;
5. atribuir time/agente;
6. aplicar prioridade/SLA;
7. gerar resumo privado seguro;
8. criar evento de timeline;
9. registrar regra, versão, origem e ator.

Pedido “quero falar com um atendente” não depende de mencionar “IA”. Retomada usa campos estruturados, não magic string.

**Gates:** 100% dos pedidos explícitos reconhecidos; zero mensagem após takeover; zero handoff duplicado; p95 até fila humana ≤ 2 s; resumo correto em pelo menos 95% do dataset; corrida IA × humano repetidamente aprovada.

### 16.9 CAP-07 — UX, playground e configuração

Na Inbox:

- badge persistente “CAPITÃO · IA”;
- timeline de ativação, handoff, takeover e retomada;
- pausar, assumir e retomar em um clique;
- score separado de prioridade;
- confiança, versão, fatores e dados ausentes;
- evidência de lead/cliente;
- fontes e próxima ação.

Na administração:

- assistente por página;
- toggle real por inbox/canal;
- horário, persona e disclosure;
- handoff, memória permitida e conhecimento;
- modelo, custo e ferramentas;
- histórico de versões, publicação e rollback.

O playground usa o pipeline de produção, porém isolado: não cria contato, deal, mensagem real, score persistente ou handoff. Exibe trace, fontes, score, confiança e regra.

### 16.10 CAP-08 — Observabilidade e avaliação

Eventos mínimos:

- `captain.response_requested`;
- `captain.context_built`;
- `captain.retrieval_completed`;
- `captain.response_generated`;
- `captain.response_suppressed`;
- `captain.response_sent`;
- `captain.handoff_requested`;
- `captain.handoff_completed`;
- `captain.human_takeover`;
- `captain.resumed`;
- `crm.score_calculated`;
- `crm.lifecycle_changed`.

Trace comum deve ligar webhook, Sidekiq, Core, Orchestrator, LLM, RAG e handoff, com versões e sem conteúdo pessoal bruto.

Datasets versionados:

| Dataset | Cobertura inicial |
|---|---|
| `identity_gold_v1` | 200 contatos |
| `triage_gold_v1` | 300 conversas |
| `score_rules_gold_v1` | cenários determinísticos/invariantes |
| `rag_gold_v1` | 200 perguntas |
| `handoff_gold_v1` | 150 conversas |
| `memory_multiturn_v1` | 100 conversas longas |
| `safety_red_team_v1` | injection, PII, impersonação e tenant |
| `production_replay_v1` | amostra anonimizada de regressão |

Dois revisores rotulam identidade, triagem e handoff; divergências são adjudicadas e concordância alvo ≥ 0,80.

Metas mínimas antes de produção ampliada:

- pedido explícito de humano: recall 100%;
- precisão de `customer` ≥ 98%;
- macro-F1 de lead/cliente/ex-cliente/desconhecido ≥ 90%;
- 100% dos scores com explicação e versão;
- zero efeito de tool alegado sem confirmação;
- zero vazamento cross-tenant/PII;
- qualidade humana média ≥ 4/5;
- nenhum erro crítico factual ou de segurança.

### 16.11 Flags e gate de saída da Fase 4

Flags independentes:

- `captain_identity_v2`;
- `crm_scoring_v2`;
- `captain_memory_v2`;
- `captain_rag_v2`;
- `captain_handoff_v2`;
- `captain_observability_v2`.

Gate:

- Core é a única fonte comercial;
- todos os endpoints internos são autenticados e tenant-safe;
- cliente/lead/lifecycle possui evidência e override;
- score é reproduzível, versionado e shadow-tested;
- UI e runtime consomem a mesma configuração;
- memória/RAG não têm verdade paralela;
- takeover silencia a IA;
- playground não produz efeitos;
- sandbox de provedor/mídia/tool/handoff passa;
- métricas do AI Center derivam de eventos/atores, não apenas do estado final;
- kill switch por inbox foi ensaiado.

---

## 17. Fase 5 — Funcionalidades de maior impacto

**Objetivo:** adicionar valor apenas depois de estabilizar a experiência e os contratos centrais.

**Dependências:** inventário “já existe/parcial/ausente”, telemetria e slices F3/F4 relevantes.

**Estimativa relativa:** 6 a 12 semanas para o primeiro conjunto, conforme priorização.

Limite de escopo: a F3 preserva e moderniza o mínimo operacional existente; a F5 só adiciona a camada avançada cuja lacuna e impacto forem comprovados. Se o inventário demonstrar que a capacidade já foi entregue na F3, o candidato é removido ou redefinido antes de estimar.

### 17.1 Critério de priorização

Pontuar cada candidato em:

- impacto em tempo, conversão, SLA ou qualidade;
- frequência e alcance de usuários;
- alinhamento estratégico;
- confiança da evidência;
- esforço;
- risco técnico, regulatório e operacional;
- dependências;
- capacidade de medir e reverter.

Usar RICE ou WSJF, mas publicar os dados e não tratar a fórmula como decisão automática.

### 17.2 Ordem inicial recomendada

| Prioridade | Capacidade | Por quê |
|---:|---|---|
| 1 | próxima melhor ação, escalada e lembrete inteligente | amplia a próxima ação manual entregue na F3 |
| 2 | follow-up avançado acionado por rotting | transforma o sinal F3 em cadência controlada |
| 3 | preferências, digest e roteamento de notificações | amplia o agrupamento visual F3 |
| 4 | matching de duplicidade e fila de revisão | amplia o alerta/merge manual F3 |
| 5 | builder de campos customizados de deal | torna o núcleo horizontal configurável |
| 6 | webhooks documentados/idempotentes | amplia integração com segurança |
| 7 | builder visual de automações | amplia as automações existentes preservadas na F3 |
| 8 | agendamento de mensagens | valor operacional com risco de canal/compliance |
| 9 | menções e colaboração contextual | reduz coordenação fora do sistema |
| 10 | forecast por cenários | somente após histórico e qualidade de dados suficientes |

### 17.3 Template obrigatório de feature

Cada feature deve documentar:

- usuário e problema;
- comportamento atual e hipótese;
- métrica de sucesso e guardrail;
- já existe/parcial/ausente;
- fluxo e estados;
- modelo de dados e eventos;
- permissões/tenant;
- dependências externas;
- feature flag;
- testes;
- observabilidade;
- rollback;
- resultado pós-piloto.

### 17.4 Gate de saída da Fase 5

- nenhum item duplica capacidade existente;
- hipótese e métrica foram registradas antes;
- feature passou pelo gate de fatia vertical;
- adoção/resultado do piloto é comparado à baseline;
- impacto negativo ou uso insuficiente gera ajuste ou remoção;
- documentação e APIs estão publicadas;
- dívida criada possui owner e prazo;
- backlog remanescente foi reordenado com evidência real.

---

## 18. Fase 6 — Regressão total, hardening e aceite

**Objetivo:** provar que a reformulação preserva e melhora o produto completo.

**Dependências:** todas as capacidades que entrarão na release candidate.

**Estimativa relativa:** 3 a 5 semanas, além da QA contínua de cada fase.

### 18.1 Escopo obrigatório

- matriz integral de `AUDITORIA-FUNCIONAL.md`;
- todas as famílias do inventário de rotas;
- browsers, viewports, temas e personas suportados;
- teclado, leitor de tela, zoom e reduced motion;
- Evolution, Google, LLM, SMTP, Sidekiq e ActionCable;
- 201/1.000 deals, 100 mil contatos simulados e histórico longo;
- cross-tenant, RBAC, upload, webhook e OAuth;
- migrations, backup, restauração e rollback;
- performance, soak, filas e realtime;
- datasets/evals do CAPITÃO;
- UAT e smoke pós-deploy.

### 18.2 Entregáveis

- `QA-FINAL.md`;
- matriz requisito → teste → execução → evidência;
- relatório de acessibilidade;
- relatório de performance/capacidade;
- relatório de segurança sanitizado;
- reconciliação de dados;
- plano e ensaio de rollback;
- bugs conhecidos com severidade, owner e aceite;
- sign-offs de Produto, Engenharia, Design, QA, IA, Segurança/Privacidade e Operações.

### 18.3 Gate de GA

- zero P0/P1 aberto;
- P2 restante explicitamente aceito com owner e prazo;
- dois ciclos P0 completos e consecutivos sem falha;
- nenhuma família de tela sem evidência;
- zero vazamento entre contas;
- zero violação axe crítica/séria;
- P0 aprovado manualmente com leitor de tela aplicável;
- responsividade e temas completos;
- nenhuma cascata ChusteRM duplicada ativa; todo legado restante possui owner, justificativa e remoção agendada;
- budgets e SLOs dentro da faixa;
- sandbox das integrações aprovado;
- restore e rollback ensaiados;
- nenhum teste P0 flaky ignorado/quarentenado;
- UAT de primeiro uso atende à taxa, amostra e critérios da seção 19.1;
- `QA-FINAL.md` referencia commit, imagens, migrations, ambiente e artefatos.

---

## 19. Estratégia transversal de qualidade

### 19.1 Princípios

- Regressão zero é demonstrada por execução, não por presença de código ou spec.
- Cada requisito mantém a cadeia `requisito → risco → teste → execução → evidência → decisão`.
- Baseline vermelha pode existir na Fase 0 quando reproduzida, priorizada e atribuída; não pode ser escondida.
- Cobertura de código não substitui cenário.
- No legado, congelar baseline e exigir cobertura de diff; não impor meta global que incentive testes vazios.
- Testes não usam produção nem disparam mensagens/carga real sem autorização.
- E2E deve ser pequeno e determinístico nos P0; maior volume fica em unit/component/request/contract.
- Teste flaky de P0 é defeito bloqueante, não sucesso intermitente.

#### Rubrica de severidade

| Nível | Definição | Exemplos | Efeito |
|---|---|---|---|
| P0 — crítico | segurança, perda/corrupção, operação indisponível ou dano sem contenção | cross-tenant, mensagem perdida, IA pós-takeover, migration destrutiva | interromper rollout e corrigir imediatamente |
| P1 — alto | jornada crítica quebrada sem workaround seguro | não responder, não criar/mover/fechar deal, auth/RBAC incorreto | bloqueia gate/release |
| P2 — médio | função relevante degradada com workaround aceitável | filtro inconsistente, layout que dificulta mas não impede | owner e prazo; aceite explícito |
| P3 — baixo | acabamento ou melhoria sem impacto material | copy, alinhamento, refinamento não bloqueante | backlog priorizado |

Se houver dúvida entre dois níveis, usar o mais alto até triagem conjunta de QA + Produto + Tech.

#### Denominadores de cobertura

- “Todas as famílias de tela” significa 100% do manifesto versionado gerado do inventário de rotas, acrescido de drawers, modais, abas, ChannelFactory, widget, auth e superfícies Enterprise aplicáveis.
- “Personas aplicáveis” significa a matriz rota/ação × papel aprovada em `docs/qa/MATRIZ-COBERTURA.md`.
- “Isolamento 100%” significa que 100% das fronteiras tenant-bearing inventariadas — endpoints, queries sensíveis, associações, jobs, websockets, exports, anexos, memória e tools — possuem teste negativo Conta A/B e revisão do escopo. É um gate de cobertura auditável, não alegação de prova matemática.
- Qualquer item novo entra no manifesto no mesmo PR; caso contrário, o gate falha.

#### Critério de primeiro uso

Na F1, obter baseline; na F6, testar ao menos cinco participantes de primeiro uso por persona primária (operador, vendedor e administrador), sem ajuda do moderador:

- sucesso ≥ 90% nas tarefas P0 atribuídas;
- zero erro crítico;
- mediana de tempo pelo menos 20% melhor que a baseline, ou não pior quando houver ganho documentado de segurança/qualidade;
- confiança percebida ≥ 4/5;
- todo ponto de intervenção vira defeito ou decisão explícita.

A amostra valida usabilidade inicial, não substitui telemetria pós-rollout.

### 19.2 Camadas e gates

| Camada | Escopo | Ferramentas indicadas | Gate |
|---|---|---|---|
| Estática | formatação incremental, tipos, rotas, i18n, CSS, segredos | RuboCop, ESLint, Stylelint, tsc, TruffleHog | nenhuma dívida nova; tocados limpos |
| Unitária | score, lifecycle, filtros, serviços, parsers, jobs | RSpec, Vitest, testes Node | todos os critérios novos e ramos críticos |
| Componente | primitives, forms, dialogs, Kanban, composer | Vue Test Utils, Vitest, axe | estados e interação acessível |
| Request/API | auth, tenant, paginação, erro, idempotência | RSpec request/service/job | contrato e autorização completos |
| Integração | Rails, DB, Redis, Sidekiq, ActionCable, Orchestrator | testes de integração e containers | fluxos assíncronos/realtime |
| Contrato | Evolution, LLM, Google, webhooks, OAuth | schemas/fixtures gravadas + sandbox | incompatibilidade bloqueia merge |
| E2E | jornadas P0/P1 por persona | Playwright | P0 em PR; matriz ampla na release |
| Visual | temas, viewports e estados | snapshots de imagem | mudança intencional aprovada |
| Acessibilidade | automação + uso real | axe, teclado, NVDA, VoiceOver | zero barreira crítica/séria |
| Performance | Web Vitals, APIs, board, filas | Lighthouse, traces, profiler, k6 | budgets aprovados |
| Segurança | código, dependência, DAST, tenant, IA | Brakeman, audit, ZAP/equiv., red team | zero critical/high explorável |
| IA | identidade, score, resposta, RAG, handoff | datasets versionados + revisão humana | metas da seção 16 |
| Migração/DR | expand/contract, backup, restore | cópia realista e drill | reversão/recovery comprovados |

Meta para código alterado: cobertura de linhas ≥ 80% e ramos críticos ≥ 90%, ajustável por justificativa. A aprovação continua dependente dos cenários.

### 19.3 Personas obrigatórias

| Persona | Permissões/risco | Jornadas mínimas |
|---|---|---|
| Administrador | configuração total | canais, equipe, pipeline, CAPITÃO, integrações |
| Operador/agente | conversas | receber, responder, nota, atribuir, resolver, handoff |
| Vendedor/CRM | contatos e CRM | contato, deal, atividade, Kanban, ganho/perda |
| Gestor | relatórios/gestão | filtros, forecast, exportação, reconciliação |
| Gestor de conhecimento | base e CAPITÃO | artigo, FAQ, documento, publicação |
| Custom role mínima | permissão granular | menu, deep link, API e ausência de vazamento |
| Usuário sem conta | exceção | orientação/logout, zero acesso residual |
| Conta suspensa | exceção | bloqueio consistente e recuperação prevista |
| Super-admin | superfície separada | contas, configuração e auditoria |
| Visitante/cliente | auth/widget/portal | login/reset, widget, anexo e help center |

### 19.4 Browsers, viewports e condições

Browsers:

- Chrome estável e anterior;
- Edge estável;
- Firefox estável e ESR quando exigido por cliente corporativo;
- WebKit no CI;
- Safari atual e anterior em macOS, e iOS Safari real na release.

WebKit em Windows não substitui Safari físico.

| Perfil | Viewport | Foco |
|---|---:|---|
| celular compacto | 360 × 800 | toque, composer, drawers, Kanban |
| tablet retrato | 768 × 1024 | navegação e tabelas/cards |
| notebook pequeno | 1024 × 768 | transição de breakpoints |
| notebook | 1366 × 768 | operação cotidiana |
| desktop | 1920 × 1080 | densidade e três colunas |

Condições adicionais:

- reflow a 320 px;
- zoom 200%;
- textos PT-BR longos;
- light e dark;
- `prefers-reduced-motion`;
- alto contraste quando suportado;
- portrait/landscape móvel;
- cold/warm cache;
- rede/CPU reduzidas nos fluxos críticos.

### 19.5 Matriz de execução

**A cada PR**

- unit/component/request afetados;
- lint/type/build incremental;
- Chromium 1366/admin;
- Chromium 360/agente;
- Firefox 1366/custom role;
- P0 afetado;
- axe e snapshot dos componentes tocados;
- scans rápidos de segurança.

**Nightly**

- cinco larguras em Chromium;
- P0 em Firefox e WebKit;
- light/dark;
- fixture com 201+ deals;
- integrações simuladas/contratuais;
- datasets rápidos do CAPITÃO;
- auditoria de dependências.

**Release candidate**

- browsers suportados;
- cinco viewports e condições adicionais;
- personas aplicáveis;
- Safari/iOS reais;
- sandboxes externas;
- 1.000 deals e datasets amplos;
- a11y manual;
- DAST, performance, soak, restore e rollback.

### 19.6 Catálogo E2E crítico

| ID | Severidade | Jornada preservada do inventário | Resultado obrigatório |
|---|---|---|---|
| E2E-P0-00 | P0 | composição ponta a ponta deste plano | cadeia inteira correta, auditada e reconciliada |
| E2E-AUTH-01 | P0 | login, troca e URL de outra conta | sessão correta e tenant protegido |
| E2E-CHAN-01 | P0 | criar/conectar Inbox Evolution | inbox/instância únicas, webhook e segredo seguros |
| E2E-INBOX-01 | P0 | receber texto externo e abrir conversa | um contato, conversa e mensagem; realtime |
| E2E-INBOX-02 | P0 | atribuir, label, nota, responder, resolver/reabrir | persistência e eventos corretos |
| E2E-INBOX-03 | P0 | imagem, áudio, vídeo, documento e webhook repetido | anexos seguros e deduplicados |
| E2E-INBOX-04 | P1 | duas sessões concorrentes | ActionCable atualiza sem duplicar |
| E2E-CRM-01 | P0 | IDs interno/display divergentes | exatamente a conversa correta |
| E2E-CRM-02 | P0 | criar/reutilizar deal | nenhuma duplicação indevida |
| E2E-CRM-03 | P0 | mover etapa | persistência, regra única e realtime |
| E2E-CRM-04 | P0 | ganhar, reabrir e perder com motivo | estado, auditoria e métricas corretos |
| E2E-CRM-05 | P0 | drawer, mensagem e takeover | display ID correto e IA silenciosa |
| E2E-CRM-06 | P1 | filtros, seleção e exportação | meta/escopo e falhas parciais corretos |
| E2E-CRM-07 | P0 | localizar/mover o 201º deal | nenhum item invisível |
| E2E-CRM-08 | P1 | valores distribuídos nas etapas | cards e somas globais reconciliados |
| E2E-CRM-10 | P1 | Google autorizar/sincronizar/revogar | sem duplicidade e reconexão acionável |
| E2E-AI-01 | P0 | configurar, conhecer, playground e ativar | isolamento e persistência |
| E2E-AI-02 | P0 | debounce e concorrência de mensagens | uma resposta coerente |
| E2E-AI-03 | P0 | handoff, humano e retomada | transição auditada e silêncio da IA |
| E2E-AI-04 | P0 | mídia, erro transitório e fallback | contexto ou falha segura |
| E2E-REPORT-01 | P1 | relatórios com fixture conhecida | números, export e timezone reconciliados |

Os IDs e significados de `AUDITORIA-FUNCIONAL.md` permanecem canônicos até serem copiados literalmente para `docs/qa/MATRIZ-COBERTURA.md`; nenhum ID pode ser reaproveitado. E2E-P0-00 é um novo cenário composto que orquestra os casos existentes.

#### Especificação do E2E-P0-00

Pré-condição: fixture Conta A/B, inbox sandbox com CAPITÃO habilitado, duas sessões de operador, contato desconhecido, pipeline e valores conhecidos.

Passos e oráculos:

1. receber mensagem externa com idempotency key; surge uma única conversa na Conta A;
2. CAPITÃO responde identificado como IA, uma única vez, e registra trace/config/versões;
3. identidade fica provisional e `relationship_status=prospect`; agenda/telefone não produzem customer;
4. triagem cria ou reutiliza exatamente um deal ligado à conversa pelo `database_id` correto;
5. score explicável aparece sem mover automaticamente o deal;
6. cliente pede humano; handoff ocorre uma vez, com motivo, resumo e destino;
7. segunda sessão recebe realtime e assume; toda resposta pendente da IA é suprimida;
8. humano responde pelo workspace/drawer e registra próxima ação;
9. deal move pelo Kanban, persistindo histórico, valor e somas;
10. no ciclo A, concluir won; no ciclo B, concluir lost com motivo e reabertura;
11. relatórios, timeline, exportação e eventos reconciliam com banco/API;
12. tentativa equivalente da Conta B não lê nem altera qualquer entidade da Conta A.

Evidência mínima: trace Playwright, screenshots dos marcos, IDs técnico/display, eventos correlacionados, consultas de reconciliação e axe. O teste roda duas vezes com limpeza idempotente; uma execução termina won e a outra lost.

### 19.7 Casos obrigatórios de lifecycle e score

| ID | Entrada | Resultado |
|---|---|---|
| AI-LIFE-01 | telefone salvo, sem contratação | `relationship_status=prospect`; nunca customer |
| AI-LIFE-02 | deal ganho/contrato comprovado | `relationship_status=customer` + evidência/timestamp |
| AI-LIFE-03 | cliente anterior sem vínculo ativo | `relationship_status=former_customer`; alias v1 `ex_customer` só no serializer |
| AI-LIFE-04 | evidências conflitantes/duplicidade | estado anterior preservado + `requires_review=true` |
| AI-SCORE-01 | mesmas evidências | `qualification_score/classification/fingerprint/version` idênticos |
| AI-SCORE-02 | intenção alta e suporte frustrado | prioridade não contamina potencial |
| AI-SCORE-03 | regra de handoff configurada | runtime usa configuração, não limite oculto |
| AI-SCORE-04 | evidência atualizada | um recálculo, delta explicado e versionado |

### 19.8 Acessibilidade — WCAG 2.2 AA

Escopo: dashboard, autenticação, widget e help center.

- axe por componente e família crítica; zero critical/serious;
- teclado completo em sidebar, command palette, filtros, composer, dialogs, tabs, tabela e Kanban;
- Kanban com alternativa sem drag e comandos Enter/Espaço/Escape;
- dialogs com nome, descrição, foco inicial, trap, Escape e retorno de foco;
- primitive único para confirmação, evitando `confirm()` nativo disperso;
- NVDA + Chrome/Firefox no Windows;
- VoiceOver + Safari em macOS/iOS nos P0;
- headings, landmarks, labels e live regions adequados;
- contraste AA em estados e temas;
- cor nunca como único sinal;
- zoom 200%, reflow 320 px e texto ampliado;
- hit area ≥ 44 × 44 CSS px;
- reduced motion;
- checklist manual por jornada e evidência ligada ao critério WCAG.

Exceção exige alternativa equivalente, justificativa, owner e expiração.

### 19.9 Estrutura de evidências

- `docs/qa/MATRIZ-COBERTURA.md`: requisito, rota, persona, viewport, cenário e resultado;
- `docs/qa/evidencias/<release>/<cenario>/<browser>/`: trace, screenshot, axe, vídeo em falha e HAR sanitizado;
- `docs/qa/performance/<release>/`: baseline, profiling, Lighthouse/k6 e comparação;
- `docs/qa/security/<release>/`: threat model, scans sanitizados e retestes;
- `QA-FINAL.md`: versão, ambiente, migrations, dados, gates, bugs, budgets, backup, rollback e sign-offs.

Artefatos devem seguir retenção de auditoria/LGPD e nunca incluir token, telefone completo, conteúdo privado ou credencial.

---

## 20. Requisitos não funcionais, performance e capacidade

### 20.1 Orçamentos iniciais

Os números abaixo são metas iniciais. A Fase 0 mede a baseline; um ajuste mais permissivo exige ADR, risco, owner e prazo.

| SLI | Meta inicial |
|---|---|
| feedback de clique/drag | ≤ 100 ms percebido |
| Core Web Vitals p75 | LCP ≤ 2,5 s; INP ≤ 200 ms; CLS ≤ 0,10 |
| API crítica interna | p50 ≤ 200 ms; p95 ≤ 500 ms; p99 ≤ 1,5 s; erro < 1% |
| escrita complexa | p95 ≤ 800 ms, salvo operação assíncrona explícita |
| query DB | p95 ≤ 100 ms; nenhuma > 1 s no P0 normal |
| mensagem persistida → visível | p95 ≤ 3 s |
| commit → ActionCable | p95 ≤ 1 s |
| handoff/pausa refletido | p95 ≤ 2 s |
| score heurístico | p95 ≤ 250 ms; visível ≤ 2 s |
| CAPITÃO request → resposta completa visível | texto p95 ≤ 15 s; medir provedor separadamente |
| CAPITÃO mídia/timeout controlado | p95 ≤ 30 s com progresso e fallback |
| fila crítica | espera p95 ≤ 5 s; dead jobs P0 = 0 |
| fila normal | espera p95 ≤ 60 s |
| Kanban 1.000 deals | conteúdo ≤ 2,5 s; filtro ≤ 500 ms; drag p95 ≤ 1 s |
| long task no Kanban | nenhuma > 200 ms no cenário normal |
| realtime entre sessões | p95 ≤ 2 s, sem duplicidade |
| bundle JavaScript por entrypoint | crescimento ≤ 5% por PR sem budget/ADR |
| CSS autoral ChusteRM | crescimento líquido ≤ 0%; `!important`, hardcodes e especificidade nunca aumentam |

O runtime atual entrega resposta não-streaming; portanto TTFT não é SLI observável. Se streaming for implementado, ele entra como fatia própria com instrumentação e budget antes de substituir a métrica request → resposta completa.

### 20.2 Hipóteses de capacidade a validar

- 50 operadores simultâneos por conta;
- 2× o pico de referência com erro < 1%;
- CPU < 70% e memória < 80% sustentadas no cenário-alvo;
- 100 mil contatos por conta;
- 1 milhão de mensagens históricas;
- 10 mil deals por conta;
- 1.000 cards acessíveis no recorte de board;
- conversas longas e anexos variados;
- gráficos, exportações e realtime simultâneos.

Estas são hipóteses de planejamento, não limites comprovados. Produto/Operações devem confirmar o perfil real de clientes.

### 20.3 Método de medição

- ambiente reproduzível sem watcher de build;
- RUM/APM no frontend/backend;
- New Relic/Sentry/OpenTelemetry já existentes antes de adicionar outra plataforma;
- Playwright trace e profiler Vue/Rails;
- slow query, EXPLAIN e pool/lock;
- k6 ou equivalente apenas em staging aprovado;
- cold/warm cache, mobile CPU e rede lenta;
- separar latência ChusteRM, Evolution, Google e LLM;
- soak de 2 h em fases críticas e 24–72 h antes de GA;
- nunca executar carga em produção sem autorização explícita.

---

## 21. Segurança, privacidade e confiabilidade

### 21.1 Gates de segurança

1. **Tenant como invariante:** query, FK, job, websocket, export, anexo, memória e tool sempre escopados.
2. **RBAC:** ocultar UI não substitui autorização da API.
3. **Entrada:** schema/allowlist, limite, paginação, parametrização, sanitização, CSV injection, SSRF e upload seguro.
4. **Sessão/web:** CSRF, cookies seguros, CORS allowlist, CSP/headers, rate limit e erros sem stack/segredo.
5. **Webhook/OAuth:** assinatura, replay window, idempotência, rotação e redirect allowlist.
6. **IA:** minimização de PII, tool authorization, injection/red team, isolamento de memória e confirmação para efeito externo.
7. **LGPD:** inventário, finalidade, consentimento aplicável, retenção, exportação, correção, exclusão e legal hold.
8. **Supply chain:** lockfiles, SAST, auditorias, scanner de imagem, SBOM e segredos.
9. **DAST/pentest:** staging autenticado e não autenticado; pentest antes de GA ou mudança grande de auth/IA.
10. **Recovery:** backup antes de migration, restore drill e expand/contract.

Release não aceita vulnerabilidade critical/high explorável. Medium precisa de owner, prazo e mitigação.

### 21.2 Regras específicas de dados e IA

- nenhum log com token, cookie, telefone completo ou conteúdo bruto desnecessário;
- account pseudonimizada em telemetria analítica;
- payload ao LLM com minimização/redaction;
- retenção configurável por tipo de memória;
- fonte e consentimento para fatos duráveis;
- exclusão/exportação propagada a embeddings e caches;
- prompt/documento não autoriza tool;
- ferramenta com efeito exige policy no Core;
- resposta não pode alegar sucesso antes da confirmação do sistema externo.

### 21.3 Continuidade

- ingestion e envio idempotentes;
- webhook duplicado/fora de ordem testado;
- retry com backoff/jitter e dead-letter observável;
- reconexão de Redis/ActionCable;
- Evolution offline e token OAuth expirado com recuperação;
- LLM timeout/429 com fallback seguro;
- deploy compatível com versão anterior durante rollout;
- nenhum caminho deve perder silenciosamente mensagem, deal ou atividade.

---

## 22. Observabilidade e SLOs

### 22.1 Correlação

Propagar `request_id/trace_id`:

`webhook → Core → Sidekiq → Evolution/Orchestrator/LLM → resposta/handoff`

Registrar IDs técnicos permitidos, versões, duração, estado e erro; não registrar dados pessoais brutos.

### 22.2 Métricas

| Área | Métricas mínimas |
|---|---|
| Core/API | throughput, p50/p95/p99, 4xx/5xx, slow query, pool, locks |
| Sidekiq | depth, age, retry/dead, duração/falha por job |
| Postgres/Redis | conexões, memória, cache, backup/replicação |
| ActionCable | conexões, reconexão, lag, duplicidade |
| Evolution | instância, webhook inválido/duplicado, envio/entrega/falha |
| CAPITÃO | modelo/prompt/config, tokens/custo, timeout, erro, handoff, override |
| CRM | criação, movimento, won/lost, automação, score/lifecycle, reconciliação |
| Frontend | Web Vitals, erro JS, route latency, falha API, flag/versão |

### 22.3 SLOs iniciais

| Serviço/jornada | SLO mensal |
|---|---|
| Core autenticado e health | 99,9% disponível |
| mensagem válida ingerida | 99,5% visível em até 5 s |
| comando CRM persistido | 99,9% sem perda/duplicidade |
| handoff explícito | 99,9% aplicado em até 2 s |
| isolamento entre contas | 100%, sem error budget |

Para 99,9%, o budget mensal aproximado é 43 min 49 s. Pausar rollout quando 50% do budget for consumido ou houver degradação sustentada.

### 22.4 Alertas e runbooks

Alerta precisa conter sintoma, impacto, dashboard, owner e runbook. Alertas imediatos:

- vazamento ou tentativa cross-tenant anômala;
- mensagem da IA após takeover;
- mensagem/deal duplicado ou perdido;
- fila crítica acima do limite;
- erro/latência acima da baseline;
- falha de migration/backfill;
- custo/token ou handoff anormais;
- integração desconectada;
- backup ou restore inválido.

P0/P1 gera postmortem sem culpa, ação preventiva e teste de regressão.

---

## 23. Dados, migrations e compatibilidade

### 23.1 Padrão expand–migrate–contract

1. adicionar campo/tabela nullable e índice seguro;
2. publicar código compatível com estado antigo e novo;
3. dual-write quando necessário, com reconciliação;
4. executar backfill em lotes, com dry-run, checkpoint e throttling;
5. comparar contagens, checksums e invariantes;
6. habilitar leitura nova por flag;
7. observar e permitir fallback;
8. adicionar constraint depois que os dados estiverem íntegros;
9. retirar escrita antiga;
10. remover coluna/legado apenas em release posterior.

Regras:

- migration destrutiva nunca acompanha a ativação de contrato novo;
- backup verificado antes de qualquer mudança de alto risco;
- backfill não bloqueia tabela por período incompatível com o SLO;
- jobs antigos e novos devem coexistir durante rolling deploy;
- rollback de aplicação não pode depender de desfazer perda de dados;
- nenhum lote reclassifica pessoas em massa sem preview e trilha.

### 23.2 Migrações específicas previstas

| Domínio | Mudança provável | Proteção |
|---|---|---|
| Identidade/relacionamento | evidência, fonte, confiança, override e histórico | dry-run + revisão dos registros atuais |
| Score v2 | schema de dimensões, fatores, versões e fingerprint | shadow + dual-read |
| Handoff | estados, motivo, origem, actor e timestamps estruturados | compatibilidade com eventos legados |
| Memória | fatos versionados, sensibilidade e expiração | importação seletiva; cache descartável |
| RAG | documento/chunk/versão/status/tenant | reindexação observável |
| CRM | próxima ação, rotting, campos e eventos | nullable + backfill gradual |
| Observabilidade | event IDs e versões | sem payload pessoal bruto |

### 23.3 Reconciliação de dados

Para cada backfill:

- quantidade antes/depois;
- registros elegíveis, alterados, ignorados e falhos;
- amostra revisada;
- invariantes cross-tenant;
- soma financeira e moeda;
- duplicidades;
- duração e impacto;
- arquivo de resultado sanitizado;
- procedimento de correção/rollback lógico.

No lifecycle, revisar manualmente os clientes atuais sem evidência forte antes de aplicar qualquer correção.

### 23.4 Compatibilidade com Chatwoot e Enterprise

- mapear customizações por upstream version;
- pesquisar comportamento em `core/app` e `core/enterprise`;
- evitar fork de primitive/serviço quando extensão é suficiente;
- manter contratos públicos e migrations do upstream;
- registrar patch local e risco de merge;
- rodar suíte upstream afetada;
- testar installation types e feature flags;
- reservar janela periódica para rebase/upgrade controlado.

---

## 24. Estratégia de rollout e rollback

### 24.1 Estágios

1. desenvolvimento com fixture;
2. staging/homologação com dados anonimizados;
3. shadow mode sem efeitos;
4. equipe interna;
5. 1 a 5 contas piloto;
6. 10%;
7. 25%;
8. 50%;
9. 100%;
10. remoção do legado em release posterior.

Critérios mínimos iniciais — vale o que ocorrer por último entre tempo e amostra:

| Estágio | Janela/amostra mínima | Critério de saída | Aprovador |
|---|---|---|---|
| dev/staging | dois E2E-P0-00 limpos | gates técnicos da fatia | Tech + QA |
| shadow comum | 7 dias e 500 operações elegíveis | zero P0/P1; contrato e métricas íntegros | Tech + QA + owner da capability |
| shadow score/IA | critérios quantitativos da seção 16, incluindo 30 dias | datasets, segurança e qualidade aprovados | AI + Produto + QA + Privacidade |
| equipe interna | 3 dias úteis e 100 tarefas | sucesso P0 ≥ 90%; p95 ≤ 1,2× baseline | Produto + QA |
| 1–5 pilotos | 7 dias e 500 jornadas elegíveis | erro < 1%; zero P0/P1; SLO e guardrails | Produto + QA + Operações |
| 10%, 25% e 50% | 72 h e 1.000 operações por estágio | completion/CSAT não caem > 5 p.p.; p95 ≤ 1,2×; budget consumido < 50% | Produto + Tech + QA + Operações |
| 100% | 14 dias consecutivos | SLO, segurança, reconciliação e UAT sustentados | sign-off completo |

Para aplicar o guardrail de CSAT são necessárias pelo menos 30 respostas na coorte; abaixo disso, ampliar a janela e não declarar equivalência estatística. Falso handoff deve permanecer ≤ 3% no conjunto adjudicado. Amostra insuficiente impede avanço, não autoriza inferência otimista. Comparar coorte controle quando possível.

### 24.2 Flags e kill switches

Flags por conta e, quando necessário, por inbox/pipeline:

- shell/redesign por família;
- identidade v2;
- score v2;
- memória/RAG;
- handoff;
- automações;
- ferramentas com efeito externo.

Uma flag deve existir no backend/jobs, não apenas esconder UI. Kill switch precisa funcionar sem novo deploy.

### 24.3 Pré-deploy

- CI e `QA-FINAL` parcial verdes;
- backup íntegro e restore conhecido;
- migration dry-run em cópia semelhante;
- imagens por digest;
- flags desligadas;
- dashboards e alertas ativos;
- capacidade/on-call definidos;
- plano de comunicação e suporte;
- decisão go/no-go registrada.

### 24.4 Pós-deploy

- smoke P0;
- health, 5xx, latência, Web Vitals e filas;
- ingestão/entrega e duplicidade;
- reconciliação de deals/valores;
- handoff e mensagem após takeover;
- custo/erro do LLM;
- feedback do piloto;
- registro de versão e cohort.

### 24.5 Abortar ou reverter

Rollback imediato por flag e, se necessário, imagem anterior quando houver:

- qualquer vazamento cross-tenant;
- perda ou duplicação de mensagem/deal;
- resposta da IA após takeover;
- 5xx > 2% por 5 min;
- p95 > 2× baseline por 10 min;
- fila crítica acima de 5 min;
- migration incompatível;
- afirmação sem suporte acima do limite;
- queda de CSAT superior a 5 pontos percentuais com amostra mínima;
- falso handoff acima de 3% no conjunto adjudicado;
- consumo de 50% do error budget, que pausa a expansão;
- error budget esgotado, que exige rollback salvo incidente já contido e decisão formal.

Migration destrutiva não pode ser requisito para restaurar a versão anterior.

### 24.6 Janela de segurança e remoção do legado

- manter flags, imagem anterior e contratos de leitura por pelo menos 30 dias **e** dois ciclos de release estáveis após 100%;
- para score, memória, RAG, handoff e tools, manter fallback por pelo menos 60 dias;
- o CSS/markup antigo permanece em bundle isolado atrás da flag, sem afetar a superfície nova;
- overrides redundantes da implementação nova são removidos no próprio slice;
- o bundle/contrato antigo só é removido depois da janela, restore drill e sign-off Tech + QA + Operações;
- dados/colunas legados seguem expand–contract e podem exigir janela maior.

---

## 25. Métricas de produto e sucesso

### 25.1 North Star operacional

**Interações resolvidas com continuidade comprovada:** proporção de conversas que terminam com resolução confirmada ou próxima ação válida, sem reabertura evitável, perda de contexto ou descumprimento de SLA.

Essa métrica combina atendimento e CRM, mas deve ser decomposta para evitar que “resolver rápido” esconda problemas.

### 25.2 Atendimento

- tempo de primeira resposta humana/IA, separados;
- tempo até resolução;
- SLA cumprido;
- first contact resolution;
- reabertura em 24 h e 72 h;
- CSAT e taxa de resposta;
- backlog, espera e distribuição de carga;
- retrabalho e transferências.

### 25.3 CRM

- cobertura de próxima ação;
- atividades vencidas;
- tempo por etapa e rotting;
- conversão por etapa/origem/pipeline;
- ciclo de venda;
- valor ganho/perdido;
- forecast versus realizado;
- motivos de perda;
- duplicidade e completude dos dados.

### 25.4 CAPITÃO e score

- respostas geradas, enviadas e suprimidas;
- resolução atribuída por evento/ator;
- handoff por motivo e tempo até humano;
- reabertura após IA;
- pedido explícito reconhecido;
- groundedness e abstention;
- erro factual/crítico;
- override de identidade/score;
- cobertura, distribuição, estabilidade e calibração do score;
- latência, tokens e custo por resolução;
- falha de tool/provedor e duplicidade;
- mensagem pós-takeover, cuja meta é zero.

### 25.5 Experiência e adoção

- tempo até primeiro valor no onboarding;
- sucesso/tempo/interações das tarefas P0;
- uso de busca, command palette e views salvas;
- abandono e erro por formulário;
- tickets de suporte por fluxo;
- adoção por papel e conta;
- SUS ou métrica de usabilidade periódica;
- barreiras de acessibilidade abertas/fechadas.

### 25.6 Integridade da medição

Cada indicador deve possuir:

- nome e definição;
- numerador/denominador;
- evento/fonte;
- timezone e janela;
- dimensões permitidas;
- owner;
- qualidade/atraso conhecidos;
- dashboard e consulta de reconciliação;
- data de mudança de definição.

Não usar métricas do estado final do objeto quando o ator/evento é necessário, como “resolvida pela IA”.

---

## 26. Governança e responsabilidades

### 26.1 RACI mínimo

| Papel | Responsabilidade principal |
|---|---|
| Product Owner | prioridade, não objetivos, aceite e rollout |
| Tech Lead | arquitetura, ADR, migrations e rollback |
| Design Lead | pesquisa, IA, tokens, conteúdo e visual |
| QA Owner | matriz, fixtures, execução, triagem e `QA-FINAL.md` |
| AI Owner | datasets, rubric, prompt/modelo, score e drift |
| Segurança/Privacidade | threat model, LGPD, scans, pentest e exceções |
| Operações | SLO, dashboards, alertas, backup/restore e incidentes |
| Engenharia | implementação, testes, documentação e operação da fatia |
| Representante de usuários | UAT e validação das tarefas críticas |

O mesmo indivíduo pode acumular papéis, mas a responsabilidade não pode ficar implícita.

### 26.2 Aprovação dos gates

| Gate | Dono da evidência | Aprovação obrigatória |
|---|---|---|
| F0 | QA Owner | Tech, QA, Segurança e Operações |
| F1 | Product Owner | Produto, Design e Tech |
| F2 | Design Lead | Design, Tech frontend e QA |
| F3 por fatia/consolidado | Tech Lead da fatia | Produto, Design, Tech e QA |
| F4 por capability/consolidado | AI Owner | Produto, AI, Tech, QA e Privacidade |
| F5 por feature/consolidado | Product Owner | Produto, Tech, QA e owner operacional |
| F6/GA | QA Owner | todos os papéis do RACI aplicáveis |

Um aprovador pode rejeitar o gate por ausência de evidência dentro de sua responsabilidade. Exceção não pode ser aprovada apenas pelo executor.

### 26.3 Cadência

- planejamento semanal por caminho crítico;
- revisão curta de risco/impedimento duas vezes por semana;
- demo e evidência ao final de cada slice;
- review de design antes e depois da implementação visual;
- triagem contínua de P0/P1;
- review quinzenal de métricas/IA;
- go/no-go formal em cada gate;
- registro de decisão no mesmo dia.

### 26.4 Controle de mudança

Mudança de escopo, contrato, budget ou gate exige:

- problema e evidência;
- opções e trade-offs;
- impacto em prazo, risco e rollback;
- decisão e aprovador;
- atualização do PRD/plano/ADR;
- comunicação às fatias dependentes.

Exceção temporária deve ter owner e data de expiração.

---

## 27. Riscos e mitigação

| Risco | Probabilidade/impacto | Mitigação | Gatilho |
|---|---|---|---|
| worktree misto causar perda | alta/alta | ledger, backup, commits pequenos, sem reset global | diff sem origem |
| vazamento cross-tenant | média/crítica | invariantes, fixtures A/B, testes IDOR, gate P0 | qualquer associação fora da conta |
| redesign big bang | alta/alta | primitives + migração por família + flags | slice amplo sem rollback |
| CSS continuar crescendo | alta/média | budgets e remoção no mesmo slice | dívida aumenta |
| jurídico vazar para núcleo | alta/alta | pacote vertical versionado | regra hardcoded global |
| score parecer preditivo sem dados | alta/alta | linguagem explicável, shadow e volume mínimo | claim de probabilidade |
| cliente mal classificado silenciar IA | alta/alta | evidência forte e intenção separada | agenda vira customer |
| duas IAs responderem | média/crítica | Core único e supressão/locks | Orchestrator envia direto |
| handoff ignorar takeover | média/crítica | máquina de estados idempotente | resposta após humano |
| RAG citar dado incorreto | média/alta | aprovação, versionamento, threshold e abstention | suporte factual ausente |
| browser local indisponível | média/média | Playwright container/CI e Safari real na release | baseline não executa |
| CI verde enganoso | alta/alta | alinhar versões/jobs ativos | serviço aposentado no gate |
| integração externa instável | alta/média | sandbox, contrato, retry e circuit breaker | erro/latência fora do SLO |
| drift do Chatwoot | média/alta | patches mapeados, upstream tests e upgrades regulares | conflito de overlay |
| performance mascarada pelo watcher | alta/média | watcher opt-in e ambiente de benchmark | CPU contaminada |
| dados pessoais em IA/log | média/crítica | minimização, redaction, retenção e review | PII em trace |
| feature flag só na UI | média/alta | enforcement backend/jobs | deep link/API ainda ativa |
| automação causar dano em massa | média/alta | preview, limites, idempotência e kill switch | job/flow amplo |
| cronograma subestimado | alta/média | faixas, gates e reestimativa F0/F1 | baseline maior que hipótese |
| baixa adoção | média/alta | pesquisa, protótipo, piloto e métricas por papel | tarefa não melhora |

Riscos críticos não podem ser aceitos informalmente. Exigem owner, data, evidência e decisão explícita.

---

## 28. Cronograma indicativo e capacidade

As faixas não são promessa. A baseline das Fases 0 e 1 deve recalibrar o plano.

| Fase | Faixa | Paralelismo seguro |
|---|---:|---|
| F0 — baseline/segurança/QA | 4–6 semanas | CI, fixture, tenancy e auditoria |
| F1 — benchmark/PRD/protótipo | 3–5 semanas | pesquisa e arquitetura |
| F2A — fundação visual | 4–7 semanas | tokens, primitives e piloto |
| F2B — migração/limpeza | acompanha F3 até 30 dias após GA | por família, com F2B-RC e F2B-FINAL |
| F3 — redesign por áreas | 10–16 semanas | no máximo duas fatias |
| F4 — CAPITÃO/score | 8–14 semanas | capabilities independentes após segurança |
| F5 — novas features | 6–12 semanas | após dependências correspondentes |
| F6 — hardening final | 3–5 semanas | matrizes por especialidade |

Com uma equipe de aproximadamente 1 Product, 1 Design, 3–4 Engenharia, 1 QA e apoio parcial de IA, Segurança e Operações, o horizonte provável até GA é **28–42 semanas**. O encerramento definitivo ocorre depois da janela adicional de 30 dias para UI/CSS e, quando F4 for ativada, 60 dias para IA/score. Pode haver benchmark/prototipação read-only de F1 durante o fechamento da F0 e inventário técnico da F2 durante a F1; implementação F2 só começa após o Gate F1. F3 e F4 paralelizam apenas as capabilities cujas dependências estão satisfeitas.

Com equipe menor, preservar gates e reduzir escopo por release; não comprimir qualidade.

### 28.1 Marcos executivos

| Marco | Resultado |
|---|---|
| M0 | worktree protegido e CI confiável |
| M1 | Fase 0 comprovada por E2E/visual/a11y |
| M2 | produto-alvo e protótipos aprovados |
| M3 | F2A e primeira família migrada |
| M4 | Inbox + Cliente 360 + CRM essenciais em piloto |
| M5 | identidade/score/handoff v2 em shadow/piloto |
| M6 | features de impacto com telemetria |
| M7 | release candidate aprovada |
| M8 | GA gradual; depois F2B-FINAL e encerramento |

---

## 29. Mapa de áreas e arquivos

Este mapa orienta descoberta. Antes de editar, executar busca e verificar sobreposição Enterprise.

| Domínio | Áreas prováveis |
|---|---|
| Rotas/API CRM | `core/app/controllers/api/v1/accounts/crm/`, routes, serializers |
| Domínio CRM | `core/app/models/crm_*`, `core/app/services/crm/`, jobs/policies |
| CAPITÃO Core | controllers/models/services/jobs sob `captain` e `Captain::*` |
| Score/lifecycle | `lead_score_calculator.rb`, `crm_lead_score.rb`, lifecycle/classifier/triage |
| Frontend CRM | rotas/views/components/store/API do dashboard CRM |
| Frontend CAPITÃO | views/components/store/API do dashboard Captain/AI Center |
| Inbox/contatos | dashboard conversations, contacts e shared panels |
| Design/CSS | assets CSS/SCSS, Tailwind, `components-next/`, entrypoints |
| Enterprise | `core/enterprise/app` e equivalentes afetados |
| Orchestrator | `services/orchestrator/src`, testes e contratos |
| Infra/CI | Docker Compose, Dockerfiles, `.github/workflows`, health checks |
| QA/docs | `docs/audit`, `docs/qa`, auditorias, ADRs e setup |

Arquivos citados por nome podem mudar durante evolução do fork; o requisito e o contrato são estáveis, não o path presumido.

---

## 30. Entregáveis formais

| Entregável | Fase | Conteúdo mínimo |
|---|---:|---|
| `docs/execution/WORKTREE-LEDGER.md` | F0 | origem, decisão, teste e rollback por diff |
| auditorias atualizadas | F0 | commit, ambiente, data, cobertura e lacunas |
| `AUDITORIA-CAPITAO.md` | F0 | runtime, config, score, RAG, memória e handoff |
| `docs/qa/MATRIZ-COBERTURA.md` | F0 | requisito/rota/persona/teste/evidência |
| `BENCHMARK.md` | F1 | mercado, padrões e adotar/adaptar/rejeitar |
| `PRD-REFORMULACAO-CRM.md` | F1 | objetivos, jornadas, escopo, métricas e aceite |
| protótipos P0 | F1 | fluxos e resultados de teste |
| `docs/chusterm_design_system.md` | F2 | tokens, primitives, padrões e a11y |
| `docs/DESIGN.md` | F2 | direção visual e arquitetura de interface |
| catálogo de componentes | F2 | estados e evidência visual |
| datasets/evals IA | F4 | versões, rubric, resultados e sign-off |
| dicionário de métricas | F3/F4 | definições e consultas |
| runbooks | contínuo | alerta, diagnóstico e recuperação |
| `QA-FINAL.md` | F6 | evidências, gates, bugs, rollback e aprovações |

O arquivo presente, `PLANO-REFORMULACAO-CRM.md`, é o índice mestre e plano de execução; os demais entregáveis aprofundam uma fase e devem referenciá-lo.

---

## 31. Decisões abertas, vinculantes e premissas

| Tema | Estado/premissa | Owner | Formalizar até |
|---|---|---|---|
| público-alvo | operações brasileiras de atendimento + vendas | Product Owner | Gate F1 |
| vertical jurídico | pacote configurável, não núcleo | Produto + Tech | Gate F1 |
| evidência de cliente | deal/contrato/faturamento/manual auditado | Produto + Tech + Privacidade | F1/F3-EN |
| Core/Orchestrator | **decisão vinculante:** Core verdade; Orchestrator inferência | Tech Lead | ADR na F0 |
| identidade visual | Midnight Indigo, Manrope/Inter conforme design brief | Design + Produto | Gate F1 |
| sequenciamento CSS | proposta F2A/F2B; sem efeito até adendo e ADR-008 | Produto + Design + Tech | antes de iniciar F3 |
| browsers | matriz da seção 19 | QA + Produto | Gate F1 |
| escala | hipóteses da seção 20 | Operações + Produto | F0/F1 |
| provedor/modelos IA | abstração com budget e fallback | AI + Operações | antes do piloto F4 |
| retenção/LGPD | por classe de dado e base legal | Privacidade + Tech | F0, antes de persistir memória v2 |
| canais prioritários | WhatsApp primeiro, omnichannel preservado | Product Owner | Gate F1 |
| participantes de pesquisa | todos os papéis críticos | Design + Produto | início da F1 |
| contas piloto | internas/consentidas, baixo risco | Produto + Operações | antes do rollout |
| sandboxes | Evolution, Google e LLM isolados | Operações + QA | Gate F0 |
| densidade UI | confortável + compacta onde necessário | Design Lead | F2 |
| score automático | desligado até shadow e gate quantitativo | AI + Produto | F4 |

Se uma decisão não for tomada no prazo, usar a premissa proposta apenas quando for reversível; caso contrário, marcar bloqueio.

### 31.1 Fora de escopo inicial

- reescrever o Chatwoot ou substituir Rails/Vue;
- criar um segundo CRM ou uma segunda Inbox;
- treinar modelo fundacional próprio;
- declarar previsão comercial sem dados suficientes;
- remover todo CSS legado em um único lote;
- automatizar decisões irreversíveis por score;
- expandir para novas verticais antes do núcleo configurável;
- migrar infraestrutura sem relação comprovada com o objetivo;
- executar alterações destrutivas em produção como parte do redesign.

---

## 32. Referências de mercado e técnicas

Fontes primárias consultadas para transformar padrões de mercado em hipóteses do plano:

- [Attio — criação e visualização de registros](https://attio.com/help/reference/managing-your-data/records/create-and-view-records)
- [Attio — navegação no workspace](https://attio.com/help/reference/productivity-collaborating/navigating-your-workspace)
- [Attio — workflows](https://attio.com/help/reference/automations/workflows/overview-of-workflows)
- [HubSpot — lifecycle stages](https://knowledge.hubspot.com/records/use-lifecycle-stages)
- [HubSpot — lead scoring](https://knowledge.hubspot.com/scoring/understand-the-lead-scoring-tool)
- [Pipedrive — rotting feature](https://support.pipedrive.com/en/article/the-rotting-feature)
- [Intercom — Fin AI Agent em workflows](https://www.intercom.com/help/en/articles/10032299-use-fin-ai-agent-in-workflows)
- [Intercom — bot inbox](https://www.intercom.com/help/en/articles/3722087-turn-on-the-bot-inbox)
- [Crisp — Automated Inbox](https://help.crisp.chat/en/article/how-does-the-automated-inbox-work-1hg5umu/)
- [Salesforce — Einstein lead insights](https://help.salesforce.com/s/articleView?id=einstein_sales_lead_insights.htm&language=en_US)
- [Zendesk — intelligent triage](https://support.zendesk.com/hc/en-us/articles/4964463770650-About-intelligent-triage)
- [RD Station CRM — vendas pelo WhatsApp](https://www.rdstation.com/produtos/crm/vendas/vender-pelo-whatsapp/)
- [Kommo — automação do pipeline](https://support.kommo.com/resources/docs/automate-pipeline-actions)
- [Zenvia — Customer Cloud](https://zenvia.com/customer-cloud/)
- [Chatwoot — command bar](https://www.chatwoot.com/features/command-bar/)
- [Linear — modelo conceitual e ações consistentes](https://linear.app/docs/conceptual-model)
- [Notion — navegação pela sidebar](https://www.notion.com/help/category/sidebar-navigation)
- [W3C — WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [web.dev — Core Web Vitals](https://web.dev/articles/vitals)

O benchmark formal da Fase 1 deve registrar data, recorte, evidência, padrão observado e decisão; links sozinhos não substituem a análise.

---

## 33. Definition of Done global

Uma entrega só está pronta quando, conforme aplicável:

- requisito e risco possuem ID;
- código está revisado e compatível com Core/Enterprise;
- migration é aditiva, observável e reversível;
- tenant e permissão foram testados;
- unit/component/request/contract/E2E aplicáveis passam;
- estados loading, vazio, erro, offline e sem permissão existem;
- i18n e conteúdo foram revisados;
- teclado, foco, contraste, toque e leitor de tela foram validados;
- budget de performance não regrediu;
- telemetria e alertas necessários existem;
- documentação e ADR foram atualizados;
- feature flag e rollback foram exercitados;
- evidência foi anexada;
- UAT aprovou a tarefa;
- não há P0/P1 aberto;
- dívida aceita possui owner e expiração.

`Não executado` nunca equivale a `aprovado por inspeção`.

---

## 34. Matriz mestre de rastreabilidade

| Objetivo/requisito | Fase principal | Gate/evidência |
|---|---:|---|
| não perder funcionalidade existente | F0–F6 | inventário + matriz + dois ciclos P0 |
| segurança e isolamento de contas | F0 | testes Conta A/B e security report |
| UX mais simples e moderna | F1–F3 | benchmark, protótipos, UAT e métricas de tarefa |
| design consistente e responsivo | F2A/F2B–F6 | tokens, catálogo, visual/a11y, F2B-RC e F2B-FINAL |
| CRM completo e interligado | F3 | Inbox → 360 → deal → atividade → relatório |
| lead/cliente confiável | F3-EN/F4 | contrato, evidência, dataset e lifecycle tests |
| score inteligente/explicável | F4 | shadow, fatores, versão e avaliação |
| CAPITÃO humanizado/controlável | F4 | evals, handoff, takeover e groundedness |
| sistema rápido | F0–F6 | baseline, budgets e RUM/APM |
| novas funcionalidades úteis | F5 | matriz impacto/resultado de piloto |
| qualidade total | F6 | `QA-FINAL.md` e sign-offs |

### 34.1 IDs das auditorias e ADRs

| IDs de origem | Work package | Evidência/gate |
|---|---|---|
| ADR-001 | F0-ENV-01: imagem-base pinada e upgrade controlado | digest, build, migration e rollback |
| ADR-002 | F0-ENV-01: URL local canônica | smoke em `localhost:8086` conforme `SETUP.md` |
| ADR-003; AUD-HIGH-01; FUNC-HIGH-01 | F0.3/F0.4: evidência antes de redesign | Playwright, visual, axe e Gate F0 |
| ADR-004; AUD-CRIT-01; FUNC-CRIT-01 | F0.2: contrato database/display ID | E2E-CRM-01 |
| ADR-005; AUD-HIGH-07; FUNC-HIGH-04 | F0.1: CI/Orchestrator reproduzível | testes/build/contrato reais |
| ADR-006 | F0-WT-01: reconciliar plano errado | ledger preserva domínio válido e remove só resíduo confirmado |
| ADR-007 | F0-CPU-01: watcher opt-in | benchmark sem `core-vite` |
| ADR-008 planejado | F2A/F2B incremental | adendo explícito ao prompt; sem aprovação, ordem estrita |
| AUD-CRIT-02; CSS-01; CSS-08 | F2.0: congelar força na cascata | budget regressivo e nenhum `!important` novo |
| AUD-CRIT-03; CSS-02; CSS-03 | F2.1: tokens/imports únicos | light/dark, aliases e bundle |
| CSS-04; AUD-HIGH-05 | F2.2/F3: primitives e migração por família | catálogo + remoção controlada |
| CSS-05 | F2.1/F2.3: eliminar hardcodes por slice | auditor CSS e snapshots |
| CSS-06; AUD-HIGH-04; AUD-HIGH-06 | F0.3/F2/F3: responsive e WCAG | cinco viewports, axe e manual |
| CSS-07; AUD-MED-07 | F2.0/F6: CSS morto com prova dinâmica | coverage e gate final CSS |
| AUD-HIGH-02; FUNC-HIGH-02 | F3D: won/lost/reopen e motivo | E2E-CRM-04 |
| AUD-HIGH-03; FUNC-HIGH-03 | F3D: paginação/conjunto completo | E2E-CRM-07 com 201/1.000 |
| FUNC-HIGH-05 | F0/F6: sandboxes externas | Evolution, Google e LLM |
| AUD-MED-01; FUNC-MED-01 | F3D: valor/somas | E2E-CRM-08 e reconciliação |
| AUD-MED-02; FUNC-MED-02 | F3D: conjunto operacional do board | contrato open/won/lost/archived |
| AUD-MED-03; FUNC-MED-03 | F3B/F4: ações CAPITÃO | resumo real, link correto e E2E-CRM-05 |
| AUD-MED-04; FUNC-MED-04; FUNC-MED-05 | F2/F3D: motivos e dialog único | CRUD + teclado/axe |
| AUD-MED-05; FUNC-MED-06 | F0.3/F3: cobertura frontend CRM | components/stores/14 rotas |
| AUD-MED-06 | F0.2: profile/factory/reports/deep links | request + router + E2E de permissão |
| FUNC-MED-07 | F0.1/F0.4: suíte Rails reproduzível | request specs completos |
| AUD-LOW-01; FUNC-LOW-01 | F0.2: accountId explícito e tenant | request/contract A/B |
| AUD-LOW-02; FUNC-LOW-02 | manutenção de toolchain | build/test sem novos warnings |
| AUD-LOW-03 | F2/F6: bundles antigos e Administrate isolado | inventário e migração separada |

Ao criar `docs/qa/MATRIZ-COBERTURA.md`, desdobrar cada ID em linha individual com status, owner, teste e evidência; o agrupamento acima não permite fechar vários achados com uma única prova genérica.

---

## 35. Ordem prática para iniciar

### Primeiras duas semanas

1. congelar expansão de escopo e aprovar este plano como índice mestre;
2. criar o ledger do worktree sem reverter mudanças;
3. validar backup/restore;
4. corrigir CI para serviços e versões ativos;
5. criar fixtures Conta A/B e personas;
6. iniciar Playwright e o primeiro P0;
7. corrigir associações cross-tenant do deal/CAPITÃO;
8. criar matriz configuração → runtime do CAPITÃO;
9. atualizar auditorias com status verificado/implementado/pending;
10. selecionar participantes da pesquisa F1.

### Semanas três a seis

1. concluir tenancy/IDs/RBAC;
2. completar screenshots, axe e matriz por viewport;
3. executar sandboxes;
4. produzir `AUDITORIA-CAPITAO.md`;
5. reconciliar CI, performance e inventário;
6. executar o P0 completo duas vezes;
7. decidir Gate F0;
8. iniciar benchmark formal, pesquisa e arquitetura de informação.

Nenhuma implementação visual ampla deve começar antes do Gate F0. Um protótipo não mutável pode avançar em paralelo para reduzir tempo.

### Ritual de início de cada tarefa

1. localizar o ID no plano/backlog;
2. confirmar evidência e dependências;
3. buscar código e overlay Enterprise;
4. registrar baseline e teste que falha;
5. planejar migration/flag/rollback;
6. implementar a menor fatia vertical;
7. executar gates;
8. anexar evidência e atualizar status;
9. somente então iniciar o próximo item dependente.

---

## 36. Critério de encerramento da reformulação

A reformulação estará concluída somente quando:

1. as Fases 0 a 6 passaram pelos gates, incluindo F2B-FINAL;
2. o `QA-FINAL.md` está aprovado;
3. os fluxos P0 funcionam nos ambientes e personas suportados;
4. identidade, score e CAPITÃO atendem aos datasets e controles;
5. durante os 14 dias a 100%, tarefas e guardrails mostram melhora ou ausência de regressão; métricas de IA/score continuam monitoradas pela janela de 60 dias;
6. segurança, acessibilidade, performance e restore estão comprovados;
7. rollout permaneceu 14 dias a 100% dentro dos SLOs e sem atingir o limiar de pausa do error budget;
8. rollback permaneceu possível durante toda a janela aplicável — 30 dias para UI/CSS e 60 dias para IA/score — e os fallbacks legados foram removidos somente depois dela;
9. documentação e runbooks correspondem ao runtime;
10. o fallback legado foi removido na release posterior estável exigida por F2B-FINAL.

Até esse ponto, o status correto é **reformulação em execução**, mesmo que a interface já pareça nova.

---

## 37. Entrega IA + Atendimento — 2026-07-22

Status: **implementado e validado no servidor local**.

### Política de controle da conversa

- score, relacionamento Lead/Cliente e etapa do ciclo deixaram de causar handoff;
- handoff passou a aceitar somente motivos estruturados: pedido do cliente, mensagem/tomada humana, ação manual, solicitação explícita da IA, risco de segurança ou falha do provedor;
- caixas antigas configuradas com `human_request_or_score` ou `score_threshold` foram migradas para `human_request`;
- movimentação automática de etapa por score passou a ser opt-in e ficou desabilitada nas configurações existentes;
- inatividade após pergunta da IA agora gera recomendação interna de revisão, não transferência; o comportamento antigo exige opt-in explícito da caixa;
- cliente confirmado pode continuar sendo atendido pelo Capitão, sem bloqueio automático.

### Inteligência e explicabilidade

- nova classificação Lead/Cliente por evidências, com confiança e fonte da decisão;
- negócio ganho, relacionamento confirmado, etapa do ciclo e tipo do contato são evidências fortes de cliente;
- contato salvo no WhatsApp, isoladamente, não é evidência de cliente;
- score mantém componentes, peso, evidência e próxima melhor ação separados da decisão de handoff;
- score alto no Orchestrator gera `review_recommended`, nunca `handoff_recommended`.

### Redesign do Atendimento

- painel lateral ampliado para uma visão 360º da conversa;
- novo centro operacional Midnight Indigo do Capitão;
- quatro estados claros: IA ativa, supervisionada, pausada e humano no controle;
- relacionamento, confiança, score, fatores, contexto, próximo passo do CRM e responsável reunidos na mesma superfície;
- tomada e retomada da IA com motivo auditável e aviso contra respostas concorrentes;
- comportamento responsivo validado em desktop e mobile, sem overflow horizontal;
- zero violações Axe críticas ou sérias dentro do novo centro do Capitão.

### Evidências executadas

- Orchestrator: 10 testes aprovados e build TypeScript aprovado;
- autenticação QA: 8 personas aprovadas;
- shell + Atendimento desktop: 10 testes aprovados;
- novo Atendimento em desktop e mobile: 2 testes aprovados com Axe;
- política Rails validada no runtime: score 100 preserva `ai_mode=auto`;
- migração `20260722000001` aplicada;
- Core, Sidekiq e Orchestrator saudáveis após rebuild e recriação.

### Próximas medições obrigatórias

O mecanismo está tecnicamente seguro, mas a calibração comercial continua dependente de histórico real com negócios ganhos/perdidos, handoffs confirmados, reaberturas e resolução. Manter shadow mode e observar a janela definida neste plano antes de chamar o score de preditivo.

---

## 38. Entrega UX/UI do Atendimento — 2026-07-23

Status: **implementada e validada no ambiente local; publicação na VPS não faz parte desta etapa**.

### Sistema visual e remoção de legado

- removido o `chusterm-theme.css`, que concentrava 2.547 linhas e 338 usos de `!important`;
- removidas suas importações de runtime e da imagem Docker;
- consolidada a aparência clara/escura nos tokens semânticos `--ds-*`;
- unificadas as famílias tipográficas locais Inter e Inter Display;
- removido o `!important` incorreto da família padrão do Tailwind;
- migrados shell, sidebar, lista, conversa, mensagens, compositor, painel de contato, CRM lateral e Copilot para superfícies, bordas, estados e foco adaptativos;
- substituídos ícones Fluent/Phosphor visíveis no fluxo principal por Lucide, preservando apenas marcas e ícones próprios sem equivalente;
- eliminados estilos locais antigos do editor e das mensagens onde a estrutura passou a ser expressa por Tailwind e tokens.

### Experiência de atendimento

- nova busca textual dentro da lista de conversas, com debounce, atalho `/`, limpeza por `Escape`, estados de carregamento/erro/vazio e botão de tentar novamente;
- busca no backend por nome, telefone, e-mail, conteúdo da mensagem e identificadores exatos, sempre limitada à conta e aos filtros permitidos;
- proteção contra respostas assíncronas antigas, eventos WebSocket contaminando resultados e repetição de paginação após erro;
- conversa aberta e histórico permanecem preservados durante a busca;
- cabeçalho, tabs, cards, datas, etiquetas, mensagens e composer ganharam hierarquia, espaçamento e alinhamento consistentes;
- painel de contato e CRM deixou de ter containers/títulos duplicados, links com botões aninhados e ícones sem nome acessível;
- centro do Capitão usa estados claros, sem mistura visual entre tema escuro e tema claro;
- menus, sidebars, popovers e submenus suportam teclado, foco restaurado, `Escape`, ARIA e telas de 360–390 px;
- em celulares, uma preferência de painel de contato herdada do desktop não intercepta mais a abertura da conversa: o chat aparece primeiro e o painel continua acessível sob demanda;
- modo de resposta e nota passou a ser um controle segmentado real; expansão do editor, áudio e ações de ícone possuem nomes acessíveis.

### Evidências locais

- 17 arquivos de teste de componentes executados, com 51 testes aprovados;
- testes específicos cobrem busca, tabs, datas, sidepanel, sidebar colapsada, estado do Capitão, contato, ícones sociais, editor e Copilot;
- ESLint dos componentes alterados concluído sem erros;
- build Vite de produção concluído com 4.504 módulos transformados;
- imagem Docker local reconstruída, com o serviço de busca presente, o tema legado ausente e o Core saudável em `localhost:8086`;
- smoke visual executado nos temas claro e escuro, em desktop de 1.920 px e mobile de 390 px, sem overflow horizontal nem erros de página;
- busca validada no runtime com redução correta para uma conversa, limpeza por `Escape` e preservação da conversa ativa.

### Pendências que não devem ser confundidas com esta entrega

- esta etapa não autoriza nem registra deploy na VPS;
- Stylelint e orçamento automatizado de CSS continuam como evolução de CI;
- rotas secundárias e componentes legados fora do fluxo Atendimento/CRM seguem a migração incremental definida nas Fases 2A/2B;
- calibração preditiva do score continua dependente de dados reais e da janela de observação.

---

## 39. Publicação UX/UI na VPS — 2026-07-23

Status: **publicada e validada em produção**.

### Release e proteção operacional

- release imutável: `20260723T183836-f5f0dde-uiux`;
- fonte ativa: `/opt/chusterm-releases/20260723T183836-f5f0dde-uiux/source`;
- ambiente ativo preservado da release anterior, sem copiar o `.env` do localhost nem o worktree remoto divergente;
- backup pré-deploy de 7,7 GB criado em `/opt/chusterm-backups/20260723T183836-f5f0dde-uiux`;
- dumps PostgreSQL, storage, Redis, Evolution, fonte anterior e checksums validados;
- imagens anteriores de Core, Sidekiq e Orchestrator etiquetadas para rollback;
- Core construído uma única vez e reutilizado pelo Sidekiq para reduzir tempo e pico de memória;
- nenhuma migration Rails pendente; versão máxima permaneceu `20260722000001`;
- migration idempotente do Orchestrator concluída pelo runner incluído na imagem de produção.

### Evidências de produção

- Core, Sidekiq, Orchestrator, PostgreSQL, Redis e Evolution API em estado `healthy`;
- raiz pública e `/health` responderam HTTP 200;
- release ativa confirmada pelos labels dos containers e pelo link `/opt/chusterm-current`;
- serviço de busca e correção do painel mobile presentes dentro da imagem ativa;
- `chusterm-theme.css` ausente da imagem de produção;
- busca por nome exato validada no runtime e lista restaurada por `Escape`;
- tema claro e escuro validados em 1.920 px;
- lista e busca validadas em 390 px, sem overflow horizontal;
- nenhum erro de página, nenhuma requisição interna falha e nenhum `ERROR`, `FATAL`, `exception` ou `failed` nos logs dos serviços após a troca;
- Core, Sidekiq e Orchestrator permaneceram com contador de reinício igual a zero;
- Orchestrator confirmado no OpenRouter com `x-ai/grok-4.5`;
- verificador de runtime da Dra. Paula aprovado integralmente no `claude-sonnet-5`,
  incluindo respostas concisas, coleta de documentos, proteção de credenciais,
  fallback de saída malformada e transferência explícita para humano.

Durante a preparação, uma primeira chamada manual do Orchestrator tentou usar
`drizzle-kit`, indisponível na imagem final. O gate interrompeu o processo antes
de qualquer container ser substituído. O comando foi corrigido para
`node dist/db/migrate.js`, as imagens ativas foram reconfirmadas e a publicação
foi retomada com sucesso.

---

## 40. Auditoria integral para a nova reformulação — Fase 1

Status: **auditoria concluída no ambiente local; aguardando aprovação para iniciar
a Fase 2**.

Documento de execução: `AUDITORIA-FASE-1-REDESIGN.md`.

### Escopo auditado

- inventário estático de 135 padrões de rota e validação de 102 URLs únicas no
  runtime local;
- comparação visual de CRM, agenda, atividades, atendimento, contatos,
  relatórios, configurações e páginas públicas;
- baseline de acessibilidade WCAG 2.1 AA, navegação por teclado, responsividade
  em 320, 375 e 768 px e risco de performance por volume de DOM;
- investigação da divergência entre os indicadores de Atividades e Agenda;
- levantamento de headers, botões, cards, tipografia, cores, sombras, raios,
  sistemas de ícones e estilos locais concorrentes;
- registro de erros funcionais observados, sem alterar integrações, banco,
  autenticação ou produção.

### Gate de continuidade

A Fase 2 somente poderá começar após aprovação explícita da matriz. O piloto
proposto é a tela de Atividades, com tokens semânticos, componentes-base,
densidade operacional, acessibilidade e responsividade. Nenhuma expansão para
outros módulos deve ocorrer antes da validação desse piloto.

Esta auditoria foi isolada na branch
`refactor/design-system-phase-1-audit`. Ela não modifica nem substitui a release
de produção descrita na seção 39.

---

## 41. Sistema visual operacional — Fase 2

Status: **piloto concluído e validado no ambiente local; Fase 3 bloqueada até
nova aprovação**.

Documento de execução: `DESIGN-SYSTEM-FASE-2.md`.

### Entrega

- estudo de Linear, Attio, Height, Vercel, Kommo, Pipedrive, Front e Intercom,
  extraindo princípios de densidade, hierarquia, filtros e operação;
- contrato de tokens com uma fonte, seis tamanhos, três pesos, espaçamento de
  4 px, dois raios, duas sombras e uma família de ícones;
- 17 componentes-base com estados, foco visível, teclado e semântica;
- redesign aplicado exclusivamente à tela de Atividades;
- remoção de KPIs decorativos, gradientes, cards aninhados e CSS local no piloto;
- tabela operacional paginada em lotes de 50 registros, ações hierarquizadas e
  criação/edição em drawer;
- fallback para a tela anterior protegido pela feature flag existente `crm_v2`.

### Evidências de validação

- 11 testes direcionados aprovados;
- ESLint direcionado e build Vite com 4.524 módulos aprovados;
- Core local saudável com o piloto ativo somente por `crm_v2`;
- temas claro e escuro aprovados em 320, 375, 768, 1024, 1440 e 1920 px, sem
  overflow horizontal do documento;
- Axe WCAG 2.1 AA sem violações no conteúdo principal e no modal destrutivo;
- busca, tabs por teclado, menu, drawer, modal, foco e `Escape` validados;
- evidências salvas em `artifacts/ui-audit-phase2-20260723/`.

### Limites e gate

Esta fase não altera banco, autenticação, integrações, canais, webhooks ou regras
de negócio. A flag permanece desligada em produção e a branch não foi
publicada. O trabalho para aqui e aguarda aprovação explícita para a Fase 3.

---

## 42. Arquétipos de página — Fase 3

Status: **seis templates implementados e validados no ambiente local; rollout
bloqueado até aprovação explícita**.

Documento de execução: `ARQUETIPOS-FASE-3.md`.

### Entrega

- cabeçalho único com breadcrumb, `h1` e ações à direita;
- seis templates reutilizáveis: Lista, Board, Registro, Conversa, Calendário e
  Configuração;
- contratos de slots sem regra de negócio ou dependência de API;
- loading com skeleton estrutural e estado vazio curto e acionável;
- comportamento responsivo específico por arquétipo;
- matriz de encaixe para as 135 rotas inventariadas;
- glossário canônico de Lead, Contato, Cliente, Empresa, Negócio, Atividade,
  Conversa, Atendimento, Pontuação e CAPITÃO;
- galeria comparativa protegida por `crm_v2` e permissão de administrador.

### Evidências

- ESLint direcionado aprovado;
- 18 testes Vitest e 2 testes Playwright aprovados;
- build da imagem local aprovado e Core saudável;
- 72 combinações de arquétipo, largura e tema sem overflow;
- Axe sem violações críticas ou sérias nos seis templates;
- 12 capturas em `artifacts/ui-audit-phase3-20260723/`.

### Gate

A galeria existe somente no localhost e não tem link na sidebar. Nenhuma tela
real foi migrada nesta fase. O rollout por módulo só pode começar depois da
aprovação dos seis contratos, da matriz, do glossário e da ordem proposta em
`ARQUETIPOS-FASE-3.md`.

---

## 43. Rollout do CRM — Lote 1

Status: **Leads, Pipeline e Ficha do negócio migrados e validados no ambiente
local; próximo lote bloqueado até aprovação explícita**.

Documento de execução: `CRM-ROLLOUT-LOTE-1.md`.

### Entrega

- tela de Leads aplicada ao arquétipo Lista;
- Pipeline aplicado ao arquétipo Board;
- Ficha 360 aplicada ao arquétipo Registro;
- busca, filtros, paginação, seleção e movimentação em massa preservados;
- criação, edição, tarefas, mensagens, arquivos, histórico e desfechos
  integrados;
- fallback individual para as três telas anteriores pela feature flag
  `crm_v2`;
- correção compartilhada de contenção responsiva e contraste.

### Evidências

- ESLint direcionado aprovado;
- 35 testes Vitest aprovados em 8 arquivos;
- build Vite de produção aprovado com 4.539 módulos;
- imagem Docker local reconstruída e Core saudável;
- smoke funcional sem erro de página ou falha de API;
- 36 combinações de tema e largura verificadas entre 320 e 1920 px, sem
  overflow horizontal do documento;
- Axe WCAG 2.1 A/AA sem violações críticas ou sérias nas três telas em mobile e
  desktop;
- capturas em `artifacts/ui-audit-phase5-crm1-20260724/`.

### Gate

Este lote permanece apenas no localhost e não foi publicado na VPS. Agenda e
Configurações de Pipeline compõem o lote CRM-2 e dependem de nova aprovação.

---

## 44. Rollout do CRM — Lote 2

Status: **Agenda e Configuração do Pipeline migradas e validadas no ambiente
local; continuidade integral autorizada**.

Documento de execução: `CRM-ROLLOUT-LOTE-2.md`.

### Entrega

- Agenda aplicada ao arquétipo Calendário;
- Configuração do Pipeline aplicada ao arquétipo Configuração;
- busca, filtros, períodos, Google Calendar e próximos compromissos integrados;
- criação, edição, conclusão, exclusão e sugestão de horários preservadas;
- criação, edição, reordenação, scoring, arquivamento, restauração e exclusão
  definitiva de pipelines e etapas preservados;
- navegação específica para desktop e mobile;
- fallback individual das duas rotas pela feature flag `crm_v2`.

### Evidências

- ESLint direcionado aprovado;
- 28 testes Vitest aprovados em quatro arquivos;
- build Vite de produção aprovado com 4.543 módulos;
- imagem Docker local reconstruída e Core saudável;
- 375 e 1440 px sem overflow horizontal;
- Axe sem violações críticas ou sérias no conteúdo das duas páginas;
- contratos `calendar` e `settings` confirmados no runtime.

### Continuidade

O usuário autorizou a continuidade de todas as fases. O rollout segue em lotes
verificáveis para Atendimento, Contatos/Empresas/Busca, CAPITÃO,
Campanhas/Relatórios, Configurações/Central de Ajuda e
Acesso/Widget/Superadmin. A VPS permanece fora de escopo até o gate específico
de publicação.

---

## 45. Consolidação do redesign — Fases 4 a 8

Status: **implementação, regressão final e gate técnico local concluídos**.

Documento de execução: `REDESIGN-ROLLOUT-FASES-4-A-8.md`.

### Entrega

- Atendimento com busca de conversas, contexto responsivo do contato e
  acessibilidade da linha do tempo;
- Contatos e Empresas com cabeçalhos compactos, segmentação progressiva,
  ordenação, expansão e paginação acessíveis;
- Busca global funcional para contatos, conversas, mensagens e artigos;
- CAPITÃO e Sistema de Score com shell consistente, terminologia revisada,
  memória, triagem, pesos, cortes e configuração de modelos preservados;
- Campanhas e Relatórios consolidados em superfícies neutras e responsivas;
- Configurações, Integrações e Central de Ajuda com cabeçalhos e estados vazios
  uniformes;
- Acesso, Widget e Superadmin revisados para uma única tipografia, sem
  gradientes decorativos e com ordem de foco natural;
- remoção dos estados vazios com dados demonstrativos que pareciam registros
  reais.

### Evidências

- ESLint direcionado aprovado;
- 19 testes Vitest aprovados em cinco arquivos;
- build Vite de produção aprovado com 4.534 módulos;
- imagem Docker local
  `sha256:0975d69b6574daf363e30c9b86755c219fd4b769c0d8f1d60b5d7e228ef3ef0a`;
- Core local saudável e sem reinicializações;
- Atendimento ativo sem violações críticas ou sérias no Axe;
- Busca, CAPITÃO, Score, Relatórios e Integrações verificados em desktop e
  celular;
- ausência de overflow horizontal do documento nas rotas auditadas;
- smoke pós-build aprovado em desktop e celular, sem violações sérias ou
  críticas nas rotas de fechamento.

### Gate

O conjunto permanece no localhost com o gate técnico aprovado. A VPS não será
alterada sem autorização explícita, backup e plano de rollback.

---

## 46. Gate de publicação do redesign

Status: **redesign publicado na VPS, validado e estabilizado**.

Releases aplicadas:

- `20260724T042840-f5f0dde-redesign-p4-p8`;
- `20260724T045200-f5f0dde-sidebar-a11y-hotfix`.

### Publicação

- pacote principal validado pelo SHA-256
  `889bdf4a2d6677787b1f88a9702328df87f649218487dde5dc03f31ded4c1321`;
- hotfix validado pelo SHA-256
  `af3814203ea171caec8aa9a89e514fa1671b06d6c2b772cffa56758c9ac8a717`;
- nenhum arquivo `.env` ou credencial incluído nos pacotes;
- árvores de migração do Rails e do Orchestrator comparadas com a versão ativa
  antes da troca dos contêineres;
- nenhuma migração pendente encontrada;
- backup integral verificado em
  `/opt/chusterm-backups/20260724T042840-f5f0dde-redesign-p4-p8`;
- snapshot da versão anterior ao hotfix em
  `/opt/chusterm-backups/20260724T045200-f5f0dde-sidebar-a11y-hotfix`;
- rollback executável preservado dentro das duas releases.

### Correção pós-publicação

O primeiro smoke autenticado encontrou contraste insuficiente em textos
secundários e marcação inválida nas listas aninhadas da sidebar. O hotfix:

- reforçou o token de texto secundário;
- corrigiu a estrutura para `ul > li > ul > li`;
- passou novamente em ESLint, Prettier e build Vite;
- eliminou todas as violações Axe sérias ou críticas do dashboard autenticado
  em 1366 × 768 e 375 × 812.

### Evidências finais

- endpoint interno e público respondendo `{"status":"woot"}`;
- login público HTTP 200 em desktop e celular;
- login autenticado redirecionando para `/app/accounts/1/dashboard`;
- zero respostas 5xx e zero erros de console;
- zero overflow horizontal e zero `tabindex` positivo;
- zero violações Axe sérias ou críticas no login e no dashboard autenticado;
- Core, Sidekiq, Orchestrator, PostgreSQL, Redis e Evolution saudáveis;
- zero reinicializações registradas nos seis serviços;
- imagem final de Core/Sidekiq
  `sha256:1d5764d596017f167c7d8773c1ec72ea4e8d44938a9340abefabae88949ee38f`;
- imagem do Orchestrator
  `sha256:1ccaa2fac9847dab4df31257410de443296159ea7ff324907b49b5023a59a7a2`.
