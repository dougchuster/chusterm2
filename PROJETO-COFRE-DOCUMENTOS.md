# Projeto — Cofre de Documentos do Cliente (módulo **Arquivos**)

**Versão:** 2.1 (substitui a 1.0 e a 2.0 do mesmo dia)
**Data:** 2026-09-22
**Status:** proposta para aprovação (nenhuma linha de código escrita)
**Flag de produto:** `crm_documents`
**Branch sugerida:** `feat/crm-documents-vault`
**Documentos relacionados:** `PLANO-REFORMULACAO-CRM.md`, `DECISOES.md`, `SECURITY_AUDIT.md`, `docs/PLANO-DESIGN-SYSTEM-2026.md`

**O que mudou da 1.0 para a 2.0**
- §5 nova: **estrutura de pastas e nomenclatura** padronizada (cliente, processo, arquivo), com modelos por área do direito.
- §6 nova: **armazenamento na VPS em duas camadas** — cofre imutável + espelho de pastas legível em disco.
- §8 reescrita: **experiência de uso** com telas, fluxos, atalhos e a nova **Caixa de Triagem**.
- §11 reescrita: **backup no Google Drive como opção configurável**, com tela própria, espelho incremental, lixeira e teste de restauração.
- Fases, custos e decisões (§14–§18) atualizados.
- **2.1 (mesmo dia):** §8.7 passa a ter **dois modos de envio**. Além do link personalizado, entra um **formulário aberto do escritório** no estilo do cartório: o cliente preenche alguns campos de orientação (quem é, assunto, descrição, prazo) e anexa os documentos, recebendo um número de protocolo. Nova tabela `crm_document_submissions` (§4.8), defesas próprias (§9.2), F4 ampliada, decisões D12–D14.

---

## 0. Resposta à cliente (em linguagem de escritório, não de TI)

> *"Seria muito oneroso manter um sisteminha assim? Seria intuitivo? É uma alternativa para o nosso problema?"*

**Resumo:** é viável, **não é caro**, e dá para fazer melhor que o site do cartório. O cartório precisou criar um sistema à parte; nós já temos o WhatsApp e o cadastro do cliente no mesmo lugar.

O site do cartório resolve **um terço** do problema: ele recebe o documento. Os outros dois terços — *guardar no lugar certo, na pasta do cliente certo* e *saber o que ainda falta* — continuariam manuais. A proposta cobre os três:

1. **Captura automática.** Todo arquivo que o cliente manda no WhatsApp entra sozinho na pasta dele, com data e com o link da conversa de onde veio. Ninguém reenvia nada para grupo. Se o documento chegar picado — três fotos hoje, o comprovante amanhã —, tudo cai na mesma pasta, porque a pasta é do **cliente**, não da conversa.
2. **Pastas organizadas, com nome padronizado.** Cada cliente tem uma gaveta com a mesma estrutura de pastas (Documentos Pessoais, Comprovantes, Procurações, Processos...) e cada arquivo recebe um nome padrão (`2026-09-22 — RG — Frente e verso.pdf`). Quem abre a pasta de qualquer cliente sabe onde procurar.
3. **Formulário estilo cartório, e melhor.** Um endereço fixo do escritório, divulgado na resposta automática do WhatsApp, no site e num QR code, onde o cliente preenche poucos campos (nome, WhatsApp, assunto, o que aconteceu, se tem data marcada), anexa os documentos e recebe um **número de protocolo**. Quando faltar algo de um cliente já atendido, a equipe clica em "Pedir documentos" e manda um link que mostra **só o que falta**. Sem login, sem aplicativo.
4. **Cópia na VPS e no Google Drive.** Os arquivos ficam guardados no servidor do escritório, numa estrutura de pastas legível. Se a opção estiver ligada, todo dia de madrugada uma cópia sobe para o Google Drive do escritório **com as mesmas pastas e os mesmos nomes**. Se o sistema sair do ar, a documentação continua acessível pelo Drive.

**Custo:** nenhum servidor novo e nenhuma licença nova. O que cresce é o espaço em disco, e ele é barato: a estimativa é de ~22 GB para mil clientes com quinze documentos cada (§16), o que cabe no servidor atual. O custo real é o tempo de desenvolvimento: **19 a 22 dias úteis de trabalho efetivo**, entregue em fases. A primeira fase já útil (pasta por cliente + captura automática do WhatsApp) fica pronta em cerca de **uma semana e meia**.

**Risco de não fazer:** hoje o documento só existe dentro da mensagem de WhatsApp. Se a conversa for arquivada, se a instância do WhatsApp cair ou se alguém da equipe sair, encontrar o documento depende da memória de alguém. Foi exatamente esse o cenário dos aborrecimentos.

---

## 1. O problema, descrito com precisão

| # | Causa | O que acontece hoje | O que resolve |
|---|-------|---------------------|---------------|
| C1 | **Roteamento manual** | Cliente manda para o número da advogada; ela reenvia para grupos | Captura automática vinculada ao contato (§7) |
| C2 | **Envio fracionado** | Documentos chegam em dias diferentes e se perdem no scroll | Pasta persistente por contato, não por conversa (§4) |
| C3 | **Sem checklist** | Ninguém sabe, sem reler a conversa, o que ainda falta | Checklist por tipo de caso (§8.6) |
| C4 | **Desorganização** | Cada um salva com um nome e num lugar | Estrutura de pastas e nomenclatura únicas (§5) |
| C5 | **Sem cópia externa** | Se a conversa some, o documento some | Cofre na VPS + espelho legível + backup no Drive (§6, §11) |

### 1.1 O que o sistema já faz (e onde para)

Levantamento feito no código em 2026-09-22:

- Anexos de qualquer canal viram registros em `attachments`, sempre **pendurados numa mensagem** (`core/app/models/attachment.rb`, `belongs_to :message`). Não existe documento por contato.
- O arquivo em si já usa **Active Storage** (`has_one_attached :file`), no serviço `local` (`core/config/environments/production.rb:43`, `ACTIVE_STORAGE_SERVICE`), gravado em `Rails.root/storage` (`core/config/storage.yml`), que é o volume Docker `core-storage:/app/storage` (`docker-compose.prod.yml:218`, `:254`).
- Anexos do WhatsApp são criados em `core/app/services/whatsapp/incoming_message_base_service.rb:171` (`attach_files`) e em `incoming_message_evolution_service.rb:345`.
- Já existe barramento de eventos com listeners (`core/app/listeners/`, ex.: `crm_captain_triage_listener.rb#message_created`). É o ponto de acoplamento limpo, sem tocar nos serviços de canal.
- Já existe OAuth do Google por conta em `crm_external_connections` (provider `google_workspace`, tokens criptografados), e **o escopo `drive.file` já é pedido** no consentimento (`core/app/controllers/api/v1/accounts/crm/google_authorizations_controller.rb:68`).
- `google-apis-core` e `googleauth` já estão no `Gemfile.lock`. Falta só o cliente específico `google-apis-drive_v3`, uma gem pequena da mesma família.
- Já existem `crm_checklist_templates` (com `case_type`/`legal_area`), auditoria polimórfica (`crm_audit_events`) e cron (`core/config/schedule.yml`, sidekiq-cron).

**Conclusão:** o módulo é, em grande parte, **composição de peças que já existem**. Não é preciso serviço novo, banco novo nem nova integração de autenticação.

---

## 2. Objetivos e não-objetivos

### 2.1 Objetivos (com métrica)

| ID | Objetivo | Métrica |
|----|----------|---------|
| O1 | Nenhum documento recebido fica fora do cofre | 100% dos anexos de canal com `crm_documents` correspondente (query auditável) |
| O2 | Fim do reenvio manual para grupos | Zero encaminhamentos manuais relatados após 30 dias |
| O3 | Saber o que falta sem reler conversa | 100% dos processos ativos com checklist de documentos |
| O4 | Achar um documento em até 3 cliques ou 1 busca | Teste com a equipe: mediana ≤ 15 s |
| O5 | Triar um documento recebido em segundos | Mediana ≤ 5 s por documento na Caixa de Triagem |
| O6 | Estrutura e nomes padronizados | ≥ 95% dos documentos fora da Triagem após 7 dias do recebimento |
| O7 | Cópia externa diária verificada | Backup `success` em ≥ 29 de 30 dias; restauração ensaiada por trimestre |
| O8 | Cliente envia sem ajuda | ≥ 80% das solicitações concluídas sem intervenção da equipe |

### 2.2 Não-objetivos

- GED jurídico com assinatura ICP-Brasil ou carimbo do tempo.
- Integração com PJe/e-SAJ ou peticionamento.
- OCR e indexação de conteúdo de PDF nas fases F1–F5 (avaliados na F6).
- Edição de documentos dentro do sistema.
- Usar o Drive como local de trabalho. O Drive é **cópia de segurança e consulta**; a fonte de verdade é o CRM.

---

## 3. Visão do produto — quatro superfícies e um motor de nomes

```
  WhatsApp / E-mail ──►┌──────────────────────────────┐
  Instagram            │ 1. CAPTURA AUTOMÁTICA        │
                       └──────────────┬───────────────┘
                                      ▼
  Equipe ─────────────►┌──────────────────────────────┐      ┌───────────────────┐
  (arrastar e soltar)  │ 2. COFRE + CAIXA DE TRIAGEM  │◄────►│ MOTOR DE NOMES    │
                       │ pastas · status · checklist  │      │ PathBuilder (§5)  │
                       └──────────────┬───────────────┘      └─────────┬─────────┘
                                      ▲                                │ mesma árvore,
  Cliente ────────────►┌──────────────┴───────────────┐                │ mesmos nomes
  (link sem login)     │ 3. PORTAL DE ENVIO           │                ▼
                       └──────────────────────────────┘      ┌───────────────────┐
                                                             │ 4. SAÍDAS         │
                                                             │ a. espelho na VPS │
                                                             │ b. backup no Drive│
                                                             │ c. download .zip  │
                                                             └───────────────────┘
```

**Princípio do dono:** o documento pertence ao **contato** (`contact_id`, obrigatório). O processo (`crm_deal_id`) é uma referência opcional. Casa com a regra do escritório: cliente antigo que volta **não é lead novo**. A pasta dele já existe, com o histórico, e o caso novo ganha uma subpasta.

**Princípio da árvore única:** a estrutura que a equipe vê na tela, o espelho em disco na VPS, o backup no Drive e o `.zip` baixado são **a mesma árvore com os mesmos nomes**, gerada por um único componente (`PathBuilder`). Ninguém precisa aprender duas organizações.

---

## 4. Modelo de dados

Todas as migrations são **aditivas**. Nada existente é alterado ou removido.

### 4.1 `crm_document_folders`

| Coluna | Tipo | Observação |
|--------|------|-----------|
| `account_id` | bigint NOT NULL | multi-tenant, indexado |
| `contact_id` | bigint NOT NULL | dono da gaveta |
| `parent_id` | bigint NULL | árvore, profundidade máxima 5 |
| `crm_deal_id` | bigint NULL | pasta de processo |
| `name` | string NOT NULL | nome exibido **e** físico (já sanitizado, §5.5) |
| `slot` | string NULL | papel da pasta no modelo (`pessoais`, `comprovantes`, `triagem`, `processo_provas`...). Usado pelo roteamento automático, sobrevive a renomeações |
| `kind` | string NOT NULL default `custom` | `system` (do modelo, não pode ser excluída) / `custom` |
| `position` | integer default 0 | ordem manual |
| `archived_at` | datetime NULL | soft delete |

Índice único: `(account_id, contact_id, parent_id, lower(name)) WHERE archived_at IS NULL`.

### 4.2 `crm_documents`

| Coluna | Tipo | Observação |
|--------|------|-----------|
| `account_id`, `contact_id` | bigint NOT NULL | |
| `crm_document_folder_id` | bigint NULL | `NULL` = raiz da gaveta |
| `crm_deal_id` | bigint NULL | processo relacionado |
| `doc_type` | string NULL | slug do catálogo (§5.4): `rg`, `cpf`, `cnis`... |
| `description` | string NULL | complemento livre ("Frente e verso") |
| `document_date` | date NULL | data do documento, quando conhecida; senão vale a data de recebimento |
| `file_name` | string NOT NULL | nome físico **gerado** pela nomenclatura (§5.3); recalculado quando tipo, descrição ou data mudam |
| `name_locked` | boolean default false | a equipe renomeou manualmente → o motor não sobrescreve |
| `original_filename`, `content_type` | string | preservados para auditoria |
| `byte_size` | bigint | |
| `checksum` | string | do blob; base da deduplicação |
| `source` | string NOT NULL | `whatsapp` `email` `instagram` `upload` `portal` `system` |
| `source_attachment_id` | bigint NULL | idempotência |
| `source_message_id` | bigint NULL | link de volta para a conversa |
| `uploaded_by_user_id` | bigint NULL | |
| `uploaded_by_contact` | boolean default false | |
| `status` | string NOT NULL default `received` | `received` `approved` `rejected` `obsolete` |
| `review_note` | text NULL | motivo de rejeição |
| `tags` | jsonb default `[]` | |
| `expires_on` | date NULL | validade (certidões) |
| `versions_count` | integer default 1 | |
| `meta` | jsonb default `{}` | `ai_suggestion`, `scan_result`, `classified_by` |
| `archived_at` | datetime NULL | soft delete |

Índices: `(account_id, contact_id, archived_at)`, `(account_id, crm_deal_id)`, **único** `(account_id, source_attachment_id) WHERE source_attachment_id IS NOT NULL`, `(account_id, contact_id, checksum)`, `(account_id, status)`, `(account_id, crm_document_folder_id)`, GIN em `tags`.

Modelo: `has_one_attached :file`, `has_many :crm_document_versions`, `has_many :crm_audit_events, as: :target`.

### 4.3 `crm_document_versions`

`crm_document_id`, `version`, `checksum`, `byte_size`, `uploaded_by_user_id`, `uploaded_by_contact`, `created_at` + `has_one_attached :file`.

Reenvio do **mesmo documento lógico** (mesmo `doc_type` na mesma pasta, com checksum diferente) cria versão nova e mantém a anterior. Nunca sobrescreve.

### 4.4 `crm_document_folder_templates` (modelos de estrutura por área)

`account_id`, `name`, `legal_area` (`previdenciario`, `trabalhista`, `familia`, `civel`, `criminal`, `empresarial`, `geral`), `scope` (`client` = raiz da gaveta, `case` = subpasta de processo), `tree` (jsonb: `[{slot, name, children:[...]}]`), `default` (boolean).

Vem com os modelos da §5.2 pré-carregados por seed e editáveis em Configurações → Arquivos. Alterar um modelo afeta apenas gavetas **novas**. Aplicar a gavetas existentes é uma ação explícita, com prévia.

### 4.5 `crm_document_requests` (portal de envio)

| Coluna | Tipo | Observação |
|--------|------|-----------|
| `account_id`, `contact_id` | bigint NOT NULL | |
| `crm_deal_id` | bigint NULL | |
| `token_digest` | string NOT NULL, único | SHA-256; **o token cru nunca é gravado** |
| `title` | string | "Documentos para aposentadoria por idade" |
| `items` | jsonb | `[{doc_type, label, required, received_at, document_id}]` |
| `message` | text | recado ao cliente |
| `status` | string | `pending` `partial` `completed` `expired` `revoked` |
| `expires_at` | datetime NOT NULL | padrão 7 dias |
| `created_by_user_id` | bigint | |
| `last_access_at`, `access_count`, `completed_at` | | telemetria |

### 4.6 `crm_storage_sync_entries` (estado das saídas: espelho e Drive)

Uma linha por (documento/versão, destino). É o que torna as saídas **incrementais**.

| Coluna | Tipo | Observação |
|--------|------|-----------|
| `account_id` | bigint NOT NULL | |
| `target` | string NOT NULL | `vps_mirror` / `google_drive` |
| `syncable_type`, `syncable_id` | | `CrmDocument` ou `CrmDocumentFolder` |
| `remote_id` | string NULL | id do arquivo/pasta no Drive; caminho relativo no espelho |
| `synced_path` | string | caminho com que foi sincronizado da última vez |
| `synced_checksum` | string | checksum sincronizado da última vez |
| `synced_at` | datetime | |
| `state` | string | `synced` `pending` `failed` `trashed` |
| `last_error` | text NULL | |

Índice único `(account_id, target, syncable_type, syncable_id)`.

Comparando `synced_path` e `synced_checksum` com o estado atual, o motor sabe se precisa **não fazer nada**, **mover/renomear** (sem reenviar bytes) ou **enviar de novo**.

### 4.7 `crm_storage_runs` (histórico de execuções)

`account_id`, `target`, `trigger` (`schedule` `manual` `event`), `started_at`, `finished_at`, `status` (`success` `partial` `failed`), `files_uploaded`, `files_moved`, `files_trashed`, `files_skipped`, `bytes_uploaded`, `manifest_remote_id`, `error`.

### 4.8 `crm_document_submissions` (envios pelo formulário, com orientação da demanda)

Um registro por envio feito pelo portal, nos dois modos (§8.7). Guarda **o que o cliente contou**, separado dos arquivos.

| Coluna | Tipo | Observação |
|--------|------|-----------|
| `account_id` | bigint NOT NULL | |
| `protocol` | string NOT NULL, único por conta | `AAAA-NNNNNN` (ex.: `2026-000317`), mostrado ao cliente |
| `mode` | string NOT NULL | `open_form` (link fixo do escritório) / `request` (link personalizado) |
| `crm_document_request_id` | bigint NULL | quando veio de um link personalizado |
| `contact_id` | bigint NULL | preenchido quando o contato for identificado |
| `crm_deal_id` | bigint NULL | processo ao qual a equipe vinculou o envio |
| `full_name` | string NOT NULL | informado pelo cliente |
| `phone_e164` | string NOT NULL | WhatsApp informado, normalizado |
| `cpf` | string NULL | opcional; **criptografado** (Active Record Encryption), com digest para busca |
| `subject` | string NOT NULL | slug do assunto (`previdenciario`, `trabalhista`, `familia`, `consumidor`, `outro`) |
| `self_declared_client` | string | `yes` / `no` / `unsure`, declarado pelo cliente e nunca usado como verdade |
| `description` | text | "conte em poucas palavras", até 1.000 caracteres |
| `deadline_on` | date NULL | "tem alguma data marcada?" (audiência, perícia, prazo) |
| `match_status` | string NOT NULL | `matched_phone` `matched_cpf` `new_contact` `ambiguous` |
| `verified` | boolean default false | `true` quando a equipe confirma ou quando veio de link personalizado |
| `review_status` | string | `new` `in_review` `done` `spam` |
| `consent_at`, `ip`, `user_agent` | | registro LGPD e antiabuso |

Os documentos anexados são `crm_documents` normais, com `source: portal` e `meta.submission_id`.

### 4.9 O que **não** será criado

- **Tabela de eventos de documento:** reusa `crm_audit_events`.
- **Sistema de arquivos próprio:** Active Storage continua sendo o cofre (§6.1).

---

## 5. Estrutura de pastas e nomenclatura

Esta seção é o "manual de organização" do escritório, só que aplicado automaticamente pelo sistema.

### 5.1 Regras gerais

1. **Toda gaveta nasce com a mesma estrutura**, conforme o modelo da área (§5.2). A equipe pode criar pastas extras, mas não pode excluir as do modelo.
2. **Prefixo numérico de duas casas** (`01`, `02`...) nas pastas do modelo. Garante a mesma ordem na tela, no Windows Explorer, no Drive e no celular, independentemente de ordenação alfabética.
3. **Datas no formato `AAAA-MM-DD`.** É o único formato que ordena cronologicamente por nome.
4. **O nome é derivado, não digitado.** O arquivo recebe o nome a partir de tipo + descrição + data. Se a equipe renomear à mão, o sistema respeita (`name_locked`) e deixa de recalcular.
5. **Acentos são mantidos** ("Certidão", "Procuração"). Ext4, Drive e ZIP (com flag UTF-8) suportam. O sistema remove apenas o que quebra algum destino (§5.5).
6. **Sem CPF no nome de pasta ou arquivo** por padrão (minimização de dados, LGPD). A unicidade vem do código do cliente. Ver D7.

### 5.2 Árvore padrão

```
Clientes/
└── Maria da Silva Souza · C000123/                 ← gaveta do cliente (§5.3)
    ├── 00 Triagem/                                  ← chegou e ainda não foi classificado
    ├── 01 Documentos Pessoais/                      ← RG, CPF, CNH, certidões
    ├── 02 Comprovantes/                             ← residência, renda, bancários
    ├── 03 Procurações e Contratos/                  ← procuração, contrato de honorários, declarações
    ├── 04 Processos/
    │   └── 2026-0042 · Aposentadoria por Idade · INSS/   ← pasta de processo (§5.3)
    │       ├── 01 Documentos do Caso/               ← CNIS, CTPS, PPP, laudos
    │       ├── 02 Petições e Protocolos/
    │       ├── 03 Decisões e Intimações/
    │       └── 04 Comunicações/
    ├── 05 Enviados pelo Escritório/                 ← o que a equipe mandou pelo WhatsApp
    └── 99 Arquivo/                                  ← obsoleto ou substituído, nunca apagado
```

**Subpastas de processo por área** (modelos editáveis; seed inicial):

| Área | `01` | `02` | `03` | `04` |
|------|------|------|------|------|
| Previdenciário | Documentos do Caso (CNIS, CTPS, PPP, laudos) | Requerimento Administrativo | Petições e Protocolos | Decisões e Perícias |
| Trabalhista | Documentos do Contrato (CTPS, holerites, rescisão) | Provas (conversas, fotos, testemunhas) | Petições e Protocolos | Decisões e Audiências |
| Família | Documentos das Partes | Bens e Renda | Petições e Protocolos | Decisões e Acordos |
| Cível / Consumidor | Documentos do Caso | Provas | Petições e Protocolos | Decisões |
| Criminal | Documentos do Caso | Inquérito e Provas | Petições e Protocolos | Decisões e Audiências |
| Geral (padrão) | Documentos do Caso | Petições e Protocolos | Decisões e Intimações | Comunicações |

A área vem do `legal_area` do processo. Se não houver, usa "Geral". Isso atende ao escopo full service: o sistema não presume previdenciário.

### 5.3 Padrões de nome

| Elemento | Padrão | Exemplo |
|----------|--------|---------|
| Gaveta do cliente | `{Nome completo} · C{id do contato, 6 dígitos}` | `Maria da Silva Souza · C000123` |
| Pasta de processo | `{AAAA}-{nº sequencial do processo no ano, 4 dígitos} · {Tipo de ação} · {Parte contrária/órgão}` | `2026-0042 · Aposentadoria por Idade · INSS` |
| Arquivo classificado | `{AAAA-MM-DD} — {Tipo} — {Descrição}.{ext}` | `2026-09-22 — RG — Frente e verso.pdf` |
| Arquivo sem descrição | `{AAAA-MM-DD} — {Tipo}.{ext}` | `2026-09-22 — CNIS.pdf` |
| Arquivo na Triagem | `{AAAA-MM-DD HHhMM} — {origem} — {nome original}.{ext}` | `2026-09-22 14h37 — WhatsApp — IMG-20260922-WA0012.jpg` |
| Versão anterior | mesmo nome + ` (v{n})`, em `99 Arquivo/` | `2026-09-22 — RG — Frente e verso (v1).pdf` |
| Colisão de nome | sufixo ` (2)`, ` (3)`... | `2026-09-22 — Holerite — Agosto (2).pdf` |

- O **código do cliente** (`C000123`) é estável: resolve homônimos e sobrevive a correções de nome. Se o nome for corrigido, a gaveta é renomeada e as saídas **movem** a pasta, sem reenviar arquivos (§4.6).
- O **número do processo** usa o número interno do CRM, sem expor o número CNJ no caminho. O número CNJ aparece nos metadados e na tela.
- Na Triagem, o nome preserva o original e a hora, para a equipe reconhecer "aquela foto que ela mandou às 14h".

### 5.4 Catálogo de tipos de documento

Tabela de configuração por conta, com seed inicial. Cada tipo sabe **o rótulo usado no nome** e **para qual pasta vai** (por `slot`, não por nome, para sobreviver a renomeações).

| Slug | Rótulo no nome | Pasta de destino (`slot`) | Validade padrão |
|------|----------------|---------------------------|-----------------|
| `rg` | RG | `pessoais` | — |
| `cpf` | CPF | `pessoais` | — |
| `cnh` | CNH | `pessoais` | data impressa |
| `certidao_nascimento` / `casamento` / `obito` | Certidão de Nascimento / Casamento / Óbito | `pessoais` | 90 dias (configurável) |
| `comprovante_residencia` | Comprovante de Residência | `comprovantes` | 90 dias |
| `holerite` | Holerite | `comprovantes` (ou `processo_docs` se houver processo trabalhista) | — |
| `extrato_bancario` | Extrato Bancário | `comprovantes` | — |
| `procuracao` | Procuração | `contratos` | — |
| `contrato_honorarios` | Contrato de Honorários | `contratos` | — |
| `declaracao_hipossuficiencia` | Declaração de Hipossuficiência | `contratos` | — |
| `cnis` | CNIS | `processo_docs` | 30 dias |
| `ctps` | CTPS | `processo_docs` | — |
| `ppp` | PPP | `processo_docs` | — |
| `laudo_medico` | Laudo Médico | `processo_docs` | — |
| `peticao` | Petição | `processo_peticoes` | — |
| `decisao` | Decisão | `processo_decisoes` | — |
| `outro` | (descrição obrigatória) | pasta atual | — |

Quando o destino é um `slot` de processo e o cliente tem **mais de um processo ativo**, o sistema não adivinha: pergunta na triagem (§8.3).

### 5.5 Sanitização (vale para todos os destinos)

Implementada uma única vez em `Crm::Documents::Naming::Sanitizer`, com testes de tabela:

- Normaliza Unicode para **NFC** (evita "á" duplicado vindo do macOS/iPhone).
- Remove `/ \ : * ? " < > |` e caracteres de controle; troca por espaço e colapsa espaços repetidos.
- Remove ponto e espaço no fim (o Windows recusa ao extrair o `.zip`).
- Evita nomes reservados do Windows (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`, `LPT1`–`LPT9`) acrescentando `_`.
- Limita o **nome do arquivo a 120 caracteres** (antes da extensão) e o **caminho completo a 240**. Trunca a descrição, nunca a data, o tipo nem a extensão.
- Extensão sempre em minúsculas e **derivada do tipo real do conteúdo** (magic bytes), não do nome enviado. `foto.pdf` que é JPEG vira `.jpg`.
- Nunca aceita `..` nem caminho absoluto. O `PathBuilder` monta caminhos a partir de ids, nunca de texto do usuário concatenado.

### 5.6 O `PathBuilder`

`Crm::Documents::Naming::PathBuilder#path_for(document)` → `["Clientes", "Maria da Silva Souza · C000123", "01 Documentos Pessoais", "2026-09-22 — RG — Frente e verso.pdf"]`

- Função pura sobre o estado do banco: mesma entrada, mesma saída. Fácil de testar.
- Usada pelo espelho da VPS, pelo backup no Drive, pelo `.zip` e pelo breadcrumb da tela.
- Resolve colisões de forma determinística (ordem por `id`), para que o espelho e o Drive nunca discordem.

---

## 6. Armazenamento na VPS

### 6.1 Duas camadas, cada uma com uma função

```
/app/storage  (volume Docker core-storage, na VPS)
├── ab/cd/abcd1234...          ← CAMADA 1 · COFRE (Active Storage)
├── ef/gh/efgh5678...             blobs imutáveis, chave opaca
│                                 fonte de verdade
└── arquivos/                  ← CAMADA 2 · ESPELHO LEGÍVEL (opcional, D8)
    └── Clientes/                 árvore da §5, gerada pelo PathBuilder
        └── Maria da Silva Souza · C000123/
            └── 01 Documentos Pessoais/
                └── 2026-09-22 — RG — Frente e verso.pdf   ← hardlink para o blob
```

**Camada 1 — Cofre (Active Storage, já em produção).** O arquivo é gravado **uma vez**, com chave aleatória, e nunca mais muda. Por que não gravar direto com o nome bonito:

- Renomear, mover ou reclassificar é **instantâneo**: muda uma linha no banco, não mexe em disco.
- Não há colisão de nome, nem risco de path traversal, nem arquivo "meio renomeado" se o servidor cair no meio da operação.
- Versões são triviais: cada versão é um blob.
- A troca futura para armazenamento compatível com S3 (D1) é só configuração em `storage.yml`, sem migrar a organização.

**Camada 2 — Espelho legível (novo).** Uma pasta `arquivos/` **no mesmo volume**, com a árvore da §5 e os nomes padronizados, mantida pelo sistema. Serve para:

- Quem administra o servidor abrir por SFTP/WinSCP e encontrar os documentos de um cliente sem passar pelo CRM.
- Recuperação quando o aplicativo estiver fora do ar.
- Base para ferramentas externas de backup (`rclone`, `restic`) copiarem uma estrutura que um humano entende.

### 6.2 Como o espelho funciona

- **Hardlink, não cópia.** Como `arquivos/` está no mesmo sistema de arquivos dos blobs, cada arquivo do espelho é um *hardlink* para o blob: **zero espaço extra em disco**. Se o sistema de arquivos não suportar (ex.: futuro armazenamento S3), o espelho passa para modo cópia ou é desligado (configurável).
- **Somente leitura.** Os arquivos ficam com permissão `0444`. Como o hardlink compartilha o conteúdo com o blob, editar o arquivo no espelho corromperia o cofre; a permissão impede isso. O `MirrorSync` confere o checksum na reconciliação e alerta se algo divergir.
- **Atualização por evento + reconciliação.** Cada criação, movimentação, renomeação ou arquivamento enfileira `Crm::Documents::MirrorSyncJob` para aquela gaveta (com *debounce* de 30 s, para agrupar rajadas). Toda madrugada, uma reconciliação completa compara o espelho com o `PathBuilder` e corrige divergências.
- **Operação atômica.** Cria o link com nome temporário e faz `rename(2)` para o nome final. Quem estiver lendo nunca vê arquivo pela metade.
- **Arquivado não é apagado.** Documento arquivado no CRM sai do espelho, mas o blob permanece no cofre até a purga (§10).
- **Estado em `crm_storage_sync_entries`** (`target: vps_mirror`), igual ao Drive. O mesmo motor de diff atende os dois destinos.

### 6.3 Capacidade de disco

- Tela Configurações → Arquivos mostra **uso atual, crescimento dos últimos 30 dias e projeção**.
- Alerta ao administrador em **70%** e **85%** de ocupação do volume.
- Limite de tamanho por arquivo em constante configurável (padrão 50 MB para a equipe, 25 MB para o portal).
- Vídeos grandes de WhatsApp entram no cofre, mas a tela sugere arquivamento após 90 dias sem acesso (sugestão, nunca ação automática).

### 6.4 Backup local da própria VPS (camada fora do app)

Independente do Drive, e recomendado mesmo que o Drive fique desligado:

- `restic` (ou `rclone`) no host, rodando por cron, copiando o volume `core-storage` e o dump do Postgres para `/opt/chusterm-backups` (layout já existente, ver `project_vps_deploy_layout`) e, opcionalmente, para um destino externo.
- Protege o cenário em que **o próprio aplicativo está quebrado**, que é justamente quando o backup importa.
- **Atenção:** o dump do banco e as chaves do Active Record Encryption (já em `/opt/chusterm-backups`) precisam ser copiados **juntos**. Sem as chaves, os metadados criptografados do backup não abrem.

---

## 7. Captura automática

### 7.1 Fluxo

```
mensagem chega (qualquer canal)
  └─► evento message_created
       └─► CrmDocumentIntakeListener#message_created                 [novo]
            ├─ filtra: tem anexo? flag ligada? tipo aceito?
            └─► Crm::Documents::IngestAttachmentJob(attachment_id)   [novo]
                 ├─ resolve contato (message.conversation.contact_id)
                 ├─ garante a gaveta (cria pelo modelo, se for a primeira vez)
                 ├─ dedup por (contact_id, checksum) → já existe? registra reenvio e sai
                 ├─ cria crm_document (source: whatsapp) em "00 Triagem"
                 ├─ classificador determinístico (§7.3) → doc_type sugerido
                 ├─ se a regra for de alta confiança e D9 = automático → move para a pasta do tipo
                 ├─ casa com item pendente do checklist → marca recebido
                 ├─ enfileira MirrorSyncJob (debounce)
                 └─ auditoria + broadcast ActionCable (a tela atualiza sozinha)
```

O listener segue o padrão de `core/app/listeners/crm_captain_triage_listener.rb`. **Nenhum serviço de canal é modificado:** evita conflito com o upstream do Chatwoot e cobre WhatsApp, Instagram, e-mail e canais futuros sem trabalho extra.

### 7.2 Regras de entrada

- Entram: `file`, `image`, `audio`, `video` de mensagens **recebidas**.
- Entram, se configurado (padrão ligado, D5): anexos **enviados pela equipe**, em `05 Enviados pelo Escritório`.
- Não entram: `location`, `contact`, `story_mention`, `share`, notas privadas e mensagens de atividade.
- Imagem sem legenda e com menos de 40 KB (figurinha, print solto) → Triagem com marca "provável irrelevante", que a equipe descarta com um toque. O limite fica em constante configurável.
- Áudio entra no cofre, mas não na Caixa de Triagem por padrão. Áudio raramente é documento; é conversa.

### 7.3 Classificação (sugestão, não decisão)

- **Camada 1 — regras determinísticas** (sem custo, sem IA): nome do arquivo e legenda contra padrões do catálogo (`rg|identidade`, `cpf`, `cnh`, `comprovante.*(residencia|endereco)|conta de (luz|agua)`, `cnis`, `ctps|carteira de trabalho`, `holerite|contracheque`, `certid[aã]o.*(nascimento|casamento|[oó]bito)`, `procura[cç][aã]o`, `laudo`, `ppp`). A legenda que o cliente escreve ("segue meu RG") é o melhor sinal e é a primeira a ser avaliada.
- **Camada 2 — IA (F6, opcional):** o orchestrator existente sugere `doc_type` e uma descrição curta, com score de confiança, em `meta.ai_suggestion`. **O status nunca muda sozinho.**

### 7.4 Idempotência e histórico

- Índice único em `(account_id, source_attachment_id)`; o job trata `RecordNotUnique` como sucesso. Webhook duplicado do Evolution, cenário real neste projeto, não duplica documento.
- Rake `crm:documents:backfill[account_id,since]` em lotes de 500, idempotente, fila de baixa prioridade, janela noturna. Tudo que vem do histórico cai na Triagem, com nome de origem, para classificação gradual.

---

## 8. Experiência de uso

### 8.1 Quem usa e como

| Pessoa | Contexto | O que precisa |
|--------|----------|---------------|
| **Advogada titular** | Celular, entre audiências, recebe tudo no WhatsApp | Não reenviar nada; ver de relance o que falta em cada caso; mandar o link de documentos em dois toques |
| **Secretária / atendimento** | Desktop, várias conversas abertas | Triar em lote o que chegou, rápido e com teclado; pedir documentos; baixar a pasta para protocolo |
| **Advogado(a) do caso** | Desktop, montando a petição | Achar o documento certo, a versão certa, e baixar o conjunto do processo |
| **Cliente** | Celular simples, pouca familiaridade digital, às vezes sem e-mail | Saber exatamente o que mandar; enviar sem cadastro; ter certeza de que chegou |

### 8.2 Princípios de design

1. **O modelo mental é a pasta física e o explorador de arquivos**, não um "dashboard de cards". Pastas à esquerda, arquivos à direita, breadcrumb no topo.
2. **Nada chega sem dono.** Todo arquivo aparece na gaveta do cliente certo; o que não foi classificado fica visível na Triagem, nunca escondido.
3. **Desfazer em vez de confirmar.** Mover, renomear, arquivar e classificar executam na hora e mostram um aviso "Desfazer" por 8 segundos. Confirmação só para purga definitiva.
4. **Uma ação principal por tela**, sempre visível: "Enviar arquivos" na gaveta, "Classificar" na triagem, "Pedir documentos" no processo.
5. **Estado vazio que ensina:** gaveta vazia explica que o que o cliente mandar no WhatsApp aparece aqui sozinho e oferece "Pedir documentos".
6. **Status com significado, não decoração:** cinza `recebido`, verde `aprovado`, vermelho `rejeitado` (motivo obrigatório), âmbar `vence em X dias`. Sempre com ícone e texto, nunca só cor.
7. **Rápido de verdade:** lista paginada e virtualizada; miniaturas carregadas sob demanda; resposta em menos de 200 ms para ações comuns (otimista, com reversão se o servidor recusar).

### 8.3 Tela: Caixa de Triagem (nova, o coração do fluxo)

A secretária hoje recebe e reencaminha; com a triagem, ela **classifica com um toque** e o sistema arquiva no lugar certo. Rota `crm/arquivos/triagem`, com contador na barra lateral.

```
┌─ Arquivos ▸ Triagem (14) ───────────────────────────────────────────────────────────────┐
│ [Todos ▾] [WhatsApp ▾] [Hoje ▾]                                     🔍 Buscar cliente…   │
├───────────────────────────────────────────┬─────────────────────────────────────────────┤
│ ▸ Maria da Silva Souza · 4 arquivos       │  ┌───────────────────────────────────────┐  │
│   ■ 14h37  IMG-WA0012.jpg   sugestão: RG  │  │                                       │  │
│   □ 14h37  IMG-WA0013.jpg   sugestão: RG  │  │        [ pré-visualização grande ]    │  │
│   □ 14h39  conta_luz.pdf    sugestão: Comp│  │                                       │  │
│   □ 15h02  audio.ogg        —             │  └───────────────────────────────────────┘  │
│ ▸ João Pereira · 2 arquivos               │  Legenda do cliente: "segue meu rg"         │
│   □ 09h12  documento.pdf    —             │  Veio de: conversa #4821 ↗   14h37 · 312 KB │
│ ▸ Ana Costa · 8 arquivos                  │                                             │
│   …                                       │  Tipo:  [1 RG ✓] [2 CPF] [3 CNH] [4 Comp.   │
│                                           │          Residência] [5 CNIS] [ Outro… ]    │
│                                           │  Descrição: [Frente e verso          ]      │
│                                           │  Processo:  [2026-0042 · Aposentadoria ▾]   │
│                                           │  Vai para: 01 Documentos Pessoais           │
│                                           │  Nome:  2026-09-22 — RG — Frente e verso.jpg│
│                                           │                                             │
│                                           │  [ Classificar  ↵ ]  [Descartar ⌫] [Pular →]│
└───────────────────────────────────────────┴─────────────────────────────────────────────┘
```

- Agrupada **por cliente**, porque os documentos chegam em rajada da mesma pessoa.
- **Prévia do nome e do destino antes de confirmar.** Ninguém se surpreende com onde o arquivo foi parar.
- **Teclado:** `J`/`K` navegam, `1`–`9` escolhem o tipo, `Enter` classifica e avança, `Backspace` descarta (vai para `99 Arquivo`, não some), `Shift+clique` seleciona vários para classificar em lote ("estas 2 fotos são o RG" → juntar em um documento com duas páginas é F3+).
- **No celular:** um arquivo por tela, deslizar para o lado para pular, chips de tipo grandes na base.
- **Processo:** se o cliente tiver um único processo ativo, vem pré-selecionado; se tiver vários, o campo fica vazio e obrigatório para tipos de processo.

### 8.4 Tela: Gaveta do cliente (aba "Arquivos" no processo e no contato)

```
┌─ Maria da Silva Souza · C000123 ▸ 04 Processos ▸ 2026-0042 · Aposentadoria por Idade ───┐
│ Checklist do caso  ▓▓▓▓▓▓▓░░░  7 de 9   Faltam: PPP, Laudo médico   [ Pedir documentos ] │
├──────────────────────────┬──────────────────────────────────────────────────────────────┤
│ 📁 00 Triagem (2)        │ Nome                                   Tipo     Data   Status│
│ 📁 01 Documentos Pessoais│ 📄 2026-09-22 — RG — Frente e verso    RG       22/09  ● Apr.│
│ 📁 02 Comprovantes       │ 📄 2026-09-20 — CNIS                   CNIS     20/09  ● Rec.│
│ 📁 03 Procurações e Contr│ 📄 2026-09-18 — Comprovante de Resid…  Comp.    18/09  ▲ 12d │
│ 📂 04 Processos          │ 📄 2026-09-15 — Procuração             Proc.    15/09  ● Apr.│
│   📂 2026-0042 · Apos…   │                                                              │
│     📁 01 Documentos do  │  ┌ Arraste arquivos aqui ou  [ Enviar arquivos ] ┐           │
│     📁 02 Requerimento   │  └──────────────────────────────────────────────┘            │
│ 📁 05 Enviados pelo Esc. │                                                              │
│ 📁 99 Arquivo            │  [Selecionar] [Baixar pasta .zip]  Ordenar: Data ▾  ☰ ▦      │
└──────────────────────────┴──────────────────────────────────────────────────────────────┘
```

- **Arrastar e soltar** para enviar do computador e para mover entre pastas. Upload múltiplo com progresso por arquivo e nova tentativa em caso de falha.
- **Seleção múltipla** (`Shift`/`Ctrl`) → mover, aprovar, baixar `.zip`, arquivar em lote.
- **Menu de contexto** (clique direito / toque longo): Abrir, Renomear, Mover para…, Alterar tipo, Aprovar/Rejeitar, Ver versões, Ver na conversa ↗, Copiar link interno, Arquivar.
- **Pré-visualização em painel lateral:** PDF e imagens (com zoom e rotação), áudio com player, vídeo. Documento do Office → baixar.
- **Versões:** "v2 · substituiu a v1 em 22/09 · enviada pelo cliente". A anterior abre em um clique.
- **Filtro do processo:** na aba do processo, a árvore mostra a gaveta toda, mas destaca e expande a pasta daquele processo.
- **"Ver na conversa ↗"** leva à mensagem original. O vínculo com o WhatsApp nunca se perde.
- **Visualização em lista (padrão) ou grade de miniaturas** (útil para fotos), lembrada por usuário.

### 8.5 Tela: Arquivos do escritório (`crm/arquivos`)

Visão geral para a gestão, com cinco filas prontas e busca global:

| Fila | O que mostra |
|------|--------------|
| **Triagem** | Tudo que chegou e ainda não foi classificado (§8.3) |
| **Para análise** | Classificados com status `recebido`, aguardando aprovação |
| **Vencendo** | Documentos com validade em até 30 dias (certidões, comprovantes, CNIS) |
| **Novos envios** | Envios do formulário aberto: protocolo, assunto, descrição, data marcada e identificação do contato, com "Vincular a processo" e "Criar negócio" |
| **Solicitações abertas** | Links enviados ao cliente e ainda não concluídos, com "último acesso há X dias" e botão "Lembrar cliente" |

Busca por nome do cliente, tipo, descrição, tag, período e origem, no servidor e paginada.

### 8.6 Checklist de documentos ("o que ainda falta")

Reusa `crm_checklist_templates` (`case_type`/`legal_area`). Ao abrir um processo, o modelo vira lista de itens com **"7 de 9"** e barra de progresso no topo da aba. Os itens são marcados automaticamente quando um documento do tipo correspondente é classificado; a equipe pode marcar à mão ("entregue em papel"). É o que resolve a causa C3, e o que o site do cartório não faz.

### 8.7 Portal de envio do cliente (celular) — dois modos

| | **A. Formulário aberto do escritório** (estilo cartório) | **B. Link personalizado** ("Pedir documentos") |
|---|---|---|
| Endereço | Fixo: `https://<dominio>/enviar` | Único por pedido: `https://<dominio>/docs/<token>` |
| Quem inicia | O cliente, quando quiser | A equipe, quando falta algo |
| Onde divulgar | Resposta automática do WhatsApp, bio/perfil, site, QR code na recepção e no cartão | Enviado pela conversa do WhatsApp |
| Campos de orientação | Todos (quem é + sobre o que é) | Só "recado" e "tem alguma data marcada?"; nome e caso já são conhecidos |
| Lista de documentos | Sugerida conforme o assunto escolhido, sem obrigar | Exatamente o que a equipe pediu |
| Identificação do cliente | Por WhatsApp/CPF informado; o envio entra **não verificado** | Pelo próprio link; entra verificado |

#### 8.7.1 Formulário aberto: o fluxo em três passos

O cliente vê uma etapa por tela, com barra "Passo 1 de 3". São poucos campos, todos em linguagem simples.

**Passo 1 · Quem é você**
- Nome completo *(obrigatório)*
- WhatsApp com DDD *(obrigatório; é por onde o escritório vai responder)*
- CPF *(opcional, com a explicação "ajuda a encontrar o seu cadastro mais rápido")*

**Passo 2 · Sobre o que é** *(os campos de orientação da demanda)*
- **Assunto**, em botões grandes, com rótulos que o cliente reconhece e não termos jurídicos: "Aposentadoria ou benefício do INSS", "Trabalho (demissão, direitos)", "Família (divórcio, pensão, guarda)", "Banco, compras ou contratos", "Outro assunto". A lista é configurável pelo escritório (D12).
- **Você já é cliente do escritório?** Sim / Não / Não sei.
- **Conte em poucas palavras o que aconteceu ou o que precisa** (caixa de texto, até 1.000 caracteres, com exemplo: *"Fui demitido em agosto e não recebi a rescisão"*).
- **Tem alguma data marcada?** (audiência, perícia, prazo) *(opcional, com seletor de data)*

**Passo 3 · Documentos**
- Conforme o assunto escolhido, aparece uma lista **sugerida** ("Para aposentadoria, geralmente precisamos de: RG, CPF, CNIS, comprovante de residência"), cada item com "Tirar foto" e "Escolher arquivo". Serve de guia e **não é obrigatória**.
- Há ainda um espaço livre "Outros documentos".
- Por último, a caixa de ciência LGPD (obrigatória) e o botão **ENVIAR**.

**Confirmação**
- Tela: *"Recebemos! Seu protocolo é **2026-000317**. O escritório vai falar com você pelo WhatsApp (61) 9••••-4321."*
- Em seguida, a inbox do escritório manda uma mensagem automática **para o WhatsApp informado** com o protocolo. Isso fecha o ciclo, confirma que o número está certo e avisa o verdadeiro dono do número se alguém usou o telefone dele.
- O protocolo pode ser citado pelo cliente em qualquer conversa, e a equipe o encontra na busca.

#### 8.7.2 O que acontece do lado do escritório

```
envio do formulário
 └─► cria crm_document_submission (protocolo)
      ├─ identifica o contato:
      │    WhatsApp igual a um contato existente ........ matched_phone
      │    senão, CPF igual .............................. matched_cpf
      │    mais de um candidato .......................... ambiguous → a equipe escolhe
      │    nenhum ........................................ new_contact (cria contato, sem criar negócio)
      ├─ arquivos → "00 Triagem" da gaveta do contato, já com o tipo do item escolhido
      ├─ nota na conversa do contato: "Envio pelo formulário · protocolo 2026-000317 · Assunto: Trabalho"
      └─ fila "Novos envios" em crm/arquivos + notificação
```

- **Cartão do envio** na Triagem e na fila "Novos envios": protocolo, assunto, descrição, data marcada (em destaque âmbar se faltarem menos de 15 dias), "já é cliente?" declarado, resultado da identificação e os arquivos. Ações: **Vincular a um processo**, **Criar negócio no funil** (já com área e descrição preenchidas), **Marcar como verificado**, **Spam**.
- **Cliente antigo não vira lead novo:** se o WhatsApp ou o CPF baterem, o envio vai para a gaveta existente e aparece no histórico. O negócio só é criado por decisão da equipe (D13), coerente com a regra do escritório.
- **Envio não verificado** (modo A) tem selo "não verificado" até alguém da equipe confirmar. Sem isso, qualquer pessoa poderia digitar o telefone de outro cliente e colocar arquivos na gaveta dele.
- A descrição e o assunto alimentam o funil: ao criar o negócio, a área do direito vem do assunto e o resumo vem da descrição, e isso define o modelo de subpastas do processo (§5.2).

#### 8.7.3 Tela do link personalizado (modo B)

```
┌───────────────────────────────┐
│  [logo]  Coimbra & Ruas       │
│  Advocacia                    │
├───────────────────────────────┤
│  Olá, Maria!                  │
│  Para seguirmos com o seu     │
│  pedido de aposentadoria,     │
│  precisamos destes documentos:│
│                               │
│  ☐ PPP                        │
│     [  📷 Tirar foto  ]       │
│     [  📎 Escolher arquivo ]  │
│                               │
│  ☐ Laudo médico               │
│     [  📷 Tirar foto  ]       │
│     [  📎 Escolher arquivo ]  │
│                               │
│  ✓ RG — recebido              │
│                               │
│  Quer deixar um recado?       │
│  [                         ]  │
│                               │
│  [      ENVIAR DOCUMENTOS   ] │
│                               │
│  🔒 Seus dados são usados só  │
│  para o seu atendimento. Saiba│
│  mais                         │
└───────────────────────────────┘
```

- **Um item por documento**, cada um com "Tirar foto" (abre a câmera direto) e "Escolher arquivo". Pode mandar várias fotos para o mesmo item (frente e verso).
- **Texto grande (mínimo 18 px), botões de 48 px, contraste AA**, linguagem simples e nenhuma palavra técnica.
- **Compressão da foto no próprio celular** antes do envio (máx. 2.000 px no lado maior), para funcionar em 3G e não estourar o plano de dados.
- **Envio item a item**: se a conexão cair, o que já subiu não se perde, e a tela mostra o que falta reenviar.
- **Confirmação clara ao final:** "Recebemos 2 documentos. Falta: Laudo médico. Você pode voltar a este link até 29/09."
- Os documentos caem na gaveta com `source: portal`, **já classificados** (o cliente escolheu o item), marcam o checklist e geram uma nota na conversa: "Maria enviou 2 documentos pelo link".

### 8.8 Acessibilidade e responsividade

- WCAG 2.2 AA: foco visível, navegação completa por teclado, `aria-live` para uploads e avisos de desfazer, alvos de toque ≥ 44 px, sem informação só por cor.
- Testado em 320, 375, 768, 1024 e 1440 px. No celular, a árvore de pastas vira um seletor no topo e a lista ocupa a largura toda.
- Respeita `prefers-reduced-motion`.
- Segue o design system do projeto (`docs/PLANO-DESIGN-SYSTEM-2026.md`) nos dois temas.

### 8.9 Textos de interface (amostra)

| Situação | Texto |
|----------|-------|
| Gaveta vazia | "Ainda não há documentos da Maria. Tudo o que ela enviar pelo WhatsApp aparece aqui sozinho." **[Pedir documentos]** |
| Triagem zerada | "Tudo classificado. Os novos arquivos vão aparecer aqui assim que chegarem." |
| Após classificar | "RG da Maria movido para 01 Documentos Pessoais. **Desfazer**" |
| Documento duplicado | "A Maria já tinha enviado este mesmo arquivo em 18/09. Nada foi duplicado." |
| Rejeitar | "Por que este documento não serve? O motivo pode ser enviado para a cliente." [Ilegível] [Cortado] [Vencido] [Outro…] |
| Link expirado (portal) | "Este link não está mais ativo. Fale com o escritório pelo WhatsApp para receber um novo." |

---

## 9. Portal de envio — superfície técnica e defesas

### 9.1 Rotas

No namespace `public` já existente (`core/config/routes.rb`):

- `GET  /docs/:token` → página (entrada Vite própria e enxuta, sem o bundle do dashboard, meta de < 80 KB gzip)
- `GET  /public/api/v1/document_requests/:token` → itens pendentes (rótulos apenas)
- `POST /public/api/v1/document_requests/:token/uploads` → um arquivo por requisição, ligado a um item
- `GET  /enviar` → formulário aberto (modo A), mesma entrada Vite
- `GET  /public/api/v1/document_submissions/form` → assuntos e listas sugeridas da conta (sem nenhum dado de cliente)
- `POST /public/api/v1/document_submissions` → cria o envio com os campos de orientação e devolve um token de upload de vida curta (2 h)
- `POST /public/api/v1/document_submissions/:upload_token/uploads` → arquivos do envio

Token: 32 bytes aleatórios; **só o digest** vai para o banco; expira em 7 dias (configurável); revogável; "Reenviar link" gera token novo e invalida o anterior.

### 9.2 Defesas (obrigatórias antes de expor)

| Vetor | Defesa |
|-------|--------|
| Enumeração de token | 32 bytes aleatórios, 404 genérico, tempo de resposta constante |
| Abuso / upload em massa | `rack-attack` por IP e por token; máx. 20 arquivos e 100 MB por solicitação; 25 MB por arquivo |
| Arquivo malicioso | Allowlist por **magic bytes** (PDF, JPEG, PNG, HEIC, WEBP); sem SVG, HTML ou executáveis; ClamAV opcional |
| Vazamento de dados | O portal **nunca lista** arquivos enviados nem dados do processo; mostra só rótulos dos itens e primeiro nome |
| Bot / spam | Honeypot + tempo mínimo de preenchimento; sem CAPTCHA (barreira real para o público do escritório) |
| Link encaminhado | Expiração curta, revogação, IP e user-agent registrados a cada acesso, alerta de acesso após conclusão |
| LGPD | Aviso de tratamento com finalidade e base legal na página; registro de ciência com data e hora |
| **Formulário aberto: gaveta alheia** | Envio do modo A entra **não verificado**; mensagem de confirmação vai para o WhatsApp informado (o dono real do número fica sabendo); a equipe confirma antes de tratar como documento do cliente |
| **Formulário aberto: descobrir quem é cliente** | A resposta é **idêntica** com ou sem cadastro; o formulário nunca mostra nome, processo ou documento existente |
| **Formulário aberto: volume** | Rate limit por IP, por telefone (máx. 3 envios/dia) e global por conta; mesmos limites de tamanho do modo B; fila "Spam" com um clique |
| **Dados informados** | Validação no servidor: nome 3–120 caracteres, telefone brasileiro válido, CPF com dígito verificador, descrição ≤ 1.000; CPF criptografado |

É o único componente exposto à internet sem autenticação. **Revisão de segurança dedicada no gate da F4**, na linha de `SECURITY_AUDIT.md`.

---

## 10. Permissões, auditoria e LGPD

- **`CrmDocumentPolicy`** espelhando `CrmDeal.visible_to`: administrador vê tudo; agente vê o que pertence às suas inboxes/times. Padrão restritivo.
- **Download auditado:** sem URL pública permanente. O controller verifica a permissão, registra o acesso em `crm_audit_events` e redireciona para URL assinada de 5 minutos.
- **Exclusão:** agente arquiva (vai para `99 Arquivo`); purga definitiva só administrador, com confirmação e registro (D4). Documento de processo ativo não pode ser purgado.
- **Trilha completa:** criação, classificação, movimentação, renomeação, aprovação, rejeição, download, exclusão, acesso ao portal e execuções de backup.
- **Criptografia:** `token_digest` e metadados sensíveis sob Active Record Encryption, já habilitada nas duas VPS.
- **Retenção:** política configurável (D6), executada por job com **relatório prévio e aprovação**. Nunca exclusão silenciosa.
- **Espelho em disco:** acessível apenas por SSH/SFTP de administração. Nunca servido por HTTP.

---

## 11. Backup diário no Google Drive (opcional)

### 11.1 O que o escritório vê: Configurações → Arquivos → Backup

```
┌─ Backup no Google Drive ────────────────────────────────────────────────────────────────┐
│  [●━━] Ativado                                                                          │
│                                                                                         │
│  Conta Google     escritorio@coimbraruas.adv.br  ✓ conectada     [Trocar conta]         │
│  Pasta de destino Drive Compartilhado ▸ Backup ChusteRM          [Escolher pasta]       │
│  Horário          [01:00 ▾]  (horário de Brasília)                                      │
│  Incluir          [✓] Documentos   [✓] Versões anteriores   [ ] Arquivados              │
│  Excluídos        Mover para "_Excluídos" no Drive e apagar após [30 ▾] dias            │
│                                                                                         │
│  Último backup    Hoje, 01:07 · ✓ Sucesso · 38 novos · 4 movidos · 212 MB · 6 min       │
│  Próximo          Amanhã, 01:00                                                         │
│  Uso no Drive     18,4 GB de 2 TB                                                       │
│                                                                                         │
│  [ Fazer backup agora ]   [ Testar restauração ]   [ Ver histórico ]                    │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

- **Liga/desliga por conta.** Desligado, nada é enviado e o cofre na VPS continua funcionando normalmente.
- **"Testar restauração"** escolhe três arquivos aleatórios já enviados, baixa do Drive, confere o checksum e mostra o resultado. Transforma o ensaio de restauração numa ação de um clique.
- **Histórico** lista cada execução (`crm_storage_runs`) com contagens, volume, duração e erro, se houver.

### 11.2 O que aparece no Drive

A **mesma árvore da §5**, legível por qualquer pessoa com acesso à pasta:

```
Backup ChusteRM/
├── Clientes/
│   └── Maria da Silva Souza · C000123/
│       ├── 01 Documentos Pessoais/
│       │   └── 2026-09-22 — RG — Frente e verso.pdf
│       └── 04 Processos/
│           └── 2026-0042 · Aposentadoria por Idade · INSS/
│               └── 01 Documentos do Caso/2026-09-20 — CNIS.pdf
├── _Excluídos/
│   └── 2026-09-22/…                 ← retido por N dias, depois apagado
└── _Controle/
    ├── manifesto-2026-09-22.json    ← lista completa com checksums
    └── LEIA-ME.txt                  ← como restaurar, em português
```

- **Arquivo arquivado ou excluído no CRM** → movido para `_Excluídos/<data>/` e apagado depois do prazo. Um erro no CRM nunca apaga o backup na mesma noite.
- **Versões anteriores** (se marcado) → vão para `99 Arquivo/`, com o sufixo `(v1)`, igual ao espelho.
- **Descrição de cada arquivo no Drive** recebe o id interno e o checksum, para auditoria e restauração.

### 11.3 Como funciona por dentro

```
cron 01:00 BRT ─► Crm::Documents::DriveBackupJob(account_id)
                   ├─ lock Redis por conta (nunca duas execuções ao mesmo tempo)
                   ├─ refresh do token OAuth; falhou → run failed + alerta "reconecte a conta"
                   ├─ garante a pasta raiz e as pastas da árvore (cache folder_path → remote_id)
                   ├─ para cada documento alterado desde o último sucesso (lotes de 200):
                   │    PathBuilder → caminho desejado
                   │    compara com crm_storage_sync_entries:
                   │      igual ................ pula
                   │      só caminho mudou ..... PATCH (parents/name) — sem reenviar bytes
                   │      checksum mudou ....... upload (resumable se > 5 MB)
                   │      arquivado ............ move para _Excluídos/<data>/
                   ├─ grava o manifesto em _Controle/
                   ├─ limpa _Excluídos vencidos
                   └─ fecha crm_storage_runs + auditoria; 2 falhas seguidas → alerta
```

- **Incremental de verdade:** só processa o que mudou. Renomear um cliente move uma pasta; não reenvia centenas de arquivos.
- **Primeiro backup em etapas:** com teto configurável por noite (padrão 20 GB), continuando de onde parou na noite seguinte. Fica bem abaixo do limite de 750 GB/dia de upload por usuário do Google Drive e não compete com o uso diurno do servidor.
- **Retentativa:** backoff exponencial com *jitter* em `429`/`5xx`; erro permanente num arquivo (`4xx`) marca a entrada como `failed` e segue com os demais. A execução fecha como `partial`, não trava.
- **Verificação:** o `md5Checksum` que o Drive devolve é comparado com o MD5 do blob (o `checksum` do Active Storage já é MD5 em base64). Divergência → reenvio e registro.
- **Fila própria de baixa prioridade** no Sidekiq, para não atrasar mensagens de WhatsApp.
- **Cliente Drive:** `google-apis-drive_v3` sobre o `googleauth` já presente, encapsulado em `Crm::Documents::Drive::Client`, para trocar a implementação sem tocar no motor.

### 11.4 Escopo e conta do Google

- O consentimento já pede **`drive.file`**: o ChusteRM só enxerga **os arquivos e pastas que ele mesmo cria ou que o usuário escolhe** explicitamente. Nunca lê o restante do Drive do escritório. É a permissão mínima correta.
- Consequência prática: para gravar dentro de um **Drive Compartilhado** existente, o administrador escolhe a pasta pelo **Google Picker** (botão "Escolher pasta"), o que concede acesso àquela pasta. Sem isso, o sistema cria "Backup ChusteRM" no Meu Drive da conta conectada. As chamadas usam `supportsAllDrives=true`.
- **Conta pessoal do Google tem 15 GB**, divididos com Gmail e Fotos, e estoura em meses. **Recomendação: Google Workspace do escritório com Drive Compartilhado** (D3). Num Drive Compartilhado os arquivos pertencem ao escritório, não a uma pessoa: se alguém sair da equipe, o backup continua.
- A conta conectada deve ser de **função** (ex.: `sistemas@...`), não pessoal de um advogado.

### 11.5 Criptografia no Drive

Os arquivos sobem **legíveis** (criptografados em repouso pelo próprio Google), porque o objetivo declarado é poder abrir o backup sem o sistema. Criptografar do lado do cliente tornaria o backup ilegível sem a chave, o que contraria esse objetivo. A decisão fica registrada como D10.

---

## 12. Mapa de implementação

### Backend (`core/`)

```
db/migrate/…_create_crm_document_folders.rb
db/migrate/…_create_crm_documents.rb
db/migrate/…_create_crm_document_versions.rb
db/migrate/…_create_crm_document_folder_templates.rb
db/migrate/…_create_crm_document_types.rb
db/migrate/…_create_crm_document_requests.rb
db/migrate/…_create_crm_document_submissions.rb
db/migrate/…_create_crm_storage_sync_entries.rb
db/migrate/…_create_crm_storage_runs.rb
db/seeds/crm_document_defaults.rb                    # modelos de pasta + catálogo de tipos

app/models/crm_document.rb
app/models/crm_document_folder.rb
app/models/crm_document_version.rb
app/models/crm_document_folder_template.rb
app/models/crm_document_type.rb
app/models/crm_document_request.rb
app/models/crm_document_submission.rb
app/models/crm_storage_sync_entry.rb
app/models/crm_storage_run.rb

app/listeners/crm_document_intake_listener.rb
app/jobs/crm/documents/ingest_attachment_job.rb
app/jobs/crm/documents/mirror_sync_job.rb
app/jobs/crm/documents/mirror_reconcile_job.rb
app/jobs/crm/documents/drive_backup_job.rb
app/jobs/crm/documents/purge_archived_job.rb

app/services/crm/documents/ingestor.rb               # regras de entrada + dedup
app/services/crm/documents/drawer_provisioner.rb     # cria gaveta pelo modelo
app/services/crm/documents/classifier.rb             # regras determinísticas
app/services/crm/documents/router.rb                 # doc_type → slot → pasta
app/services/crm/documents/checklist_matcher.rb
app/services/crm/documents/naming/sanitizer.rb
app/services/crm/documents/naming/file_namer.rb
app/services/crm/documents/naming/path_builder.rb
app/services/crm/documents/sync/planner.rb           # diff: skip / move / upload / trash
app/services/crm/documents/sync/vps_mirror.rb        # hardlink atômico
app/services/crm/documents/sync/drive_target.rb
app/services/crm/documents/drive/client.rb           # wrapper do Drive v3
app/services/crm/documents/drive/restore_probe.rb    # "Testar restauração"
app/services/crm/documents/zip_exporter.rb
app/services/crm/document_requests/creator.rb
app/services/crm/document_requests/intake.rb
app/services/crm/document_submissions/creator.rb      # valida campos, protocolo
app/services/crm/document_submissions/contact_matcher.rb  # WhatsApp → CPF → novo
app/services/crm/document_submissions/confirmation_notifier.rb  # mensagem com protocolo

app/controllers/api/v1/accounts/crm/documents_controller.rb
app/controllers/api/v1/accounts/crm/document_folders_controller.rb
app/controllers/api/v1/accounts/crm/document_triage_controller.rb
app/controllers/api/v1/accounts/crm/document_requests_controller.rb
app/controllers/api/v1/accounts/crm/document_downloads_controller.rb
app/controllers/api/v1/accounts/crm/document_storage_settings_controller.rb
app/controllers/api/v1/accounts/crm/document_storage_runs_controller.rb
app/controllers/public/api/v1/document_requests_controller.rb
app/controllers/public/api/v1/document_submissions_controller.rb
app/controllers/document_portal_controller.rb

app/policies/crm_document_policy.rb
app/views/api/v1/accounts/crm/documents/*.json.jbuilder
lib/tasks/crm_documents.rake                         # backfill, reconcile, verify
config/schedule.yml                                  # drive_backup, mirror_reconcile, purge
config/locales/*.yml                                 # pt-BR incluído
```

`Sync::Planner` é compartilhado pelo espelho e pelo Drive; cada destino implementa só `ensure_folder`, `upload`, `move` e `trash`. Funções < 50 linhas e arquivos < 800, conforme as regras do projeto.

### Frontend (`core/app/javascript/dashboard/`)

```
routes/dashboard/crm/pages/Documents.vue                    # filas + busca global
routes/dashboard/crm/pages/DocumentTriage.vue               # Caixa de Triagem
routes/dashboard/crm/components/documents/DocumentDrawer.vue
routes/dashboard/crm/components/documents/FolderTree.vue
routes/dashboard/crm/components/documents/DocumentList.vue  # lista virtualizada / grade
routes/dashboard/crm/components/documents/DocumentPreview.vue
routes/dashboard/crm/components/documents/UploadDropzone.vue
routes/dashboard/crm/components/documents/TriagePanel.vue
routes/dashboard/crm/components/documents/TypeChips.vue
routes/dashboard/crm/components/documents/ChecklistBar.vue
routes/dashboard/crm/components/documents/RequestDocumentsModal.vue
routes/dashboard/crm/components/documents/UndoToast.vue
routes/dashboard/settings/crm/DocumentsSettings.vue         # modelos, catálogo, disco
routes/dashboard/settings/crm/DriveBackupSettings.vue
store/modules/crmDocuments.js
api/crmDocuments.js
document_portal/                                            # entrada Vite do portal público
```

---

## 13. Fases, entregáveis e gates

Tudo sob a flag `crm_documents` (desligada por padrão). Rollback = desligar a flag; as migrations são aditivas e nada existente quebra. Nenhuma fase avança sem a evidência do gate.

### F0 — Decisões e baseline · ~0,5 dia
- Responder D1–D10 (§18) e registrar em `DECISOES.md`.
- Medir o volume atual: contagem e soma de bytes dos anexos existentes por conta.
- Confirmar espaço livre no volume `core-storage` das duas VPS e se o sistema de arquivos suporta hardlink dentro do volume.
- **Gate:** número real de GB em mãos e decisões registradas.

### F1 — Fundação, nomenclatura e cofre manual · ~4 dias
Migrations, modelos, seeds (modelos de pasta e catálogo), `Sanitizer`/`FileNamer`/`PathBuilder`, policy, CRUD de pastas e documentos, upload manual, gaveta no processo e no contato, desfazer, download auditado, `.zip`, auditoria, i18n.
- **Gate:** a equipe cria a gaveta, sobe arquivos, move, renomeia, baixa a pasta em `.zip` e a extrai **no Windows** sem erro; agente de outra inbox recebe 404; tabela de testes do `Sanitizer` cobre acentos NFD, nomes reservados e limites; cobertura ≥ 80% no módulo.

### F2 — Captura automática e Caixa de Triagem · ~3 dias
Listener, job de ingestão, dedup, classificador determinístico, roteamento por `slot`, tela de Triagem com teclado e versão mobile, broadcast em tempo real, rake de backfill.
- **Gate:** três arquivos enviados pelo WhatsApp em horários diferentes aparecem na gaveta certa em < 10 s; webhook duplicado não duplica; a secretária tria 20 documentos reais com mediana ≤ 5 s cada; backfill de uma conta reproduzível.

### F3 — Checklist, status, versões e modelos por área · ~2,5 dias
Integração com `crm_checklist_templates`, barra "X de Y", aprovação/rejeição com motivo, versionamento, validade e fila "Vencendo", modelos de pasta por área editáveis, busca e filtros.
- **Gate:** processo trabalhista nasce com as subpastas trabalhistas; reenvio vira versão e preserva a anterior; busca em < 500 ms com 10 mil documentos sintéticos.

### F4 — Portal de envio do cliente (dois modos) · ~4 dias
Modo B: solicitação, token, envio do link pela conversa, marcação do checklist. Modo A: formulário aberto em três passos com os campos de orientação, protocolo, identificação por WhatsApp/CPF, mensagem de confirmação no WhatsApp, fila "Novos envios" com cartão do envio e "Criar negócio". Comum: compressão no celular, upload item a item, nota na conversa, defesas da §9.2.
- **Gate:** revisão de segurança aprovada; teste de ponta a ponta em celular Android simples em 3G; token expirado e tipo proibido recusados; envio com telefone de cliente existente cai na gaveta dele como "não verificado" e dispara a confirmação; resposta do formulário idêntica para cliente e não cliente; três pessoas de fora da equipe completam o formulário sem ajuda.

### F5 — Espelho na VPS e backup no Google Drive · ~3,5 dias
`Sync::Planner`, espelho por hardlink com reconciliação, `restic` no host, cliente Drive, Picker, backup incremental, `_Excluídos`, manifesto, tela de configuração, histórico, "Testar restauração", alertas.
- **Gate:** espelho confere 100% com o `PathBuilder` após reconciliação; renomear um cliente move a pasta no Drive sem reenviar bytes; backup completo executado; restauração de arquivos a partir do Drive com checksum conferido; alerta disparado em falha simulada (token revogado).

### F6 — Assistência por IA (opcional) · ~3 dias
Sugestão de tipo e descrição pelo orchestrator, OCR em avaliação, "juntar fotos em um PDF".
- **Gate:** precisão da sugestão ≥ 85% em amostra real de 100 documentos; nenhuma mudança automática de status.

**Total: 19 a 22 dias úteis de trabalho efetivo** (F6 à parte). F1+F2 já acabam com o reenvio manual, que é o gargalo principal.

---

## 14. Testes e critérios de aceite

TDD, cobertura mínima de 80%, três níveis.

**Unitários (RSpec):** `Sanitizer` e `FileNamer` (tabela de casos: acentos, NFD, caracteres proibidos, nomes reservados, truncamento, colisão); `PathBuilder` (determinismo, homônimos); `Sync::Planner` (skip/move/upload/trash); dedup; idempotência; classificador; roteamento com um e com vários processos; versionamento; token; policy.

**Integração (request specs):** CRUD, triagem, download auditado, `.zip`, portal (válido, expirado, revogado, tipo proibido, tamanho, rate limit), configuração do backup; Drive com cliente dublê gravando as chamadas.

**E2E (Playwright), as jornadas que importam:**
1. Cliente manda PDF no WhatsApp → aparece na Triagem da gaveta certa → secretária classifica com `1` + `Enter` → arquivo está em `01 Documentos Pessoais` com o nome padrão.
2. Equipe pede documentos → link chega na conversa → cliente envia pelo celular → checklist completa e a conversa recebe a nota.
4. Pessoa sem cadastro abre `/enviar` → preenche os três passos → recebe protocolo na tela e no WhatsApp → envio aparece em "Novos envios" → equipe clica em "Criar negócio" e o processo nasce com a área e o resumo preenchidos.
3. Backup roda → arquivo aparece no Drive na pasta certa → cliente é renomeado → pasta é movida no Drive → "Testar restauração" confere o checksum.

**Critérios de aceite (amostra):**
- **CA-01:** Dado um contato com processo aberto, quando envia um PDF com a legenda "meu rg", então em até 10 s existe documento `source: whatsapp`, `doc_type: rg` sugerido, visível na Triagem, e a tela atualiza sem recarregar.
- **CA-02:** Dado o mesmo arquivo enviado duas vezes, então existe **um** documento e um evento de reenvio.
- **CA-03:** Dado um documento classificado como RG com descrição "Frente e verso" em 22/09/2026, então o caminho é `Clientes/<Nome> · C<id>/01 Documentos Pessoais/2026-09-22 — RG — Frente e verso.<ext>` na tela, no espelho, no Drive e no `.zip`.
- **CA-04:** Dado um agente sem acesso à inbox do contato, quando pede o documento pela API, então recebe 404 e o acesso é registrado.
- **CA-05:** Dada uma solicitação expirada, quando o cliente abre o link, então vê a mensagem de link expirado e nenhum dado do processo.
- **CA-06:** Dado um documento arquivado no CRM, quando o backup roda, então ele está em `_Excluídos/<data>/` no Drive e só é apagado após o prazo configurado.
- **CA-08:** Dado um envio pelo formulário aberto com o WhatsApp de um contato existente, então os arquivos vão para a Triagem da gaveta dele com selo "não verificado", nenhum negócio novo é criado e o número recebe a mensagem com o protocolo.
- **CA-07:** Dado o token do Google revogado, quando o backup roda duas noites seguidas, então as duas execuções ficam `failed` e o administrador recebe o alerta "reconecte a conta Google".

---

## 15. Riscos e mitigação

| Risco | Prob. | Impacto | Mitigação |
|-------|-------|---------|-----------|
| Disco da VPS enche | Média | Alto | Medição na F0; alertas em 70/85%; espelho por hardlink não duplica espaço; troca para S3-compatible prevista em `storage.yml` |
| Alguém edita arquivo no espelho e corrompe o blob | Baixa | Alto | Arquivos `0444`; checksum conferido na reconciliação; alerta em divergência |
| Token do Google expira e o backup para sem ninguém perceber | Média | Alto | Refresh automático, alerta após 2 falhas, tela com "último backup", camada `restic` independente |
| Primeiro backup demora dias | Alta | Baixo | Teto por noite e continuação; status "backup inicial em andamento — 42%" |
| Nomes longos ou acentos quebram o `.zip` no Windows | Média | Médio | `Sanitizer` único, com limites e teste de extração no gate da F1 |
| Portal público vira vetor de abuso | Baixa | Alto | Defesas da §9.2 + revisão de segurança no gate da F4 |
| Classificação automática erra e esconde documento | Média | Médio | Toda classificação automática é desfazível, registrada e mostra "classificado automaticamente"; na dúvida, fica na Triagem |
| Documento vazado por link de download | Baixa | Crítico | URL assinada de 5 min, download auditado, espelho nunca servido por HTTP |
| Quota do Drive estoura | Média | Médio | D3 (Workspace + Drive Compartilhado), uso exibido na tela, alerta |
| Backfill pesado degrada produção | Média | Médio | Lotes de 500, fila de baixa prioridade, janela noturna |

---

## 16. Custos

**Armazenamento na VPS (sem duplicação, graças ao hardlink)**

| Cenário | Clientes | Docs/cliente | Média | Total |
|---------|----------|--------------|-------|-------|
| Atual (estimado, a confirmar na F0) | ~300 | 15 | 1,5 MB | ~7 GB |
| 3 anos | ~1.000 | 15 | 1,5 MB | ~22 GB |
| Pessimista (muita foto e vídeo) | ~1.000 | 40 | 2,5 MB | ~100 GB |

O servidor atual absorve os dois primeiros cenários. No pessimista, armazenamento compatível com S3 custa na faixa de US$ 5/mês por 250 GB, e `storage.yml` já suporta a troca.

**Google Drive:** sem custo adicional se o escritório já tiver Workspace (os planos Business incluem de 30 GB a 5 TB por usuário, conforme o plano). Conta pessoal de 15 GB não serve como destino de longo prazo.

**Licenças:** zero. Só uma gem oficial do Google (`google-apis-drive_v3`) a mais.

**Desenvolvimento:** 19–22 dias úteis de trabalho efetivo, em fases, com valor já na F2.

---

## 17. Operação (runbook resumido)

| Situação | Onde olhar | Ação |
|----------|-----------|------|
| "O documento que a cliente mandou não apareceu" | Triagem → filtro por cliente; `crm_audit_events` do anexo | Se não houver registro: `rake crm:documents:backfill[account,since]` para o período |
| Backup falhou | Configurações → Backup → Histórico | Token → "Trocar conta"; quota → liberar espaço; outros → "Fazer backup agora" após corrigir |
| Espelho divergente | Log do `MirrorReconcileJob` | `rake crm:documents:mirror:reconcile[account]` |
| Restaurar do Drive com o sistema fora do ar | `_Controle/LEIA-ME.txt` no Drive | Baixar a pasta do cliente; o manifesto confirma a integridade |
| Restaurar a VPS inteira | `docs/execution/F0-RESTORE-DRILL-*.md` | Dump do Postgres + volume + chaves de criptografia, **juntos** |

Ensaio de restauração trimestral registrado no formato que o projeto já usa.

---

## 18. Decisões a confirmar antes da F1

| ID | Decisão | Recomendação |
|----|---------|--------------|
| **D1** | Armazenamento: disco local da VPS ou S3-compatible? | **Local agora**; migrar ao passar de 60% do disco. |
| **D2** | Construir o portal público de envio (F4)? | **Sim.** É o pedido explícito da cliente, com revisão de segurança no gate. |
| **D3** | Conta do Google para o backup | **Workspace do escritório + Drive Compartilhado**, conectado por conta de função. |
| **D4** | Quem pode excluir documento definitivamente? | **Só administrador**, com confirmação e auditoria. Agente arquiva. |
| **D5** | Anexos enviados **pela equipe** entram no cofre? | **Sim**, em `05 Enviados pelo Escritório`. |
| **D6** | Retenção e expurgo | Definir com a cliente (sugestão: 5 anos após o encerramento do caso), com relatório prévio. |
| **D7** | Identificação da gaveta: `Nome · C000123` ou incluir CPF? | **Nome + código interno.** CPF fica nos metadados, fora dos caminhos (LGPD). |
| **D8** | Manter o espelho legível em disco na VPS? | **Sim, por hardlink** (sem custo de espaço). Desligável. |
| **D9** | Documento com classificação de alta confiança sai da Triagem sozinho? | **Não no início.** Tudo passa pela Triagem nas primeiras semanas; liga-se o automático quando a precisão medida justificar. |
| **D10** | Criptografar os arquivos antes de enviar ao Drive? | **Não**, para manter o backup legível sem o sistema; confiar na criptografia em repouso do Google Workspace. |
| **D12** | Quais assuntos aparecem no formulário aberto e quais documentos sugerir em cada um? | Começar com 5 assuntos (INSS, Trabalho, Família, Banco/consumo, Outro) e as listas do catálogo; a cliente revisa os textos. |
| **D13** | Envio de pessoa sem cadastro cria negócio no funil automaticamente? | **Não.** Cria só o contato e o cartão em "Novos envios"; a equipe decide com "Criar negócio". |
| **D14** | Pedir código de confirmação por WhatsApp antes de aceitar o envio do formulário aberto? | **Não no início**, por ser uma barreira para o público do escritório; o envio entra "não verificado" e a confirmação pós-envio avisa o dono do número. Reavaliar se houver abuso. |
| **D11** | Estrutura de pastas e nomes da §5 | Validar com a cliente **antes da F1**: mudar depois é possível (o motor move tudo), mas custa reorganizar o hábito da equipe. |

---

## 19. Próximo passo

1. Apresentar à cliente a §0 e a árvore de pastas da §5.2 para validação (D11). É a parte que ela vai usar todos os dias.
2. Responder D1–D10 e D12–D14 e autorizar a F0 (meio dia), que devolve o volume real de GB e confirma o suporte a hardlink no volume.
