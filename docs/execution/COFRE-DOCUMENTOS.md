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
| Volume atual de anexos por conta nas VPS | **pendente** | Exige acesso de leitura à produção; rodar a query abaixo nas duas VPS |
| Espaço livre do volume `core-storage` e suporte a hardlink | **pendente** | `df -h` e teste de `ln` dentro do volume, nas duas VPS |

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
| API (pastas, documentos, tipos, download auditado) | em andamento | — |
| Frontend (aba Arquivos no negócio e no contato) | pendente | — |
| Download da pasta em `.zip` | pendente | depende de decidir a gem `rubyzip` |

**Escolhas de implementação registradas aqui (não mudam a especificação):**

- Pasta do processo: `AAAA-NNNN · <título do negócio>`, com ano de criação e id do negócio. O CRM não tem número sequencial por ano; o id é estável e único.
- "Arquivar" = `archived_at` (some das listas, restaurável). "Descartar" na triagem = mover para `99 Arquivo` (continua visível). São ações diferentes de propósito.
- Contato apagado: documentos saem pelo model (`Contact has_many :crm_documents, dependent: :destroy`, que apaga o arquivo); pastas caem por cascade no banco.
- Violação de índice único durante o provisionamento roda em savepoint (`requires_new`), para não abortar a transação de quem chamou.

**Testes:** 65 exemplos, 0 falhas (nomenclatura, models, provisionamento, roteamento, upload, acesso).

### F2 a F6

Pendentes. Ver `PROJETO-COFRE-DOCUMENTOS.md` §13.
