# Execução — Cofre de Documentos (módulo Arquivos)

Especificação: `PROJETO-COFRE-DOCUMENTOS.md` (raiz). Decisões: `DECISOES.md` → ADR-DOC.
Branch: `feat/crm-documents-vault`. Este arquivo é o registro vivo do que foi feito, como verificar e o que falta.

## Como ligar o módulo numa conta

O módulo fica desligado por padrão. Liga por conta (ADR-DOC, D15):

```ruby
# rails console
Crm::Documents::Feature.enable!(Account.find(ID))
Crm::Documents::Feature.disable!(Account.find(ID))
```

Com o módulo desligado, todas as rotas `crm/document*` respondem 404.

## Como rodar os testes do módulo (Windows, Postgres do compose na porta 5436)

```bash
cd core
export $(grep '^POSTGRES_PASSWORD=' ../.env | xargs)
POSTGRES_HOST=127.0.0.1 POSTGRES_PORT=5436 POSTGRES_USERNAME=chusterm RAILS_ENV=test \
  bundle exec rspec spec/services/crm/documents spec/models/crm_document_spec.rb \
  spec/models/crm_document_folder_spec.rb spec/controllers/api/v1/accounts/crm/documents
```

Se o banco de teste estiver defasado em relação à branch, recarregue a partir do `schema.rb` (não rode `db:migrate` no banco de teste e comite o dump: ele traz tabelas de outras branches):

```bash
... RAILS_ENV=test bundle exec rails db:schema:load
```

## Ledger

### F0 — Decisões e baseline

| Item | Status | Evidência |
|------|--------|-----------|
| Decisões D1–D14 registradas | feito (provisórias) | `DECISOES.md` → ADR-DOC |
| D15: flag por `accounts.settings` (bitmask de features no limite) | feito | `DECISOES.md` → ADR-DOC; `Crm::Documents::Feature` |
| Volume atual de anexos por conta nas VPS | feito (22/09, somente leitura) | ver "Medição de produção" abaixo |
| Espaço livre do volume `core-storage` e suporte a hardlink | feito | ext4 nas duas VPS (hardlink suportado); espaço abaixo |

#### Medição de produção (22/09/2026, somente leitura, transação `read_only`)

**KVM4 — crm.coimbraeruas.com.br (cliente):**

| Item | Valor |
|------|-------|
| Disco `/` | 193 GB, **130 GB usados (68%)**, 64 GB livres |
| Volume `core-storage` (arquivos do app) | 4,6 GB |
| Banco (`chusterm_postgres-data`) | 11 GB |
| `/opt/chusterm-backups` | **56 GB** — 8 backups de pré-deploy de ~6,8 GB sem rotação + dump de 23/07 (2,7 GB) |
| Imagens Docker / cache de build | 30 GB (27 GB recuperáveis) / 14 GB |
| Contatos | 3.578 (195 com anexo de documento) |
| Anexos de documento (imagem, vídeo, arquivo) | 3.356, **4,5 GB**, desde 21/05/2026 |
| Ritmo | ~1.000 arquivos e ~1 GB por mês (mai 1,3 GB; jun 0,5; jul 1,0; ago 1,1) |
| Por tipo | JPEG 1.693 (224 MB), PDF 1.024 (1,7 GB), WebP 394 (61 MB), DOCX 128, MP4 87 (912 MB), MOV 15 (**1,5 GB**) |
| Recebidos × enviados pela equipe | 1.739 × 2.861 |
| Imagens < 40 KB | 239 |
| Áudios (fora do cofre) | 2.102, 88 MB |

**Chuster — crm.chuster.tech (canário):** disco 96 GB, 43% usado; nenhum contato nem anexo.

**Conclusões:**

1. **O cofre não pressiona o disco; os backups sim.** Documentos são 4,5 GB e crescem ~1 GB/mês. Os backups de pré-deploy crescem 6,8 GB **a cada deploy**, sem rotação: com 64 GB livres, o disco da cliente lota em uns 9 deploys, com ou sem cofre. **Recomendação:** rotação no `/root/predeploy-backup.sh` (manter os 3 últimos + 1 semanal) e cópia externa. Não apaguei nada: backup de produção é irreversível e o espaço ainda não é urgente.
2. **D1 confirmada:** disco local continua adequado para os documentos. O gatilho "migrar ao passar de 60%" foi pensado para o volume de documentos; aqui o que passa de 60% são backups e imagens.
3. **Cópia própria por hardlink:** copiar os anexos para o cofre dobraria 4,5 GB (+1 GB/mês). Como o serviço é Disk em ext4, a cópia vira hardlink: arquivo independente, zero espaço extra (implementado em seguida).
4. **Figurinhas são WebP** (394): a marca "provável figurinha" passa a considerar WebP sem legenda, não só o tamanho.
5. **Vídeo de iPhone passa de 50 MB** (MOV médio ~100 MB): com o limite do upload, provas em vídeo ficariam fora do cofre. Limite da captura de conversa sobe para 200 MB (o upload da equipe segue em 50 MB, que é o corte do nginx).

Query de dimensionamento (somente leitura):

```sql
SELECT a.account_id, count(*) AS anexos, pg_size_pretty(sum(b.byte_size)) AS volume
FROM attachments a
JOIN active_storage_attachments asa ON asa.record_type = 'Attachment' AND asa.record_id = a.id
JOIN active_storage_blobs b ON b.id = asa.blob_id
GROUP BY a.account_id ORDER BY sum(b.byte_size) DESC;
```

### F1 — Fundação, nomenclatura e cofre manual

| Item | Status | Onde |
|------|--------|------|
| Migration aditiva (tipos, modelos de pasta, pastas, documentos) | feito | `db/migrate/20260922000001_create_crm_documents_foundation.rb` |
| Catálogo padrão (19 tipos, gaveta, 6 modelos de processo) | feito | `config/crm_documents/defaults.yml`, `Crm::Documents::Defaults` |
| Models com validações (profundidade 5, ciclo, nome único entre irmãs, pasta do mesmo contato) | feito | `app/models/crm_document*.rb` |
| Nomenclatura: `Sanitizer`, `FileNamer`, `Extension`, `PathBuilder` | feito | `app/services/crm/documents/naming/` |
| Provisionamento da gaveta e da pasta de processo por área | feito | `DrawerProvisioner`, `CaseFolderProvisioner` |
| Roteamento por tipo (slot) | feito | `Crm::Documents::Router` |
| Upload com identificação pelo conteúdo, allowlist, limite e dedup por checksum | feito | `Crm::Documents::Uploader` |
| Visibilidade (admin tudo; agente pelos contatos que atende) | feito | `Crm::Documents::Access` |
| API (pastas, documentos, tipos, download auditado) | feito | `app/controllers/api/v1/accounts/crm/document*_controller.rb`, rotas em `config/routes.rb` (namespace `crm`) |
| Frontend: aba Arquivos no negócio | feito | `routes/dashboard/crm/components/documents/`, `DealDetailsOperational.vue` |
| Frontend: aba Arquivos no drawer do contato | feito | `ContactManageView.vue` (só com o módulo ligado) |
| Desfazer (toast) em mover/classificar/arquivar | pendente | hoje confirma com aviso simples; arquivar é reversível por `restore` |
| Revisão de segurança dedicada da F1 | feita, achados corrigidos | ver "Revisão de segurança" abaixo |
| Download da pasta em `.zip` | pendente | depende de decidir a gem `rubyzip` |

**Escolhas de implementação registradas aqui (não mudam a especificação):**

- Pasta do processo: `AAAA-NNNN · <título do negócio>`, com ano de criação e id do negócio. O CRM não tem número sequencial por ano; o id é estável e único.
- "Arquivar" = `archived_at` (some das listas, restaurável). "Descartar" na triagem = mover para `99 Arquivo` (continua visível). São ações diferentes de propósito.
- Contato apagado: documentos saem pelo model (`Contact has_many :crm_documents, dependent: :destroy`, que apaga o arquivo); pastas caem por cascade no banco.
- Violação de índice único durante o provisionamento roda em savepoint (`requires_new`), para não abortar a transação de quem chamou.

**Testes:** 93 exemplos, 0 falhas (nomenclatura, models, provisionamento, roteamento, upload, acesso, API).

**API (todas sob `/api/v1/accounts/:account_id/crm/`, 404 com o módulo desligado ou fora da visibilidade):**

| Método e rota | O que faz |
|---------------|-----------|
| `GET document_folders?contact_id=&deal_id=` | Cria a gaveta (e a pasta do processo, com `deal_id`) na primeira visita; devolve pastas com contagem |
| `POST document_folders` | Pasta comum (`contact_id`, `parent_id`, `name`) |
| `PATCH document_folders/:id` | Renomeia/move (`folder[name|parent_id|position]`); pasta do modelo mantém o slot |
| `DELETE document_folders/:id` | Arquiva pasta comum vazia; pasta do modelo nunca |
| `GET document_types` | Catálogo de tipos da conta |
| `GET documents?contact_id=&folder_id=&deal_id=&status=&doc_type=&q=&archived=&page=&per_page=` | Lista paginada com caminho e link de download |
| `POST documents` (multipart) | Upload (`file`, `contact_id`, `folder_id`, `deal_id`, `doc_type`, `description`, `document_date`); 201 novo, 200 + `duplicate: true` se o arquivo já existia |
| `PATCH documents/:id` | Classificar (da triagem, leva para a pasta do tipo), mover, renomear (trava o nome), aprovar/rejeitar (motivo obrigatório) |
| `DELETE documents/:id` · `POST documents/:id/restore` | Arquivar / restaurar |
| `DELETE documents/:id/purge` | Apagar de vez, com arquivo — só administrador |
| `GET documents/:id/download?disposition=inline` | Audita e redireciona para URL assinada de 5 minutos |

Toda ação grava em `crm_audit_events` (`document_created`, `document_resent`, `document_updated`, `document_archived`, `document_restored`, `document_purged`, `document_downloaded`, `document_folder_*`), com IP e user-agent.

**Revisão de segurança (2026-09-22, agente security-reviewer sobre `27fe796d67..HEAD`):**

| Severidade | Achado | Tratamento |
|------------|--------|------------|
| CRÍTICO | `Access` reusava `CrmDeal.visible_to`, que torna negócio sem inbox visível a todo agente: qualquer agente leria RG/CPF/laudos de clientes que nunca atendeu | Corrigido: regra própria (conversa em inbox do agente, ou negócio do qual é dono, responsável ou do time). Spec de regressão `access_spec.rb` |
| ALTO | Upload sem limite de taxa; tamanho checado depois de o corpo chegar | Throttle `crm/documents#create` (200/h por usuário, `RATE_LIMIT_CRM_DOCUMENT_UPLOADS`) e recusa 413 por `Content-Length`. O revisor citou `client_max_body_size 0` do nginx herdado do Chatwoot, mas produção usa `chusterm-host.conf`, que já corta em 50m/100m |
| MÉDIO | Evento `document_downloaded` gravado na emissão do link, não no download | Renomeado para `document_download_link_issued` |
| MÉDIO | Mensagem de erro expunha o content type detectado | Mensagem genérica com os formatos aceitos |
| BAIXO | `window.open` sem `noreferrer` | `noopener,noreferrer` |

Sem achados em: IDOR entre contas/contatos, path traversal/header injection no nome, mass assignment, SQL injection na busca, XSS.

**Verificação no app local (2026-09-22):** imagem `core` reconstruída, migration aplicada, módulo ligado na conta 55 (fixture "Conta A QA"), negócio 70. Roteiro reproduzível: `qa/e2e/shot-documents-vault.mjs <saida> <amostras>`. Visto funcionando: gaveta criada na primeira visita com as 7 pastas e a pasta do processo `2026-0070 · Negocio QA 0001` com as 4 subpastas do modelo geral; envio de 3 arquivos com progresso; nome de triagem com hora local (`2026-09-22 16h44 — Envio da equipe — RG maria.pdf`); contagem da aba atualizada. Ajustes feitos a partir das capturas: coluna de pastas mais larga com quebra de linha nos nomes, nome de arquivo em até duas linhas, lista de envios com "Limpar lista" e sumiço automático dos concluídos.

### F2 — Captura automática

| Item | Status | Onde |
|------|--------|------|
| Listener no `message_created` (todos os canais, sem tocar serviço de canal) | feito | `app/listeners/crm_document_intake_listener.rb`, registrado em `AsyncDispatcher` |
| Job de ingestão na fila `low`, com nova tentativa se o arquivo ainda não chegou | feito | `app/jobs/crm/documents/ingest_attachment_job.rb` |
| Ingestão: recebido → Triagem; enviado pela equipe → `05 Enviados pelo Escritório` (desligável por `accounts.settings['crm_documents_capture_outgoing'] = false`) | feito | `Crm::Documents::AttachmentIngestor` |
| Idempotência por anexo (webhook duplicado) e por checksum | feito | índice único `source_attachment_id` + `Uploader` |
| Hora do nome = hora em que o cliente mandou | feito | `provenance[:received_at]` |
| Classificador determinístico (legenda antes do nome, sem acento) → só sugere | feito | `Crm::Documents::Classifier`; `meta.suggested_doc_type` |
| Imagem pequena sem legenda marcada como "provável figurinha" | feito | `meta.likely_irrelevant` (< 40 KB) |
| Tela: sugestão, legenda do cliente, "Ver na conversa", sugestão pré-marcada no modal | feito | `CRMDocumentList.vue`, `CRMDocumentEditModal.vue` |
| Backfill idempotente em lotes | feito | `Crm::Documents::Backfill`, `rake "crm:documents:backfill[ACCOUNT_ID,AAAA-MM-DD]"` |
| Caixa de Triagem do escritório (`crm/arquivos/triagem`) | feito | `pages/DocumentTriage.vue`, `CRMTriagePanel.vue`; API `GET crm/documents/triage`; item "Triagem de documentos" no menu CRM só com o módulo ligado |
| Triagem: agrupada por cliente, pré-visualização de imagem/PDF, sugestão marcada, atalhos (J/K, 1–9, Enter, Delete), destino e nome final antes de confirmar, processo quando o tipo é de processo | feito | idem |
| Aba do negócio: classificar leva o processo junto (CNIS/laudo vão para a subpasta do processo) | feito | `CRMDocumentVault.vue` |
| Atualização em tempo real (ActionCable) | pendente | hoje a aba atualiza ao abrir/recarregar |

**Decisões de implementação da F2:**

- **Cópia própria do arquivo, por hardlink.** O documento não reaproveita o blob do anexo da mensagem: se a conversa ou a mensagem for apagada, o Active Storage tentaria apagar um arquivo compartilhado. `Crm::Documents::BlobCloner` cria um blob independente; no serviço Disk (produção) é um hardlink — zero espaço extra, e apagar um não afeta o outro. Em volume sem hardlink ou em S3, copia os bytes. Motivo: medição de produção (copiar dobraria 4,5 GB + 1 GB/mês).
- **Limite da captura: 200 MB** (vídeo de iPhone); upload da equipe segue em 50 MB. **WebP sem legenda** marcado como provável figurinha.
- **Áudio não entra.** Nota de voz é conversa, não documento (§7.2). Imagem, vídeo e arquivo entram.
- **Origem pelo canal da inbox:** WhatsApp, e-mail, Instagram; demais canais (widget, API) como `chat` ("Conversa").
- **Nota privada não entra** (inclui anexos que a equipe põe só para uso interno).

**Verificação da captura no app local:** mensagem recebida com anexo e legenda "segue meu comprovante de residência" criada na conversa 1 do contato 80 (conta 55). O Sidekiq gerou o documento em `00 Triagem` com cópia própria do arquivo, nome `2026-09-22 17h08 — Conversa — conta-luz-setembro.pdf` e sugestão `comprovante_residencia`.

**Testes:** RSpec do módulo 131/0 (classificador, ingestão, listener, backfill, API, triagem); Vitest CRM + contatos + menu 204/0.

**Falha pré-existente, não relacionada:** `spec/listeners/crm_captain_triage_listener_spec.rb:19` falha também sem as mudanças do cofre (a criação de conta já provisiona funil com etapas, o que invalida a premissa do teste).

### Deploys (22/09/2026)

| Onde | Release | Estado | Verificação |
|------|---------|--------|-------------|
| Chuster (canário) | `20260922T204436-4346d0c-cofre-f1f2` | no ar, **módulo ligado** na conta 1 (Chuster Tech) | migration aplicada; `/health` OK; teste de fumaça no volume real: documento criado na pasta certa, clone por hardlink com mesmo inode, clone sobrevive ao original apagado, contato de teste removido |
| Chuster (canário) | `20260922T222513-50b5391-cofre-f3` | no ar (F3), módulo ligado na conta 1 | teste de fumaça: reenvio virou v2 com validade 2026-12-21; anterior obsoleto em `99 Arquivo` como "(v1)"; fila "Para análise" traz o v2; contato de teste removido |
| Chuster (canário) | `20260923T000744-0177aa3-cofre-universal` | no ar (universal + F4 + correções de segurança), módulo ligado na conta 1 | migration aplicada; `/health` OK; teste de fumaça por HTTPS como navegador (CSRF, Origin, cookie): formulário criado do modelo jurídico, página 200 com CSS/JS 200, CSP e `Referrer-Policy: same-origin` no ar, envio com PDF → protocolo `2026-000001`, contato novo, arquivo na Triagem como "2026-09-22 21h29 — Formulário — rg-smoke.pdf" com tipo sugerido e "não verificado"; formulário, envio, documento e contato de teste removidos |
| Chuster (canário) | `20260923T053528-5bf03e1-menu-arquivos` | "Arquivos" como item próprio do menu (antes escondido no grupo Negócios); flag `marketing` ligada na conta 1 a pedido do dono | menu conferido no navegador |
| KVM4 (cliente) | `20260923T062814-5bf03e1-cofre-universal` | no ar, **módulo LIGADO** na conta 1 (Coimbra e Ruas) com o modelo jurídico, a pedido do dono em 23/09 (D11 dispensada por ele); Marketing já estava ligado | `/health` 200, site 200; 19 tipos, 7 modelos de pasta, 0 documentos; menu "Arquivos" no bundle; nginx do CRM com 100 MB; disco foi de 72% para 77% com o backup pré-deploy |
| KVM4 (cliente) | `20260922T205644-4346d0c-cofre-f1f2-dark` | no ar, **módulo desligado** (dark launch) | migration aplicada; `/health` OK; site 200; `accounts.settings.crm_documents` ausente; 0 documentos |

A KVM4 ficou na F1/F2 de propósito: o módulo está desligado lá (a F3 não muda nada até ligar) e cada deploy soma ~6,8 GB de backup num disco em 72%. Levar a F3 junto com o próximo deploy necessário, de preferência depois da rotação de backup.

Ligar para o escritório: `Crm::Documents::Feature.enable!(Account.find(1))` na KVM4 (e, se quiser trazer o histórico, `rake "crm:documents:backfill[1]"`). Aguarda a validação da árvore de pastas pela cliente (D11). O backup pré-deploy levou o disco da KVM4 de 68% para 72%.

### Incidente encontrado na produção (fora do escopo do cofre)

**O WhatsApp da Dra. Paula está desconectado do CRM desde 08/09/2026 11h43.** Instância Evolution "Dra Paula Matos": `connectionStatus: connecting`, `disconnectionReasonCode: 401`, `conflict / device_removed` — o aparelho vinculado foi removido do WhatsApp (ou a sessão foi derrubada pelo WhatsApp). Última mensagem gravada no CRM: 16/09/2026. Nada entra desde então.

**Como resolver (precisa do celular dela):** no CRM, Configurações → Caixas de entrada → WhatsApp da Dra. Paula → reconectar e escanear o QR code pelo WhatsApp dela (Aparelhos conectados → Conectar um aparelho). Sem isso, nem o atendimento nem a captura do cofre recebem mensagens. Relacionado ao risco A2 (Baileys não oficial) de `DECISOES.md`.

### F3 — Checklist, status, validade e versões

| Item | Status | Onde |
|------|--------|------|
| "X de Y" do negócio a partir dos checklists existentes (itens `kind: document`) | feito | `Crm::Documents::Checklist`, `GET/PATCH crm/document_checklist?deal_id=` |
| Casamento item ↔ tipo: `doc_types` do item, apelidos (`rg_cpf` → RG/CPF/CNH, `contracheques` → holerite), slug igual à chave, classificador no título | feito | `Crm::Documents::ChecklistMatcher`, `checklist_aliases` em `defaults.yml` (chaves dos checklists reais da produção) |
| Documento de processo só conta para o próprio negócio; rejeitado não conta; aprovado aparece | feito | idem |
| Escolher checklist na aba (197 dos 208 negócios abertos da cliente não têm área nem tipo, então o casamento automático quase nunca acontece) e marcar "entregue em papel" | feito | `crm_deals.custom_fields['documents_checklist']`; `CRMDocumentChecklist.vue` |
| Validade automática pelo tipo (certidões 90 dias, CNIS 30), sem sobrescrever data manual | feito | `CrmDocument#assign_expiry` |
| Aprovar / Rejeitar com motivo (chips: Ilegível, Cortado, Vencido, Documento errado) | feito | `CRMDocumentList.vue`, `CRMDocumentEditModal.vue` |
| Versões: mesmo tipo na mesma pasta com conteúdo diferente vira v2; a anterior vai para 99 Arquivo, obsoleta, como "(v1)"; selo "vN" na lista | feito | `Crm::Documents::Versioner` (chamado no upload e ao classificar/mover); sem tabela nova, conforme §5.3 |
| Filas do escritório: "Para análise" (aprovar/rejeitar) e "Vencendo" (vencidos e 30 dias), em abas na página de documentos | feito | `GET crm/documents/queue?name=review|expiring` (`QueueQuery`), `CRMDocumentQueue.vue`, `DocumentTriage.vue` |
| Modelos de pasta editáveis por área (tela de configuração) | feito (23/09) | aba "Pastas" em Configurar documentos, `CRMFolderTemplatesSettings.vue`, `crm/document_folder_templates` |

**Testes:** RSpec do módulo 154/0 (+checklist, validade); Vitest do cofre 20/0.

### Universal: modelos por área e nomes configuráveis (22–23/09/2026)

O CRM atende várias áreas; o cofre deixou de ser jurídico por padrão.

| Item | Onde |
|------|------|
| Modelos de documentos por área: **geral** (padrão universal), legal, clinic, real_estate, education — tipos, pastas, apelidos de checklist, padrões de nome e formulário inicial | `config/crm_documents/presets/*.yml`, `Crm::Documents::Presets`, `Crm::Documents::Defaults` |
| Conta nova recebe o modelo do pack vertical instalado ou o geral; conta que já usava o catálogo jurídico é reconhecida (tipo `cnis`); troca de modelo acrescenta tipos e troca modelos de pasta sem mexer no que existe | `Defaults.initial_preset`, `Defaults.apply_preset!` |
| Configurações por conta (modelo, padrões de nome, captura) | tabela `crm_document_settings` |
| Padrões de nome com marcadores (`{data} — {tipo} — {descricao}`, `{nome} · C{codigo}`, `{ano}-{numero} · {titulo}`, triagem), validados por padrão, sem separador sobrando, encolhendo só a descrição | `Crm::Documents::Naming::Template`, `FileNamer`, `PathBuilder` |
| Tela "Configurar documentos" (administrador): Formulários, Área e nomes (prévia ao vivo), Tipos de documento, Pastas | `pages/DocumentSettings.vue`, `components/documents/settings/` |

Para ligar o módulo com um modelo: `Crm::Documents::Feature.enable!(account, preset: 'legal')` (ou `geral`, `clinic`, `real_estate`, `education`). Sem `preset`, vale o do pack ou o geral.

### F4 — Formulários de envio montados pela conta

O plano previa um formulário fixo (§8.7). Virou um **construtor**: cada conta monta os próprios formulários, com as perguntas e documentos que quiser.

| Item | Onde |
|------|------|
| Estrutura: campos (texto, texto longo, telefone, e-mail, CPF, CNPJ, CPF/CNPJ, data, número, lista, escolha única, várias escolhas, confirmação), ligação ao cadastro (nome/telefone/e-mail), obrigatório, ajuda, condição "mostrar quando"; documentos pedidos com tipo do cofre, vários arquivos e condição; textos da página | `CrmDocumentForm`, `Crm::Documents::FormSchema` |
| Página pública `/f/:token` (link fixo) e `/l/:token` (link do cliente); HTML no servidor, funciona sem JS; JS só condicionais, lista de arquivos, redução de fotos e anti-duplo-envio | `PublicDocumentFormsController`, `app/views/public_document_forms/`, `public/crm-forms/` |
| Envio: validação por tipo (CPF/CNPJ com dígito verificador), ciência LGPD, contato por telefone/e-mail sem alterar cadastro existente, protocolo `AAAA-NNNNNN`, arquivos na Triagem com tipo sugerido, "não verificado" até a equipe confirmar | `FormAnswers`, `ContactResolver`, `FormSubmitter` |
| Link personalizado ("Pedir documentos" no negócio/contato): não pede identificação, entra verificado, validade 1–60 dias, só o digest do token no banco | `CrmDocumentFormLink`, `POST crm/document_forms/:id/links`, `CRMRequestDocumentsModal.vue` |
| Fila "Novos envios": respostas rotuladas, identificação, "É este cliente", concluir, spam (arquiva os arquivos) | `GET/PATCH crm/document_submissions`, `CRMDocumentSubmissions.vue` |
| Defesas: CSRF, campo-isca e tempo mínimo (fingem sucesso), página expirada pede reenvio, rack-attack por IP (10 envios/h, `RATE_LIMIT_CRM_FORM_SUBMITS`), X-Frame-Options DENY, noindex, no-store, 404 genérico | idem |

**Revisão de segurança (23/09/2026)**: nenhum achado CRITICAL. Corrigidos:

| Nível | Achado | Correção |
|-------|--------|----------|
| HIGH | Envio aberto grava arquivos no contato real casado pelo telefone/e-mail — quem sabe o telefone de alguém podia inundar a Triagem dele | até 5 envios não verificados por contato em 24 h (`FormSubmitter::MAX_UNVERIFIED_PER_CONTACT`); link personalizado não entra na conta |
| HIGH | "Pedir documentos" e upload aceitavam `deal_id` de qualquer negócio sem inbox do contato (`CrmDeal.visible_to`) — documento podia cair no caso de outro agente (sigilo entre casos) | `Crm::Documents::Access#deals` (dono, responsável, time, inbox do agente) em `find_contact_deal!` |
| MEDIUM | Sem teto total por envio | 100 MB por envio (`MAX_TOTAL_BYTES`), igual ao nginx do canário |
| MEDIUM | "Concluir" liberado com envio não verificado | servidor recusa; na fila o botão só aparece depois de "É este cliente" (spam continua livre) |
| MEDIUM | Sem CSP na única página aberta sem login | CSP só da própria origem em `PublicDocumentFormsController` |
| LOW (aceito) | Verificador de tempo reutilizável dentro de 12 h; respostas (CPF) sem criptografia de coluna | mitigado pelo rack-attack; mesmo padrão de `contacts` — registrar se a cliente pedir |

**Achados do roteiro visual (`qa/e2e/shot-documents-forms.mjs`) que os testes não pegavam:**

- `Referrer-Policy: no-referrer` fazia o navegador mandar `Origin: null` e o CSRF recusava **todo** envio real (422). Trocado para `same-origin`; spec de request com CSRF ligado.
- O `core/Dockerfile` copia `public/` item a item e deixava `public/crm-forms` de fora: a página saía sem estilo, com o campo-isca visível e sem os condicionais. Incluído.
- Vírgula sem aspas no YAML cortava o rótulo "Tem alguma data marcada? (audiência, perícia, prazo)"; `presets_spec.rb` varre os presets atrás de chave sem valor.
- As abas de "Configurar documentos" sumiam (filho da coluna flex encolhendo a zero).

Observação: o nginx do canário acrescenta `X-Frame-Options: SAMEORIGIN` ao `DENY` da aplicação (cabeçalho duplicado); quem vale é o `frame-ancestors 'none'` da CSP, então a página continua sem poder ser embutida.

**Pendências conhecidas da F4:** confirmação do protocolo por WhatsApp para o número informado (§8.7.1) — exige escolher a inbox de envio por formulário; hoje o protocolo aparece só na tela. O nginx das duas VPS aceita 100 MB por requisição no host do CRM (conferido em 23/09), igual ao teto da aplicação.

### F5 e F6

Pendentes. F5 (backup no Google Drive) depende da D3 (conta Google). F6 (acabamento e métricas) depois do uso real. Ver `PROJETO-COFRE-DOCUMENTOS.md` §13.
