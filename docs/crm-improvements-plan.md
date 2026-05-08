# Plano de Melhorias do CRM Jurídico - ChusteRM Core

> **Versão**: 4.1 (execução no Core + benchmark Kommo)
> **Data**: 2026-05-05
> **Escopo**: melhorias do CRM dentro do fork do Chatwoot/ChusteRM (`core/`)
> **Decisão principal**: não criar outro CRM. O ChusteRM Core é a fonte única de verdade.

---

## 0. Correção de Rumo

A direção correta é evoluir o CRM **dentro do fork do Chatwoot**, não criar um sistema paralelo em `services/crm-service` ou `services/crm-ui`.

O CRM precisa viver onde o atendimento já acontece:

- Contatos do Chatwoot (`Contact`).
- Conversas (`Conversation`).
- Responsáveis/assignees (`User`, `Conversation#assignee`).
- Labels já existentes do Chatwoot.
- Anexos (`Attachment`).
- Notas privadas.
- Captain/Capitão.
- Dashboard Vue do Chatwoot.

Os serviços externos podem existir apenas como apoio técnico, se necessário, mas **não devem ser o CRM principal**. A experiência do usuário deve estar dentro do ChusteRM Core.

### O que fica fora do escopo principal

- Novo painel Next.js como CRM oficial.
- Banco separado para contatos/deals como fonte primária.
- Duplicar contatos do Chatwoot em outro serviço.
- Criar outro sistema de etiquetas fora das labels do Chatwoot.
- Fazer o Capitão consultar um CRM paralelo antes de consultar o próprio ChusteRM Core.

---

## 1. Objetivo

Transformar o ChusteRM Core em um CRM jurídico mais rico, integrado ao chat e útil para o Capitão.

O resultado esperado:

- O atendente vê no próprio Chatwoot se o contato é **Lead** ou **Cliente**.
- O contato tem um **responsável principal**.
- As etiquetas ficam organizadas por categoria e servem para segmentação real.
- O Capitão consegue usar histórico, etiquetas, lifecycle, responsável, anexos, áudios e imagens.
- A conversa, o contato e o CRM ficam vinculados no mesmo lugar.

---

## 2. Princípios de Arquitetura

1. **Core first**: qualquer dado essencial do CRM deve estar no `core/`.
2. **Chat como origem**: conversas alimentam contato, lifecycle, etiquetas e histórico.
3. **Contato como ficha central**: o `Contact` é a entidade principal do CRM.
4. **Labels do Chatwoot como base**: melhorar o sistema existente, não criar outro.
5. **Captain integrado ao Core**: o Capitão deve ler e escrever dados do próprio Chatwoot.
6. **Sem duplicidade**: evitar dois lugares para a mesma verdade.
7. **Auditoria**: mudanças importantes precisam ter histórico.

---

## 3. Fonte de Verdade

### Entidades principais no Core

| Necessidade | Entidade correta |
|---|---|
| Pessoa atendida | `Contact` |
| Conversa/atendimento | `Conversation` |
| Responsável pelo atendimento atual | `Conversation#assignee_id` |
| Responsável principal pelo relacionamento | novo campo em `contacts` |
| Etiquetas | `Label` + label list do Chatwoot |
| Notas internas | mensagens privadas / notas do contato |
| Documentos e mídia | `Attachment` |
| IA agente | `Captain::Assistant` e serviços Captain |
| Histórico/auditoria | audit events ou eventos próprios no Core |

### Serviços auxiliares

`services/crm-service` e `services/crm-ui` não devem ser tratados como CRM oficial. Se forem mantidos, devem ser:

- protótipo legado;
- ferramenta interna de testes;
- serviço auxiliar para jobs/skills;
- não fonte primária de contato, etiqueta ou lifecycle.

---

## 4. Melhorias no Contato

### 4.1 Lead ou Cliente

Hoje o contato tem `contact_type`, mas isso é pouco claro para o uso jurídico. Precisamos adicionar campos explícitos no `Contact`.

Campos propostos em `contacts`:

```ruby
relationship_status: string
# lead, customer

lifecycle_stage: string
# visitor, lead, qualified_lead, triage, consultation_scheduled,
# customer, active_customer, recurring_customer, ex_customer, lost

lifecycle_stage_changed_at: datetime
became_lead_at: datetime
became_customer_at: datetime
first_customer_at: datetime
last_legal_interaction_at: datetime
```

### 4.2 Definição simples para UI

| Campo | Uso |
|---|---|
| `relationship_status` | Mostra se é Lead ou Cliente |
| `lifecycle_stage` | Mostra a etapa detalhada |

Exemplo:

- `relationship_status = lead`
- `lifecycle_stage = triage`

ou:

- `relationship_status = customer`
- `lifecycle_stage = active_customer`

### 4.3 Estágios

| Estágio | Significado |
|---|---|
| `visitor` | Conversou sem identificação suficiente |
| `lead` | Identificado, mas ainda sem triagem completa |
| `qualified_lead` | Área e necessidade identificadas |
| `triage` | Capitão ou humano coletando dados |
| `consultation_scheduled` | Consulta/agendamento criado |
| `customer` | Virou cliente |
| `active_customer` | Tem caso ativo |
| `recurring_customer` | Já fechou mais de um caso |
| `ex_customer` | Cliente antigo sem caso ativo |
| `lost` | Lead perdido/desqualificado |

### 4.4 Regras automáticas

- Nova conversa identificada: `lead`.
- Capitão identificou área e necessidade: `qualified_lead` ou `triage`.
- Consulta marcada: `consultation_scheduled`.
- Humano marcou como cliente: `customer`.
- Existe caso ativo: `active_customer`.
- Segundo caso fechado: `recurring_customer`.
- Lead desqualificado: `lost`.

Importante: a mudança para cliente deve poder ser manual, com botão claro: **Marcar como cliente**.

---

## 5. Responsável pelo Contato

### 5.1 Diferença entre atendimento e relacionamento

No Chatwoot já existe responsável pela conversa:

- `conversation.assignee_id`

Mas falta o responsável pelo contato como relacionamento de CRM.

Novo campo em `contacts`:

```ruby
crm_owner_id: integer
crm_owner_assigned_at: datetime
crm_owner_source: string
# manual, assignee, routing_rule, captain, import
```

### 5.2 Regras

- Se o contato já tem `crm_owner_id`, novas conversas mostram esse responsável.
- Se a conversa tem assignee e o contato não tem owner, sugerir usar o assignee como responsável.
- Se o Capitão identifica a área, pode sugerir responsável por regra de roteamento.
- Lead quente sem responsável deve aparecer como alerta.
- Troca manual de responsável deve gerar histórico.

### 5.3 UI

Na tela de conversa e no painel de contato:

- Badge/linha: **Responsável: Nome do usuário**.
- Se vazio: **Sem responsável** com ação "Atribuir".
- Filtro: "Meus contatos".
- Filtro: "Sem responsável".
- Ação em massa em contatos/conversas: "Atribuir responsável".

---

## 6. Sistema de Etiquetas

### 6.1 Direção correta

Usar e melhorar o sistema de labels do Chatwoot, não criar outro sistema paralelo.

Hoje o Chatwoot já tem:

- tabela `labels`;
- labels em conversas;
- labels em contatos;
- `label_list`;
- automações com labels;
- filtros por labels.

O que falta é governança: categoria, escopo, padrão de nomes e uso pelo Capitão.

### 6.2 Melhorias propostas em `labels`

Adicionar campos ao modelo `Label`:

```ruby
category: string
# area, temperature, relationship, status, document, origin, risk, service

slug: string
# area.previdenciario, temp.quente, rel.cliente

scope: string
# contact, conversation, both

is_system: boolean
description: text
```

Se não for seguro alterar muito a tabela `labels`, usar `custom_attributes` da label ou uma tabela complementar:

```ruby
crm_label_settings
- label_id
- category
- slug
- scope
- is_system
- description
```

Preferência: alterar `labels` se o impacto for controlado.

### 6.3 Taxonomia inicial

#### Área jurídica

- `area.previdenciario`
- `area.trabalhista`
- `area.civel`
- `area.consumidor`
- `area.familia`
- `area.imobiliario`
- `area.penal`
- `area.tributario`
- `area.empresarial`
- `area.auxilio_maternidade`

#### Temperatura

- `temp.quente`
- `temp.morno`
- `temp.frio`

#### Relacionamento

Essas labels podem ser espelho visual dos campos estruturados:

- `rel.lead`
- `rel.cliente`
- `rel.cliente_ativo`
- `rel.recorrente`
- `rel.ex_cliente`

Mas a fonte da verdade continua sendo `contacts.relationship_status` e `contacts.lifecycle_stage`.

#### Status operacional

- `status.em_triagem`
- `status.consulta_agendada`
- `status.aguardando_documento`
- `status.aguardando_retorno`
- `status.sem_responsavel`
- `status.reativar`

#### Documentos

- `doc.rg_pendente`
- `doc.rg_recebido`
- `doc.cpf_pendente`
- `doc.comprovante_recebido`
- `doc.cnis_pendente`
- `doc.ctps_pendente`
- `doc.procuracao_pendente`
- `doc.documento_ilegivel`

#### Risco

- `risk.prazo_urgente`
- `risk.audiencia_marcada`
- `risk.intimacao_recebida`
- `risk.conflito_pendente`
- `risk.conflito_alertado`

### 6.4 Regras de uso

- Área jurídica: aplicada na conversa e no contato.
- Temperatura: aplicada principalmente no contato.
- Relacionamento: sincronizada com lifecycle.
- Documento: aplicada quando o Capitão pede ou reconhece anexos.
- Risco: aplicada quando houver prazo, audiência, intimação ou conflito.
- Status sem responsável: aplicada automaticamente quando necessário.

### 6.5 UI de labels

Melhorias dentro do dashboard Vue:

- Agrupar labels por categoria no painel lateral.
- Mostrar cores consistentes por categoria.
- Usar nomes de exibicao humanos no chat/CRM, mantendo `title`/`slug` tecnicos para integracoes.
- Nao exibir labels no menu principal lateral; elas devem aparecer no chat, contato, filtros, CRM e configuracoes.
- Adicionar filtro por categoria.
- Evitar duplicatas ao criar nova label.
- Sugerir slugs padronizados.
- Permitir arquivar label sem perder histórico.
- Mostrar origem quando label for aplicada pelo Capitão.

### 6.6 Capitão e labels

O Capitão já tem ferramenta `add_label_to_conversation`. Precisamos melhorar:

- Quando aplicar label na conversa, decidir se também aplica no contato.
- Quando remover ou trocar temperatura, evitar múltiplas labels conflitantes.
- Registrar nota privada explicando por que aplicou a label.
- Usar labels existentes, não criar nomes soltos.

Exemplo:

```text
Se identificar caso trabalhista:
- aplicar area.trabalhista na conversa;
- aplicar area.trabalhista no contato;
- registrar nota privada com motivo.
```

---

## 7. CRM Dentro da Tela do Chat

### 7.1 Painel lateral do contato

Adicionar uma seção "CRM Jurídico" no painel lateral da conversa.

Deve mostrar:

- Lead ou Cliente.
- Lifecycle.
- Responsável pelo contato.
- Área jurídica principal.
- Temperatura.
- Próxima ação.
- Documentos pendentes.
- Última nota importante.
- Botões rápidos:
  - Marcar como cliente.
  - Atribuir responsável.
  - Adicionar etiqueta.
  - Criar tarefa.
  - Pedir documento.

### 7.2 Lista de contatos

Adicionar colunas/filtros:

- Lead/Cliente.
- Lifecycle.
- Responsável.
- Área jurídica.
- Temperatura.
- Última conversa.
- Próxima ação.
- Documentos pendentes.

### 7.2.1 Importacao, exportacao e listas de contatos

O Core ja possui base para:

- importar contatos por CSV em `ContactsController#import` e `DataImportJob`;
- exportar contatos por CSV em `ContactsController#export` e `Account::ContactsExportJob`;
- filtrar contatos por payload avancado em `Contacts::FilterService`;
- salvar segmentos/listas em `CustomFilter` com `filter_type = contact`;
- criar campanhas SMS/WhatsApp por audiencia baseada em `Label`.

Melhorias necessarias para o fluxo juridico:

- No modal de importacao, permitir escolher/criar uma "Lista de origem" antes de subir o CSV.
- Ao importar uma planilha, aplicar automaticamente uma label de lista/campanha, por exemplo `lista_inss_maio_2026`.
- Aceitar colunas CRM no CSV: `relationship_status`, `lifecycle_stage`, `crm_owner_email`, `labels`, `source_list`, `legal_area`.
- Atualizar o CSV de exemplo para mostrar um caso real de planilha INSS.
- Exibir historico/importacoes recentes com status, total, rejeitados e link de erros.
- Permitir criar segmento salvo a partir da importacao, combinando lista + etiquetas + Lead/Cliente + responsavel.
- Fazer campanhas aceitarem tanto `Label` quanto `ContactSegment`/lista salva como audiencia.
- Mostrar contador estimado de contatos antes de disparar campanha.

Exemplo esperado:

1. Usuario sobe uma planilha "Leads INSS Maio".
2. O sistema cria/aplica a label visual "Lista INSS Maio" nos contatos importados.
3. O usuario cria ou reaproveita um segmento "INSS - leads novos".
4. Ao criar campanha WhatsApp/SMS, escolhe esse segmento/lista.
5. O disparo considera somente contatos daquela lista, sem misturar toda a base.

### 7.3 Lista de conversas

Mostrar sinais sem poluir:

- Badge Cliente/Lead.
- Ícone de responsável ausente.
- Ícone de documento pendente.
- Prioridade/risco.
- Área jurídica.

---

## 8. Tarefas e Próximas Ações

Usar recursos existentes do Chatwoot sempre que possível:

- notas privadas;
- snooze;
- assignee;
- labels;
- automações;
- mensagens internas.

Se for necessário um modelo novo, criar dentro do Core:

```ruby
CrmTask
- account_id
- contact_id
- conversation_id
- assignee_id
- title
- description
- due_at
- status
- source
```

Mas só criar `CrmTask` se as atividades existentes do Chatwoot não forem suficientes.

Primeira opção: evoluir a UI e o uso dos recursos já existentes.

---

## 9. Capitão Integrado ao CRM do Core

### 9.1 Problema atual

O Capitão conversa, mas ainda não usa um dossiê CRM completo.

Ele precisa saber:

- se é Lead ou Cliente;
- responsável pelo contato;
- labels do contato e da conversa;
- notas privadas relevantes;
- documentos enviados;
- áudios transcritos;
- imagens descritas/OCR;
- histórico recente;
- próxima ação pendente.

### 9.2 Serviço de contexto

Criar no Core:

```ruby
Captain::CrmContextBuilder
```

Responsável por montar:

```json
{
  "contact": {
    "id": 123,
    "name": "Maria",
    "relationship_status": "lead",
    "lifecycle_stage": "triage",
    "crm_owner": "Dra. Ana",
    "labels": ["area.trabalhista", "temp.quente"]
  },
  "conversation": {
    "id": 456,
    "assignee": "João",
    "priority": "high",
    "labels": ["risk.audiencia_marcada"]
  },
  "documents": {
    "pending": ["CTPS", "termo de rescisão"],
    "received": ["RG"]
  },
  "media": {
    "audio_transcriptions": [],
    "image_descriptions": [],
    "ocr_texts": []
  }
}
```

Esse contexto entra nos prompts do Captain e nas ferramentas.

### 9.3 Ferramentas do Capitão

Adicionar ou melhorar tools dentro do Core:

- `get_crm_context`
- `set_contact_relationship_status`
- `set_contact_lifecycle_stage`
- `assign_contact_owner`
- `add_label_to_contact`
- `add_label_to_conversation`
- `add_private_note`
- `register_document_request`
- `register_document_received`
- `handoff_with_crm_summary`

### 9.4 Regras

- O Capitão não inventa dados de CRM.
- O Capitão registra hipótese como nota se não houver certeza.
- O Capitão só marca cliente automaticamente se houver regra clara ou confirmação humana.
- O Capitão pode sugerir responsável, mas atribuição automática precisa seguir configuração.

---

## 10. Áudios no Capitão

### 10.1 O que existe no Core

O Core já possui:

- `Attachment` com `file_type: audio`;
- `Messages::AudioTranscriptionService`;
- `Messages::AudioTranscriptionJob`;
- `attachments.meta.transcribed_text`;
- `Message#content_for_llm`, que usa transcrição quando existe.

### 10.2 Problema

Se o ambiente usa OpenRouter para chat, Whisper não está disponível ali. Então o áudio não é transcrito ou não chega corretamente ao Capitão.

### 10.3 Solução correta dentro do Core

Separar o provedor de chat do provedor de transcrição.

Configurações propostas:

```env
AUDIO_TRANSCRIPTION_PROVIDER=openai
AUDIO_TRANSCRIPTION_MODEL=whisper-1
AUDIO_TRANSCRIPTION_API_KEY=...
```

ou:

```env
AUDIO_TRANSCRIPTION_PROVIDER=gemini
AUDIO_TRANSCRIPTION_MODEL=gemini-2.5-flash
```

No ChusteRM Core, as chaves operacionais ficam em `InstallationConfig`:

```env
CAPTAIN_MEDIA_AI_API_KEY=...
CAPTAIN_MEDIA_AI_MODEL=gemini-2.5-flash
CAPTAIN_MEDIA_AI_ENDPOINT=https://generativelanguage.googleapis.com/

CAPTAIN_AUDIO_TRANSCRIPTION_API_KEY=...
CAPTAIN_AUDIO_TRANSCRIPTION_MODEL=gemini-2.5-flash
CAPTAIN_AUDIO_TRANSCRIPTION_ENDPOINT=https://generativelanguage.googleapis.com/
```

Se essas chaves ficarem vazias, o Core tenta manter compatibilidade com as configurações antigas do Captain apenas quando o endpoint antigo for compatível com Gemini ou OpenAI direto. Assim, usar OpenRouter para chat não obriga áudio/imagem a passarem pelo OpenRouter.

### 10.4 Pipeline esperado

1. Mensagem de áudio chega.
2. `Attachment` é criado.
3. `Messages::AudioTranscriptionJob` roda.
4. Transcrição é salva em `attachment.meta["transcribed_text"]`.
5. Mensagem é reindexada.
6. `Message#content_for_llm` retorna o texto transcrito.
7. Capitão responde considerando o áudio.

### 10.5 UI

- Mostrar transcrição abaixo do áudio.
- Mostrar status quando ainda está processando.
- Se falhar, permitir "Tentar transcrever novamente".

---

## 11. Imagens e Documentos no Capitão

### 11.1 Problema

Imagens chegam ao chat, mas o Capitão nem sempre consegue ver:

- porque o modelo não tem visão;
- porque a URL local não é acessível pelo provedor;
- porque falta descrição/OCR salvo no Core.

### 11.2 Solução dentro do Core

Criar:

```ruby
Messages::MediaUnderstandingJob
Messages::ImageUnderstandingService
```

Para cada imagem/documento relevante:

- gerar descrição;
- extrair OCR quando houver texto;
- detectar tipo provável de documento;
- salvar em `attachment.meta`.

Campos em `Attachment#meta`:

```json
{
  "image_description": "...",
  "ocr_text": "...",
  "document_guess": "rg",
  "media_understanding_status": "processed"
}
```

### 11.3 Conteúdo para o Capitão

Atualizar `Message#content_for_llm` para incluir:

- transcrição de áudio;
- descrição de imagem;
- OCR;
- tipo provável do documento.

Exemplo:

```text
[Imagem enviada]
Descrição: foto de uma carteira de trabalho.
Texto extraído: ...
Tipo provável: CTPS.
```

### 11.4 UI

- Mostrar "Documento reconhecido: RG/CTPS/CNIS".
- Permitir marcar como correto/incorreto.
- Criar label documental automaticamente:
  - `doc.rg_recebido`
  - `doc.ctps_recebido`
  - `doc.documento_ilegivel`

---

## 12. Auditoria e Histórico

Criar histórico para mudanças importantes:

- Lead virou cliente.
- Lifecycle mudou.
- Responsável mudou.
- Label aplicada/removida.
- Capitão pediu documento.
- Documento foi reconhecido.
- Capitão fez handoff.

Pode usar audit log existente se estiver disponível no Core. Se não, criar tabela simples:

```ruby
crm_events
- account_id
- contact_id
- conversation_id
- actor_type
- actor_id
- event_type
- before
- after
- metadata
- created_at
```

---

## 13. Roadmap Dentro do Core

### Check-up operacional - 2026-05-05

Estado atual validado antes de seguir para as próximas fases:

- Stack Docker saudável: `core`, `sidekiq`, `evolution-api`, Postgres e Redis em execução.
- Migrations principais aplicadas: lifecycle/owner em `contacts`, metadados CRM em `labels` e estado de conversa do Captain.
- `Contact` já possui campos de CRM: `relationship_status`, `lifecycle_stage`, `crm_owner_id`, datas de mudança e origem do responsável.
- `Label` já possui governança CRM: `category`, `slug`, `scope`, `is_system` e `description`.
- Seed de labels jurídicas carregado: 41 labels categorizadas no ambiente atual, incluindo documentos pendentes, recebidos e ilegíveis.
- Captain v2 ativo na conta principal.
- Modelo atual do Capitão: Gemini via endpoint compatível com OpenAI.
- Áudio e mídia estão configurados com Gemini: transcrição ativa, modelo `gemini-2.5-flash`, processamento de mídia ativo.
- `core` e `sidekiq` compartilham `/app/storage`, evitando falha de leitura de anexos em jobs.
- Fluxo real da Dra. Juliana validado com texto e áudio: o Capitão continua a triagem sem encerrar automaticamente.
- Triagem CRM passa a reprocessar a conversa conforme novos dados chegam, com throttle curto, e sincroniza labels jurídicas no contato e na conversa.
- Labels conflitantes de área, temperatura e relacionamento são substituídas automaticamente para evitar múltiplas classificações incompatíveis.
- Tela de configuração de labels mostra categoria, slug e escopo, com filtro por categoria e edição desses metadados.
- Seletores de labels no atendimento e nas ações em massa agrupam por categoria e filtram por escopo (`contact`, `conversation`, `both`).
- Labels foram removidas do menu principal lateral e continuam disponiveis no chat/contato/CRM/filtros.
- Labels agora possuem nome visual humano via `display_title`, por exemplo `Temp Frio`, `Status Consulta Agendada` e `Doc RG Recebido`, mantendo `title` tecnico como `temp_frio`.
- OCR/descrição de imagem agora sincroniza labels documentais automaticamente, removendo pendências quando o documento correspondente é reconhecido como recebido.
- Contexto CRM do Capitão inclui o deal vinculado, responsável, status de documentos e próxima ação recomendada.
- Painel lateral do Capitão mostra a próxima ação do deal junto do link para o CRM.
- Backfill CRM executado na conta principal: 11 contatos processados e 10 normalizados com lifecycle/relacionamento/datas.
- Triagem CRM agora herda o assignee da conversa como responsável principal quando o contato ainda não tem `crm_owner_id`.
- Negócios abertos herdam o responsável principal do contato quando ainda estão sem owner.
- Lead quente sem responsável gera atividade pendente `Atribuir responsavel ao lead quente`, com prioridade e prazo conforme urgência/score.
- Lista e detalhe de contatos agora exibem resumo CRM com Lead/Cliente, etapa do lifecycle e responsável principal.
- Handoff do Capitão para humano agora cria nota privada com resumo CRM determinístico: motivo, contato, etapa, responsável, deal, documentos, mídia, etiquetas e próxima ação.
- UI de mensagens agora exibe status de mídia do Capitão/Gemini em áudio e imagem: transcrevendo, áudio transcrito, analisando mídia, documento reconhecido, falha ou mídia não analisada.
- Roteamento por área jurídica configurável no inbox do Capitão (`routing_config.area_owner_ids`) aplicado quando o contato ainda não tem responsável principal.
- Modo Gemini compatível agora recebe o dossiê CRM completo no prompt e executa sincronização determinística no Core após a resposta: triagem, deal, etiquetas, score, responsável e estado do Capitão sem depender de tool-calls OpenAI.
- Handoff por `conversation_handoff` também cria nota privada com resumo CRM, igual ao handoff por ferramenta.
- Atividades CRM ganharam ação de adiar/snooze, reaproveitando `due_at` e `reminder_at`.
- Serviços fora do Core foram revisados: `services/crm-service` e `services/crm-ui` agora estão documentados como legado/apoio técnico, sem autoridade sobre contatos, deals, labels, lifecycle ou Capitão.
- Check-up operacional `crm:health_check` criado no Core para auditar contatos, deals, labels, mídia, atividades e estado do Capitão por conta.
- Painel principal do CRM agora mostra o resumo de saúde CRM/Captain com contatos sem responsável, leads quentes sem responsável, mídia parada e tarefas vencidas.
- Job recorrente `Crm::HealthCheckJob` agenda auditoria diária e cria alerta quando a saúde do CRM exigir atenção.

Pontos de atenção:

- Com Gemini via endpoint compatível com OpenAI, tools/handoffs nativos do agent runner continuam protegidos contra erros de `thought_signature`, mas ações essenciais de CRM rodam por execução determinística no Core.
- O Evolution ainda registra eventos `Bad MAC`/`No matching sessions` em alguns pacotes do WhatsApp. Como o atendimento testado funcionou, não bloqueia o CRM, mas deve ser monitorado se alguma mensagem sumir ou atrasar.
- Há jobs antigos no `DeadSet` do Sidekiq. As filas ativas estão zeradas, então não bloqueia a próxima fase; convém limpar ou auditar depois.
- `crm-service` ainda pode subir pelo compose como apoio técnico (`4003`), mas não é fonte primária do CRM. `crm-ui` fica apenas no profile legado `legacy-crm-ui` e não deve ocupar `3001` no uso normal.

### Fase 0 - Correção de rumo

- [x] Marcar `services/crm-service` e `services/crm-ui` como legado/protótipo no plano.
- [x] Garantir que novas melhorias de CRM sejam feitas em `core/`.
- [x] Remover/limpar o painel paralelo que estava ocupando `http://localhost:3001/`.
- [x] Revisar alterações já feitas fora do Core e decidir se serão revertidas ou apenas ignoradas.

### Fase 1 - Contato CRM no Core

- [x] Migration em `core/db/migrate` para lifecycle e owner em `contacts`.
- [x] Atualizar model `Contact`.
- [x] Adicionar service `Crm::ContactLifecycleManager`.
- [x] Adicionar eventos/auditoria para mudanças de lifecycle, Lead/Cliente e responsável.
- [x] Backfill de contatos existentes.
- [x] UI no painel lateral da conversa.
- [x] Filtros CRM na lista de contatos.
- [x] Colunas/resumo CRM na lista/detalhe do contato.

### Fase 2 - Labels governadas

- [x] Evoluir `Label` ou criar `crm_label_settings`.
- [x] Seed de labels jurídicas padrão.
- [x] UI de labels por categoria.
- [x] Sincronizar labels de contato e conversa.
- [x] Atualizar ferramentas do Capitão para usar slugs padronizados.
- [x] Agrupar labels por categoria nos seletores laterais do chat/contato.
- [x] Automatizar labels documentais recebidas a partir de OCR/descrição de imagem.
- [x] Ocultar labels juridicas sistemicas do menu principal lateral.
- [x] Remover a navegacao por labels do menu principal lateral de conversas e contatos.
- [x] Adicionar nome visual humano para labels, sem quebrar `title`/`slug` tecnicos.

### Fase 3 - Responsável pelo contato

- [x] Campo `crm_owner_id`.
- [x] UI para atribuir responsável.
- [x] Filtros "Meus contatos" e "Sem responsável".
- [x] Regra por assignee: conversa atribuída preenche o responsável principal do contato quando vazio.
- [x] Regra por área jurídica.
- [x] Alerta de lead quente sem responsável.

### Fase 4 - Capitão com contexto CRM

- [x] Criar `Captain::CrmContextBuilder`.
- [x] Injetar contexto nos prompts.
- [x] Criar tools de CRM dentro do Core.
- [x] Incluir deal, responsável, documentos e próxima ação no contexto CRM do Capitão.
- [x] Handoff com resumo CRM.
- [x] Testar com fluxo da Dra. Juliana.
- [x] Reativar ações essenciais do Capitão em modo compatível com Gemini por execução determinística no Core, sem depender de OpenAI embeddings/tool-calls instáveis.

### Fase 5 - Áudio e imagem

- [x] Corrigir provider de transcrição/mídia separado do provider de chat.
- [x] Garantir `AudioTranscriptionJob` funcionando.
- [x] Criar `MediaUnderstandingJob`.
- [x] Salvar descrição/OCR em `Attachment#meta`.
- [x] Incluir mídia em `Message#content_for_llm`.
- [x] Fazer o Capitão aguardar brevemente áudio/imagem/documento antes de responder.
- [x] UI de status de processamento.

### Fase 6 - Documentos e próximas ações

- [x] Reconhecimento simples de documentos.
- [x] Labels documentais automáticas.
- [x] Próxima ação no painel do contato.
- [x] Tarefas ou uso melhorado de notas/snooze.

### Fase 7 - Operação e qualidade

- [x] Documentar serviços legados fora do Core como apoio técnico, não CRM oficial.
- [x] Criar check-up operacional de CRM/Captain via rake task.
- [x] Medir contatos sem Lead/Cliente/lifecycle/responsável.
- [x] Medir leads quentes sem responsável.
- [x] Medir labels sistêmicas visíveis no menu principal.
- [x] Medir mídia parada em processamento.
- [x] Medir atividades pendentes, vencidas e do dia.
- [x] Criar painel visual dessas métricas dentro do CRM.
- [x] Criar alerta recorrente para saúde `attention`.

### Fase 8 - Contatos ricos, listas e segmentacao de campanha

- [x] Melhorar modal de importacao para permitir nome da lista, etiquetas padrao, area juridica, Lead/Cliente e responsavel.
- [x] Atualizar processamento CSV para aceitar `labels`, `source_list`, `relationship_status`, `lifecycle_stage`, `legal_area` e `crm_owner_email`.
- [x] Criar/aplicar label de lista automaticamente em todos os contatos importados.
- [x] Atualizar CSV exemplo para um modelo juridico, incluindo uma lista INSS.
- [x] Mostrar importacoes recentes na tela de contatos com status, totais e falhas.
- [x] Adicionar filtros avancados de contato para lifecycle, responsavel, area juridica, origem/lista e etiquetas com nome visual.
- [x] Melhorar visual da pagina de contatos para segmentacao rapida e leitura CRM.
- [x] Permitir salvar segmentos/listas de contatos a partir de filtros aplicados.
- [x] Permitir campanha SMS/WhatsApp para lista importada via label criada automaticamente na importacao.
- [x] Permitir campanhas SMS/WhatsApp por segmento/lista salva, alem de etiquetas.
- [x] Mostrar contador/previsao de audiencia antes de criar campanha.
- [x] Garantir que Capitão enxergue lista de origem, etiquetas e segmento do contato no contexto CRM.

### Check-up operacional - 2026-05-05 - Fase 8

- [x] `Campaigns::AudienceResolver` validado com audiencia por `ContactSegment`/lista salva.
- [x] Rota `POST /api/v1/accounts/:account_id/campaigns/audience_count` reconhecida pelo Core.
- [x] Rota `GET /api/v1/accounts/:account_id/contacts/imports` reconhecida pelo Core.
- [x] Filtros `source_list` e `legal_area` copiados para a imagem Docker via `lib/filters/filter_keys.yml`.
- [x] Campanhas SMS/WhatsApp registram estatisticas iniciais de `total`, `sent`, `skipped` e `failed`.
- [x] `core` e `sidekiq` reconstruidos e saudaveis em `http://localhost:3010`.

### Refinamento UI/UX de contatos - 2026-05-05

- [x] Lista de contatos reorganizada com painel unico de listas e filtros CRM.
- [x] Atalhos rapidos para `Todos os contatos`, `Lead`, `Cliente`, `Sem responsavel` e `Meus contatos`.
- [x] Cards de contato exibem Lead/Cliente como controle editavel, etapa do lifecycle e responsavel.
- [x] Detalhe do contato reorganizado em blocos: identidade, CRM juridico, dados editaveis e exclusao.
- [x] Chat/painel lateral do CRM usa o mesmo controle Lead/Cliente da pagina de contatos.
- [x] Responsividade ajustada para lista e detalhe, com largura util maior em desktop e menos quebra em telas menores.
- [x] `pnpm exec eslint` passou nos componentes Vue alterados.
- [x] `core` e `sidekiq` reconstruidos e saudaveis em `http://localhost:3010`.

### Check-up operacional - 2026-05-05

- [x] `core` e `sidekiq` reconstruidos e saudaveis em `http://localhost:3010`.
- [x] Rota `GET /api/v1/accounts/:account_id/crm/health` reconhecida pelo Core.
- [x] `crm:health_check ACCOUNT_ID=1` executado com `status: ok`.
- [x] `Crm::HealthCheckJob` executado em transacao sem criar alerta indevido quando a saude esta `ok`.
- [x] `Crm::StaleDetectorJob` corrigido para criar retomada como `follow_up`, mantendo compatibilidade com os tipos validos de atividade.
- [x] `Crm::StaleDetectorJob` validado em transacao com rollback, criando tarefas de retomada sem alterar dados reais.

---

## 14. Critérios de Aceite

### Lead/Cliente

- O contato mostra claramente Lead ou Cliente dentro do Chatwoot.
- Um humano consegue marcar "Virou cliente".
- A mudança fica registrada.
- O Capitão sabe se é Lead ou Cliente.

### Responsável

- Contato pode ter responsável principal.
- Conversa pode continuar com assignee próprio.
- Filtros mostram contatos sem responsável.
- Lead quente sem responsável gera alerta.

### Etiquetas

- Labels jurídicas ficam padronizadas.
- Capitão usa labels existentes.
- Labels aparecem agrupadas por categoria.
- Labels nao poluem o menu principal lateral.
- Labels exibem nomes humanos no chat/CRM, sem perder slugs tecnicos.
- Filtros por área, temperatura, documento e risco funcionam.

### Áudio

- Áudio recebido é transcrito.
- Transcrição aparece no chat.
- Capitão responde considerando o áudio.

### Imagem/documento

- Imagem recebe descrição/OCR quando possível.
- Documento é sugerido como RG, CTPS, CNIS etc.
- Capitão consegue usar esse contexto.

---

## 15. Métricas

- % de contatos com Lead/Cliente definido.
- % de contatos com responsável.
- % de leads quentes sem responsável.
- % de conversas com área jurídica identificada.
- % de áudios transcritos com sucesso.
- % de imagens/documentos processados com sucesso.
- Tempo médio de triagem.
- Tempo até handoff humano.
- Conversão Lead -> Cliente.
- % de contatos com próxima ação definida.

---

## 16. Estudo Profissional da Kommo e Aplicacao no ChusteRM

### 16.1 Objetivo do estudo

Este estudo usa a Kommo como benchmark de CRM conversacional, nao para copiar o produto inteiro, mas para identificar recursos que fazem sentido dentro do ChusteRM Core, respeitando a decisao principal deste plano:

- o CRM oficial continua sendo o fork do Chatwoot em `core/`;
- chat, contato, negocio/deal, etiquetas, anexos e Capitao precisam estar no mesmo fluxo;
- o foco do ChusteRM e juridico, entao recursos de e-commerce ou vendas genericas so entram se ajudarem atendimento, triagem, conversao e gestao de clientes.

Fontes oficiais consultadas em 2026-05-05:

- Product overview: https://www.kommo.com/product-overview/
- CRM knowledge base: https://www.kommo.com/support/crm/
- Pricing/features: https://www.kommo.com/buy/tariff/
- WhatsApp CRM: https://www.kommo.com/whatsapp/
- Salesbot: https://www.kommo.com/salesbot/
- Pipeline triggers: https://www.kommo.com/support/crm/pipeline-triggers/
- Salesbot triggers: https://www.kommo.com/support/crm/salesbot-triggers/
- Importacao: https://www.kommo.com/support/crm/how-to-import/
- Campos customizados: https://www.kommo.com/support/crm/fields/
- Perfil do lead: https://www.kommo.com/support/crm/lead-profile/
- Broadcasting: https://www.kommo.com/support/crm/broadcasting
- Estatisticas de broadcast: https://www.kommo.com/support/crm/broadcasting-stats/
- AI Agent: https://www.kommo.com/support/crm/kommo-ai-agent/
- Qualificacao com AI Agent: https://www.kommo.com/support/crm/ai-agent-lead-qualification/
- Copilot/Analyst mode: https://www.kommo.com/support/crm/analyst-mode-overview/
- Integracoes: https://www.kommo.com/integrations/

### 16.2 O que a Kommo faz bem

#### CRM conversacional por natureza

A Kommo se posiciona como CRM conversacional. A logica principal e simples:

- inbox unificado para WhatsApp, Instagram, Messenger, TikTok, Telegram, email, live chat e outros canais;
- historico do cliente em um perfil unico;
- conversa, tarefas, notas, emails, chamadas, tags, responsavel e etapa do funil no mesmo lugar;
- foco em responder rapido e mover o lead pelo processo sem sair do chat.

Aplicacao no ChusteRM:

- Este ponto confirma que a decisao de evoluir o CRM dentro do Chatwoot esta correta.
- O ChusteRM ja parte de uma base melhor para chat do que CRMs tradicionais.
- A prioridade nao deve ser criar "outro CRM", e sim enriquecer a tela de conversa e a ficha do contato.

#### Tres modos principais de trabalho

A Kommo trabalha com visoes como:

- pipeline/kanban para acompanhar oportunidades;
- lista para operacao, segmentacao e edicao;
- inbox para atendimento conversacional.

Aplicacao no ChusteRM:

- O ChusteRM precisa ter tres portas de entrada igualmente fortes:
  - `Conversas`: atendimento e Capitao.
  - `Contatos`: base, listas, importacao, filtros, segmentos.
  - `CRM/Deals`: funil juridico, oportunidades, proximas acoes e saude da operacao.

#### Perfil rico de lead/cliente

No perfil de lead da Kommo ficam reunidos:

- contato e empresa;
- responsavel;
- etapa do funil;
- valor;
- tags;
- tarefas;
- notas;
- mensagens;
- emails;
- chamadas/gravacoes;
- produtos ou itens relacionados;
- estatisticas do lead.

Aplicacao no ChusteRM:

- A ficha central deve ser o `Contact`, mas o `CrmDeal` precisa aparecer junto quando houver oportunidade ativa.
- O contato juridico deve mostrar:
  - Lead/Cliente.
  - Responsavel CRM.
  - Area juridica.
  - Origem/lista.
  - Etiquetas.
  - Documentos pendentes/recebidos.
  - Conversas recentes.
  - Deals/casos vinculados.
  - Tarefas/proxima acao.
  - Resumo do Capitao.

#### Campos customizados e campos obrigatorios por etapa

A Kommo permite campos customizados em lead, contato, empresa e cliente, com tipos como texto, numero, select, multiselect, data, checkbox, endereco, pessoa juridica e nome legal. Um ponto importante: campos podem ser obrigatorios a partir de uma etapa do pipeline.

Aplicacao no ChusteRM:

- O ChusteRM ja usa `custom_attributes`, mas precisa de governanca visual e regras por etapa.
- Para juridico, isso vira:
  - em `Triagem`: area juridica e resumo do problema obrigatorios;
  - em `Consulta Agendada`: data/hora e responsavel obrigatorios;
  - em `Aguardando Documento`: lista de documentos pendentes obrigatoria;
  - em `Cliente`: CPF/CNPJ, contrato/procuracao ou identificador interno obrigatorios conforme area.

#### Importacao madura de dados

A Kommo importa contatos, leads, clientes, empresas, campos customizados, notas e catalogos. O fluxo inclui planilha/Google Sheets, mapeamento de colunas, aplicacao de tags e atualizacao de dados existentes.

Aplicacao no ChusteRM:

- A Fase 8 ja iniciou o caminho certo.
- Proximo nivel necessario:
  - tela de mapeamento de colunas antes de importar;
  - preview das primeiras linhas;
  - deteccao de duplicados;
  - escolha entre atualizar, ignorar ou criar novo;
  - relatorio de erros;
  - historico de importacoes;
  - opcao de criar segmento salvo automaticamente apos a importacao.

#### Automacoes por pipeline

A Kommo tem automacoes acopladas aos estagios do funil, como:

- rodar bot;
- criar tarefa;
- criar lead;
- enviar email;
- enviar webhook;
- mudar etapa;
- adicionar/remover tags;
- concluir tarefas;
- gerar formulario;
- trocar responsavel;
- alterar campos;
- apagar arquivos conforme regra.

Aplicacao no ChusteRM:

- O ChusteRM precisa de um motor simples de automacoes CRM dentro do Core.
- Nao precisa comecar com um construtor visual completo.
- Comecar com automacoes juridicas configuraveis:
  - ao entrar em `qualified_lead`, criar tarefa de contato humano;
  - ao identificar `area_inss`, atribuir responsavel por regra;
  - ao reconhecer `doc.rg_recebido`, remover `doc.rg_pendente`;
  - ao ficar parado por X dias, criar retomada;
  - ao virar `consultation_scheduled`, enviar confirmacao;
  - ao marcar `lost`, pedir motivo de perda.

#### Salesbot e bots sem codigo

A Kommo tem Salesbot no-code com gatilhos por etapa, comportamento, tempo, tags e responsavel. O bot coleta informacoes, responde, aplica tags, move leads, cria tarefas e pode ser acionado por regras.

Aplicacao no ChusteRM:

- O Capitao deve ser mais inteligente que um Salesbot, mas precisa de "trilhos" previsiveis.
- Criar um modulo de Playbooks do Capitao:
  - playbook INSS;
  - playbook Trabalhista;
  - playbook Familia;
  - playbook Consulta;
  - playbook Pos-atendimento.
- Cada playbook define:
  - perguntas obrigatorias;
  - documentos esperados;
  - etiquetas que pode aplicar;
  - etapa para mover;
  - quando passar para humano;
  - mensagens prontas aprovadas pelo escritorio.

#### IA aplicada ao CRM

A Kommo tem dois caminhos de IA:

- AI Agent: atende conversas, usa fontes de conhecimento, persona, regras e acoes. Pode qualificar leads, coletar dados, aplicar tags, preencher campos, mudar etapa, transferir para humano e criar tarefa.
- Copilot/Analyst: resume, sugere respostas, ajuda a completar informacoes e permite perguntas analiticas sobre dados da conta.

Aplicacao no ChusteRM:

- O Capitao ja esta no caminho do AI Agent.
- Faltam duas camadas:
  - `Fontes de conhecimento` versionadas: servicos do escritorio, perguntas frequentes, regras de atendimento, documentos por area.
  - `Modo Analista`: perguntas naturais sobre a operacao, por exemplo "quantos leads INSS entraram esta semana?", "quais leads quentes estao sem responsavel?", "qual campanha trouxe mais consultas?".

#### Broadcasts/campanhas com estatisticas

A Kommo permite broadcast por canais como WhatsApp, Instagram, Telegram e outros, com selecao de publico por filtros/tags/etapas, agendamento, templates e estatisticas como enviado, entregue, lido, falhou e respondeu.

Aplicacao no ChusteRM:

- A campanha por lista/etiqueta e essencial para o caso de uso de planilhas INSS.
- O proximo passo nao e apenas disparar; e medir:
  - audiencia prevista;
  - enviados;
  - entregues;
  - lidos;
  - respostas;
  - falhas;
  - custo estimado quando for WhatsApp oficial;
  - conversoes geradas: conversa, consulta, cliente.

#### Dashboards e saude da operacao

A Kommo oferece dashboard customizavel, widgets, estatisticas, ROI, NPS e analise de performance.

Aplicacao no ChusteRM:

- O painel de saude CRM ja criado e um bom primeiro passo.
- Precisa evoluir para:
  - funil por area juridica;
  - conversao Lead -> Consulta -> Cliente;
  - tempo medio por etapa;
  - origem/lista/campanha com melhor conversao;
  - produtividade por responsavel;
  - gargalos: sem responsavel, sem proxima acao, aguardando documento, parado.

#### Ecossistema de integracoes

A Kommo tem marketplace forte: WhatsApp, Instagram, TikTok, Facebook, Telegram, email, telefonia, Google Sheets, Google Calendar, formulários, pagamentos, documentos, e-commerce, BI e automacao externa.

Aplicacao no ChusteRM:

- O ChusteRM deve priorizar integracoes juridicas e operacionais:
  - Google Calendar para consultas;
  - Google Sheets/importacao recorrente;
  - Google Drive/Docs para documentos e contratos;
  - Meta/WhatsApp oficial;
  - telefonia/call log no futuro;
  - webhooks de entrada e saida;
  - API publica documentada para integracoes com sites/formularios.

### 16.3 O que nao vale copiar da Kommo agora

Nem tudo da Kommo e prioridade para o ChusteRM:

- E-commerce/produtos/catalogos: so faz sentido se virar "servicos juridicos" ou pacotes de atendimento.
- Pagamentos integrados: importante depois, mas nao antes de funil, contatos e documentos estarem maduros.
- Marketplace amplo: antes precisamos estabilizar API, webhooks e objetos CRM internos.
- Automacao visual complexa: alto custo de desenvolvimento; melhor comecar com playbooks e regras juridicas.
- Multiplos canais alem do WhatsApp: interessante, mas o foco imediato deve continuar WhatsApp + chat + email se ja estiver disponivel.

### 16.4 Gaps do ChusteRM comparado a Kommo

| Area | Kommo | ChusteRM hoje | Acao recomendada |
|---|---|---|---|
| Inbox conversacional | Forte | Forte por heranca Chatwoot | Manter como centro do produto |
| Perfil rico | Forte no lead card | Em evolucao | Enriquecer contato/deal no chat e contatos |
| Importacao | Mapeamento, tags, atualizacao | Importacao rica iniciada | Adicionar preview, mapeamento, duplicados e historico |
| Segmentos/listas | Filtros e tags | Parcial via labels/filtros | Salvar segmentos e usar em campanhas |
| Campanhas | Broadcast com agenda e stats | Parcial | Adicionar audiencia prevista, agenda e metricas |
| Automacoes | Digital pipeline e Salesbot | Parcial/deterministico | Criar automacoes juridicas por etapa |
| IA | AI Agent + Copilot + Analyst | Capitao com CRM/midia | Adicionar fontes de conhecimento, playbooks e modo analista |
| Campos obrigatorios por etapa | Existe | Nao estruturado | Criar regras por etapa juridica |
| Dashboard | Customizavel/ROI/NPS | Saude CRM inicial | Criar dashboards de funil, origem e conversao |
| Integracoes | Marketplace grande | Pontual | Priorizar Calendar, Drive, Sheets, webhooks e WhatsApp oficial |

### 16.5 Recomendacoes prioritarias para o ChusteRM

#### Prioridade 1 - Contatos, listas e campanhas no nivel Kommo

Esta e a necessidade mais conectada ao pedido atual do usuario.

Implementar:

- Historico de importacoes com status, totais, falhas e arquivo original.
- Preview e mapeamento de colunas antes de confirmar importacao.
- Politica de duplicados: atualizar existente, ignorar ou criar novo.
- Segmento salvo a partir da importacao.
- Segmento salvo a partir de filtros.
- Campanha WhatsApp/SMS por segmento salvo, nao apenas por label.
- Contador de audiencia antes do disparo.
- Estatisticas de campanha: enviado, entregue, lido, respondeu, falhou.

Resultado esperado:

- O usuario importa uma planilha "Leads INSS Maio".
- O ChusteRM cria a lista/segmento.
- O usuario filtra por INSS + Lead + sem consulta marcada.
- O usuario dispara campanha somente para essa lista.
- O gestor mede resposta e conversao da lista.

#### Prioridade 2 - Playbooks juridicos do Capitao

Inspirado no Salesbot, mas adaptado ao juridico e com IA.

Implementar:

- Cadastro simples de playbooks por area.
- Perguntas obrigatorias por area.
- Documentos esperados por area.
- Regras de handoff.
- Mensagens aprovadas.
- Acoes permitidas: aplicar etiqueta, atualizar etapa, criar tarefa, pedir documento, atribuir responsavel.

Exemplo INSS:

- perguntar beneficio/objetivo;
- perguntar se ja houve negativa;
- pedir RG, CPF, comprovante, CNIS ou carta do INSS conforme caso;
- classificar area como INSS/previdenciario;
- marcar temperatura conforme urgencia;
- criar tarefa se o lead for quente ou se enviar documento.

#### Prioridade 3 - Funil juridico visual

Inspirado no pipeline da Kommo, mas com etapas juridicas.

Implementar:

- Kanban de `CrmDeal`.
- Etapas configuraveis por escritorio.
- Regras de entrada/saida por etapa.
- Campos obrigatorios por etapa.
- Indicador de proxima acao.
- Alerta de card parado.
- Acoes rapidas: atribuir, agendar, pedir documento, marcar cliente, perder lead.

Etapas iniciais sugeridas:

- Novo lead.
- Triagem Capitao.
- Aguardando documento.
- Consulta agendada.
- Proposta/contrato.
- Cliente/caso ativo.
- Perdido/desqualificado.

#### Prioridade 4 - Knowledge base do Capitao

Inspirado nas Sources da Kommo AI Agent.

Implementar:

- Fontes por escritorio/conta.
- Fontes por area juridica.
- Versionamento simples.
- Status ativo/inativo.
- Teste do Capitao antes de publicar.
- Registro de qual fonte foi usada na resposta.

Tipos de fonte:

- FAQ do escritorio.
- Servicos juridicos.
- Horarios, endereco e politicas.
- Documentos necessarios por area.
- Scripts de atendimento aprovados.
- Regras de handoff.

#### Prioridade 5 - Modo Analista CRM

Inspirado no Analyst mode da Kommo.

Implementar consultas em linguagem natural sobre dados do Core:

- "Quantos leads INSS entraram essa semana?"
- "Quais leads quentes estao sem responsavel?"
- "Qual lista importada mais gerou respostas?"
- "Quais contatos estao aguardando documento ha mais de 3 dias?"
- "Qual responsavel converte mais consulta em cliente?"

Inicio simples:

- Criar endpoints agregados de metricas.
- Criar ferramenta do Capitao/Copilot interno que consulta esses endpoints.
- Responder com tabelas simples e links para filtros prontos.

### 16.6 Nova Fase 9 - Benchmark Kommo aplicado ao ChusteRM

- [x] Criar historico visual de importacoes com status, totais, falhas e download de erros.
- [x] Criar preview inicial de colunas e primeiras linhas na importacao de contatos.
- [x] Criar mapeamento avancado de colunas antes de confirmar importacao.
- [x] Implementar politica de duplicados na importacao: atualizar existente ou ignorar duplicado.
- [x] Implementar politica de duplicados para criar novo contato mesmo quando houver duplicidade, preservando dados originais em atributos adicionais.
- [x] Permitir salvar segmento a partir de filtros de contatos.
- [x] Permitir campanhas por segmento salvo, alem de etiquetas.
- [x] Mostrar contador de audiencia antes de criar campanha.
- [x] Criar estatisticas iniciais de campanha: total, enviado, ignorado e falhou.
- [x] Criar tracking avancado de campanha: entregue, lido, respondeu e conversao por webhook/provedor.
- [x] Criar Kanban de deals juridicos com etapas configuraveis.
- [x] Criar campos obrigatorios por etapa do funil juridico.
- [x] Criar automacoes juridicas por etapa: tarefa, etiqueta, responsavel, mensagem e webhook.
- [x] Criar Playbooks do Capitao por area juridica.
- [x] Criar Knowledge Base do Capitao com fontes versionadas.
- [x] Criar modo Analista CRM inicial para perguntas em linguagem natural sobre contatos, listas, campanhas e funil.
- [x] Criar dashboards de conversao por area, funil, campanha inicial e responsavel.
- [ ] Priorizar integracoes Google Calendar, Google Sheets/Drive, webhooks e WhatsApp oficial.

### Check-up operacional - 2026-05-05 - Fase 9

- [x] Rota `POST /api/v1/accounts/:account_id/crm/analyst/ask` reconhecida pelo Core.
- [x] `Crm::AnalystService` validado com perguntas sobre leads quentes sem responsavel, leads INSS, listas importadas e campanhas recentes.
- [x] Tela de metricas do CRM recebeu bloco "Analista CRM" com exemplos de perguntas.
- [x] Politica `create_new` de duplicados validada: novo contato criado sem violar unicidade e dados originais preservados em `additional_attributes`.
- [x] Campos obrigatorios por etapa validados em `Crm::DealMover`: movimento bloqueia quando falta campo e permite apos preenchimento.
- [x] `crm:health_check ACCOUNT_ID=1` executado com `status: ok` apos rebuild final.
- [x] Importacao de contatos recebeu mapeamento avancado de colunas: campos padrao do CRM, colunas ignoradas e atributos customizados.
- [x] Campanhas receberam tabela `campaign_delivery_events`, endpoint `track_event`, tracking automatico de respostas e conversoes por deal ganho.
- [x] Capitao recebeu `Captain::Playbook`, seed inicial por area juridica e playbooks dentro do `Captain::CrmContextBuilder`.
- [x] Knowledge Base do Capitao recebeu `Captain::DocumentVersion`, snapshots automaticos e endpoints de consulta de versoes.

### Check-up visual e operacional - documento Kommo/SocialHub - 2026-05-05

O arquivo `docs/projeto_melhorias_chatwoot_fork_socialhub_kommo (1).md` foi revisado contra a implementacao atual do ChusteRM Core. A leitura confirma que o produto ja tem boa parte da base tecnica, mas ainda precisava de uma camada operacional mais clara para o usuario perceber valor real no dia a dia.

#### Melhorias iniciadas nesta rodada

- [x] Tela de Atividades transformada em agenda CRM com KPIs, filtros por status/data/tipo/prioridade, busca e acoes rapidas de concluir ou adiar.
- [x] API de Atividades enriquecida com filtros por status, prioridade, periodo, responsavel e retorno serializado de contato, deal, etapa, owner e assignee.
- [x] Tela de Relatorios CRM reorganizada como painel executivo com filtros, KPIs, insights, funil, distribuicao por area, urgencia e prioridade de atividades.
- [x] Tela de Templates de Checklist refeita com resumo operacional, busca, filtros por tipo de caso e area juridica, preview de itens e modal mais organizado.
- [x] Tela de Automacoes refeita com resumo de regras, filtros por status/etapa, leitura clara de gatilho -> atividade gerada e edicao mais profissional.
- [x] Tela de Cadencias recebeu filtros por busca/status/canal e ajuste visual dos selects para evitar quebra de UI.
- [x] Kanban do CRM recebeu renomeacao inline no card do lead.
- [x] Kanban passou a exibir telefone do contato no card e buscar por telefone normalizado nos dados carregados.
- [x] Kanban recebeu selecao em lote e movimentacao de varios leads para outra etapa.
- [x] API de deals passou a serializar telefone/e-mail do contato e aceitar busca por titulo, contato, e-mail e telefone normalizado.
- [x] Validacao executada: ESLint, Prettier, sintaxe Ruby, build Vite e reinicio dos servicos `core` e `core-vite`.

#### Pendencias P0 que seguem abertas no documento Kommo/SocialHub

- [x] Renomeacao inline do lead direto no card do Kanban.
- [x] Busca por telefone normalizado/parcial no pipeline para os dados carregados e no endpoint de deals.
- [x] Acoes em lote no Kanban/lista: mover etapa, arquivar, descartar spam/invalido/duplicado/nao lead, alterar origem, atribuir responsavel e aplicar etiqueta.
- [x] Origem do lead como dropdown operacional no Kanban/drawer, com `source_detail` para campanha, anuncio, planilha, URL ou observacao.
- [x] Status operacional `Cliente Base`, `Cliente Convertido`, `Retorno de Cliente`, spam, invalido, duplicado, nao lead e arquivado no funil e nos relatorios.
- [x] Descarte rapido no card do lead com motivo padronizado, preservando metricas e auditoria.
- [x] Sidebar CRM dentro da conversa com criar/vincular lead, etiquetas do contato, responsavel do relacionamento, responsavel por responder, status, origem e criacao de tarefa.
- [x] Ficha 360 do lead com historico completo de mensagens, anexos, tarefas, notas, eventos, campanhas, etiquetas do contato/atendimento e delegacao do responsavel por responder.
- [x] Relatorios especificos de saneamento: origem, status operacional, clientes da base e descartes iniciais no painel de CRM.

#### Check-up operacional - P0 Kommo/SocialHub - 2026-05-05

- [x] Migration `20260505000011` aplicada no Core com campos operacionais em `crm_deals`: `operational_status`, `source_detail`, `disposition_reason`, `disposition_note`, `disposed_at` e `archived_at`.
- [x] `CrmDeal` ganhou metodos auditados para arquivar, descartar, marcar Cliente Base e reabrir sem apagar historico.
- [x] API `POST /api/v1/accounts/:account_id/crm/deals/bulk_action` validada com acoes de mover, descartar, arquivar, Cliente Base, origem, responsavel e etiqueta.
- [x] Cards do Kanban exibem status operacional/origem e possuem atalhos de descarte e Cliente Base.
- [x] Sidebar do atendimento passou a conectar Chat, Contato e CRM: relacionamento Lead/Cliente, owner CRM, atendente responsavel, etiquetas sincronizadas, lead vinculado e tarefa contextual.
- [x] Ficha 360 do lead passou a consumir dados detalhados do Core: contato, conversa, ultimas mensagens, anexos, eventos de campanha, atividades, auditoria e dados LGPD.
- [x] Tela da ficha 360 recebeu abas operacionais, labels humanizadas e interligadas com contato/atendimento, bloco de responsaveis e opcao de delegar quem responde o atendimento.
- [x] Build Vite, ESLint, Prettier, sintaxe Ruby, rebuild Docker `core/sidekiq`, smoke HTTP e logs do Rails validados.

Com isso, o P0 Kommo/SocialHub deixa de ser apenas base tecnica e passa a aparecer em telas operacionais: limpar o funil, reduzir cliques, preservar metricas e consultar a ficha completa do lead dentro do proprio ChusteRM.

### 16.7 Conclusao do benchmark

A Kommo confirma a tese central do ChusteRM: o CRM mais forte para este projeto nao e um CRM separado do atendimento, mas um CRM conversacional onde cada mensagem alimenta contato, funil, tarefa, campanha e IA.

O diferencial do ChusteRM deve ser ir alem da Kommo no nicho juridico:

- entender audio, imagem e documentos;
- classificar area juridica;
- conduzir triagem com Capitao;
- pedir documentos corretos;
- criar tarefas e proximas acoes;
- mostrar contexto juridico no chat;
- segmentar contatos por lista, area, status e campanha;
- transformar WhatsApp em canal de captacao, triagem e relacionamento.

## 17. Resumo Executivo

O plano correto é:

1. Evoluir o **ChusteRM Core**.
2. Usar `Contact`, `Conversation`, `Label`, `Attachment` e `Captain` do próprio fork.
3. Adicionar Lead/Cliente, lifecycle e responsável no contato.
4. Melhorar labels existentes, com categorias e slugs.
5. Fazer o Capitão ler e escrever no CRM do Core.
6. Corrigir áudio e imagem no pipeline de mensagens do Core.
7. Não transformar `services/crm-service` em CRM oficial.

8. Usar o benchmark da Kommo para priorizar importacao/segmentos, campanhas com metricas, funil visual, playbooks do Capitao, knowledge base e modo analista.

## 18. Checklist UI/UX do CRM - 2026-05-05

Rodada de ajustes aplicada nas principais paginas do CRM para corrigir quebras visuais, overflow horizontal, campos espremidos e controles pouco responsivos.

- [x] Pipeline: filtros, busca, bulk actions, header e board com `min-width: 0`, inputs responsivos e colunas sem estourar o conteudo.
- [x] Atividades: tabs com rolagem horizontal segura, filtros empilhando corretamente, busca sem sobrepor controles e lista empilhando em telas menores.
- [x] Relatorios: painel de filtros convertido para grid responsivo com `auto-fit`, botoes sem quebra e KPIs/insights sem overflow.
- [x] Checklists: toolbar, cards, editor de itens e modal ajustados para textos longos e telas estreitas.
- [x] Automacoes: filtros, cards de regra, chips, acoes e modal com comportamento responsivo.
- [x] Cadencias: selects, inputs, cards e modal com protecao contra overflow e largura consistente.
- [x] Scoring: pagina protegida contra overflow em grids internos e inputs/selects padronizados.
- [x] Ficha 360: campos, paineis e dados longos com quebra segura; botoes adaptados para mobile.
- [x] Pipelines: pagina de configuracao protegida contra overflow e carga de arquivados corrigida sem `await` dentro de loop.
- [x] Motivos de perda: tela refeita com header, formulario e lista em padrao visual do CRM.
- [x] Metricas: header, analista CRM, filtros de periodo e tabelas/graficos com responsividade mais segura.
- [x] Validacao: Prettier, ESLint e build Vite executados apos os ajustes.

## 19. Fase Contatos, Listas e Segmentacao - 2026-05-05

Objetivo da fase: transformar a pagina de contatos em uma central operacional para importar listas, segmentar base, filtrar por etiquetas e preparar publicos de campanha sem sair do ChusteRM Core.

- [x] API de contatos passou a aceitar filtros CRM tambem em busca, ativos e filtros salvos: Lead/Cliente, etapa, responsavel, sem responsavel, etiqueta, lista de origem e area juridica.
- [x] Serializer de contatos passou a enviar etiquetas do contato para a UI, mantendo a ligacao com as mesmas etiquetas usadas no atendimento.
- [x] Cards da lista de contatos passaram a mostrar etiquetas, lista importada e area juridica quando existirem.
- [x] Tela de contatos recebeu uma central de segmentacao com filtros rapidos por relacionamento, etapa, responsavel, etiqueta, lista e area juridica.
- [x] Listas importadas recentes ficaram clicaveis para filtrar rapidamente a base, usando `source_list` gravado na importacao.
- [x] Exportacao de contatos passou a respeitar filtros rapidos aplicados pela URL, inclusive lista, etiqueta, area, responsavel e etapa.
- [x] Filtro avancado de contatos foi reforcado com atributos CRM: Lead/Cliente, etapa CRM, responsavel CRM, lista de origem e area juridica.
- [x] Filtro avancado recebeu comportamento responsivo mais seguro para evitar overflow em telas estreitas.
- [x] Operadores de presenca (`is_present` e `is_not_present`) foram corrigidos no backend de filtros para funcionarem em campos padrao e atributos adicionais.
- [ ] Proxima validacao visual: testar no navegador a pagina `/app/accounts/1/contacts` com listas importadas reais, etiquetas reais e exportacao por segmento.

## 20. Fase Integracoes Operacionais - Calendario - 2026-05-05

Objetivo da fase: iniciar as integracoes externas de forma incremental, com recursos uteis sem depender imediatamente de OAuth ou credenciais de terceiros.

- [x] Atividades do CRM ganharam endpoint de calendario `.ics` em `GET /api/v1/accounts/:account_id/crm/activities/calendar`.
- [x] Exportacao `.ics` respeita os filtros atuais da agenda: status, tipo, prioridade, periodo, responsavel e caso.
- [x] Cada atividade com prazo passou a receber link direto para criar evento no Google Agenda.
- [x] Tela de Atividades ganhou botao `Exportar ICS` para enviar a agenda filtrada ao Google Calendar, Apple Calendar, Outlook ou outro calendario compativel.
- [x] Eventos exportados incluem titulo, descricao, contato, telefone, caso vinculado e responsavel quando disponiveis.
- [x] Duracao padrao: 60 minutos para reuniao e 30 minutos para demais atividades.
- [x] Proximo passo natural iniciado: sincronizacao OAuth com Google Calendar/Meet e criacao de eventos no Google Calendar.
- [x] Proximo passo natural iniciado: exportacao direta de segmentos para CSV compativel com Google Sheets.
- [x] Proximo passo natural iniciado: sync autenticado com Google Sheets/Drive.

## 21. Fase Integracoes Operacionais - Listas e Planilhas - 2026-05-05

Objetivo da fase: tornar a segmentacao de contatos imediatamente utilizavel em planilhas, campanhas e operacoes comerciais sem esperar e-mail de exportacao.

- [x] Contatos ganharam endpoint direto `POST /api/v1/accounts/:account_id/contacts/export_csv`.
- [x] O CSV direto respeita filtro avancado, segmento salvo, etiqueta, lista de origem, area juridica, etapa, Lead/Cliente e responsavel.
- [x] Exportacao antiga por e-mail foi preservada para bases grandes ou fluxo assíncrono.
- [x] Dialogo de exportacao ganhou acao secundaria `Baixar CSV agora`.
- [x] CSV gerado inclui campos CRM uteis: relacionamento, etapa, responsavel, lista de origem, area juridica, etiquetas, empresa, cidade, criado em e ultima atividade.
- [x] As etiquetas exportadas sao as mesmas do atendimento/contato, mantendo Chat, CRM e campanha vinculados.
- [x] Proximo passo natural iniciado: sync autenticado com Google Sheets/Drive usando OAuth.
- [x] Proximo passo natural iniciado: selecionar segmento/lista diretamente na tela de criacao de campanha.

## 22. Fase Campanhas por Listas e Segmentos - 2026-05-05

Objetivo da fase: ligar a importacao/segmentacao de contatos ao disparo de campanha, evitando que o usuario precise recriar publicos manualmente.

- [x] Campanhas WhatsApp e SMS passaram a carregar listas importadas recentes a partir do historico de importacao de contatos.
- [x] Campo de publico da campanha agora combina etiquetas, listas importadas e segmentos salvos.
- [x] Backend de campanhas passou a resolver audiencia do tipo `SourceList` pelo campo `additional_attributes.source_list` dos contatos.
- [x] Contador de audiencia considera listas importadas e continua mostrando total e contatos com telefone.
- [x] Permissao de parametros de campanha aceita `name` no publico, preparando o mesmo formato para futuras listas nomeadas.
- [x] Proximo passo natural iniciado: preview dos contatos antes de disparar.
- [x] Proximo passo natural: tela de campanhas com filtros por lista/status/canal/periodo.
- [x] Proximo passo natural iniciado: campanhas WhatsApp oficiais com templates e metricas de entrega por provedor.

## 23. Fase Preview de Audiencia de Campanha - 2026-05-05

Objetivo da fase: reduzir risco de disparo errado mostrando uma amostra dos contatos que entram na campanha antes de criar/enviar.

- [x] API ganhou endpoint `POST /api/v1/accounts/:account_id/campaigns/audience_preview`.
- [x] Resolvedor de audiencia retorna resumo e amostra de contatos com nome, telefone, relacionamento, etapa, lista de origem e etiquetas.
- [x] Formulario de campanha WhatsApp passou a trocar o contador simples por preview com os primeiros contatos.
- [x] Formulario de campanha SMS recebeu o mesmo preview.
- [x] Preview respeita etiquetas, segmentos salvos e listas importadas.
- [x] Proximo passo natural: filtro visual dentro da pagina de campanhas por lista, status, canal e periodo.
- [x] Proximo passo natural: tela de revisao final antes do disparo com total, sem telefone, mensagem/template e publico.

## 24. Fase Integracoes Operacionais - Google Sheets/Drive - 2026-05-05

Objetivo da fase: permitir que uma lista segmentada saia do ChusteRM Core direto para uma planilha Google autenticada, sem perder os filtros de CRM.

- [x] Criada conexao CRM `google_workspace` com OAuth proprio, escopos Google Sheets e Drive File.
- [x] Callback `GET /crm/google/callback` grava a conexao por conta em `crm_external_connections`.
- [x] Contatos ganharam endpoint `POST /api/v1/accounts/:account_id/contacts/export_google_sheet`.
- [x] Exportacao para Google Sheets respeita filtros, segmento salvo, etiqueta, lista de origem, area juridica, etapa, Lead/Cliente e responsavel.
- [x] Dialogo de exportacao de contatos recebeu acoes `Criar Google Sheet` e `Conectar Google`.
- [x] O fluxo tenta criar a planilha e, se a conta ainda nao estiver conectada, inicia o OAuth do Google automaticamente.
- [x] Proximo passo natural iniciado: sincronizacao OAuth com Google Calendar/Meet e criacao de eventos no Google Calendar.
- [x] Campanhas WhatsApp oficiais passaram a registrar eventos por contato com provider, external_id e metricas iniciais no `delivery_stats`.
- [x] Cards de campanha exibem publico e resumo de metricas de entrega quando disponiveis.

## 25. Fase Integracoes Operacionais - Google Calendar e metricas de provedor - 2026-05-06

Objetivo da fase: fechar o ciclo operacional entre agenda CRM, Google Calendar/Meet e metricas reais de campanhas por provedor.

- [x] Atividades CRM ganharam campos externos `external_calendar_event_id`, `external_calendar_link`, `meeting_url` e `external_calendar_synced_at`.
- [x] Sincronizacao individual com Google Calendar agora salva o `event_id`, link do evento e link do Meet na atividade.
- [x] Nova sincronizacao da mesma atividade faz `PATCH` no evento Google existente, evitando duplicidade.
- [x] Eventos criados no Google recebem `extendedProperties` privadas com `account_id` e `crm_activity_id`.
- [x] Criado importador OAuth `Crm::GoogleCalendarImporter` para ler eventos do Google Calendar e criar/atualizar atividades CRM.
- [x] Criado endpoint `POST /api/v1/accounts/:account_id/crm/activities/import_google_calendar`.
- [x] Tela de Atividades ganhou botao `Importar Google`, com resumo de importadas, atualizadas e ignoradas.
- [x] Tracking de campanhas passou a consumir status reais de provedor por `external_id`, cobrindo `delivered`, `read` e `failed` mesmo quando nao existe `Message` local.
- [x] Webhooks WhatsApp Cloud e Evolution agora alimentam `CampaignDeliveryEvent` e atualizam `delivery_stats` da campanha.
- [x] Campanhas SMS/Bandwidth e Twilio passaram a registrar eventos `sent`, `skipped` e `failed` por contato.
- [x] Dockerfile do Core passou a copiar migracoes `20260506*.rb`, garantindo que novas fases entrem na imagem.

Validacao do bloco:

- [x] Sintaxe Ruby validada nos servicos, controller, rotas, model e migracao.
- [x] Prettier e ESLint passaram nos arquivos frontend alterados.
- [x] Build Docker `core`/`sidekiq` concluido pela raiz do projeto.
- [x] Migracao `20260506000001` aplicada e confirmada como `up`.
- [x] Rotas de Google Calendar/Sheets/OAuth confirmadas via `rails routes`.
- [x] Smoke HTTP em `http://localhost:3010/` retornou `200`.
- [x] `crm:health_check ACCOUNT_ID=1` retornou `status: ok`.

## 26. Fase Campanhas - Opt-out operacional - 2026-05-06

Objetivo da fase: impedir novos disparos para contatos que pediram saida da comunicacao, mantendo o dado no proprio contato.

- [x] Contatos ganharam metodos `campaign_opted_out?` e `campaign_opt_out!` usando `additional_attributes`.
- [x] Respostas recebidas com `SAIR`, `STOP`, `CANCELAR`, `DESCADASTRAR` ou `UNSUBSCRIBE` marcam opt-out automaticamente.
- [x] A origem, data e campanha associada ao opt-out ficam em `campaign_opt_out_source`, `campaign_opt_out_at` e `campaign_opt_out_campaign_id`.
- [x] Resolvedor de audiencia exclui contatos com opt-out antes de contar, prever ou disparar.
- [x] Resumo de audiencia passou a expor `opted_out`.
- [x] Preview/API de contato expõe `campaign_opt_out`.
- [x] Disparos WhatsApp, SMS/Bandwidth e Twilio fazem checagem defensiva antes do envio e registram `skipped` com motivo `campaign_opt_out`.

Validacao do bloco:

- [x] Sintaxe Ruby validada nos models e services alterados.
- [x] Build Docker `core`/`sidekiq` concluido.
- [x] Stack reiniciado com `core` e `sidekiq` healthy.
- [x] Smoke HTTP retornou `200`.
- [x] Rails runner confirmou `Contact#campaign_opted_out?`.
- [x] `crm:health_check ACCOUNT_ID=1` retornou `status: ok`.

## 27. Fase Cadencias - Condicionais avancadas - 2026-05-06

Objetivo da fase: permitir que cada passo de cadencia execute somente quando o lead/caso atende criterios operacionais.

- [x] Criado `Crm::CadenceConditionEvaluator`.
- [x] Condicoes suportam campos do deal, etapa, contato, atributos adicionais e opt-out de campanha.
- [x] Operadores suportados: `eq`, `not_eq`, `in`, `not_in`, `present`, `blank`, `gt`, `gte`, `lt`, `lte`.
- [x] Executor de cadencia avalia `action_config.conditions` antes de rodar o passo.
- [x] Ao falhar a condicao, o passo pode `skip_step`, `pause_enrollment` ou `cancel_enrollment`.
- [x] Auditoria registra `cadence_step_skipped_by_condition` com passo, cadencia, comportamento e condicoes.
- [x] Tela de Cadencias ganhou campo `Condicoes JSON` por passo e seletor `Se condicao falhar`.
- [x] Cards de cadencia indicam quantas condicoes existem por passo.

Validacao do bloco:

- [x] Sintaxe Ruby validada no avaliador e executor.
- [x] Prettier e ESLint passaram na tela de Cadencias.
- [x] Build Docker `core`/`sidekiq` concluido.
- [x] Stack reiniciado com `core` e `sidekiq` healthy.
- [x] Rails runner confirmou avaliador de condicoes.
- [x] Smoke HTTP retornou `200`.
- [x] `crm:health_check ACCOUNT_ID=1` retornou `status: ok`.

**Fim do documento.**
