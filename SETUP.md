# ChusteRM — setup e operação

Este guia descreve a stack Docker atual do ChusteRM. Execute os comandos a partir da raiz do repositório.

## Stack local verificada

| Serviço | Acesso pelo host | Uso |
|---|---|---|
| ChusteRM Core | http://localhost:8086 | CRM e atendimento Rails |
| Agent Orchestrator | http://localhost:4001 | Orquestração dos recursos de IA |
| Evolution API | http://localhost:8085 | Integração com WhatsApp |
| Mailhog | http://localhost:8025 | Caixa de e-mail local; SMTP em `localhost:1025` |
| PostgreSQL | `localhost:5436` | Banco persistente; porta interna `5432` |
| Redis | `localhost:6382` | Cache e filas; porta interna `6379` |

O `docker-compose.override.yml` altera o Core local para `8086:3000`. Use `docker compose config` para consultar a configuração efetiva, em vez de considerar apenas o mapeamento do arquivo base. Sidekiq faz parte da stack padrão. O `core-vite` é um watcher opcional, sem porta publicada, isolado no perfil `frontend-watch` porque uma recompilação completa pode usar bastante CPU e memória.

O CRM vive no Core Rails e nas tabelas `crm_*`. Os antigos `crm-service` e `identity-bridge` estão aposentados e não devem ser iniciados, incluídos em deploys ou usados por novas integrações. O Orchestrator permanece como o único serviço Node.js da arquitetura atual.

## Pré-requisitos e segredos

- Docker Desktop ou Docker Engine com Docker Compose v2.
- Git e PowerShell para o fluxo local documentado abaixo.
- Um arquivo `.env` criado a partir do modelo do ambiente.

```powershell
Copy-Item .env.example .env
```

Preencha o `.env` com valores próprios e fortes antes de subir a stack. Gere segredos aleatórios, armazene-os no gerenciador de senhas do time e nunca versione o `.env`. E-mails pessoais, usuários administrativos, tokens e senhas reais não pertencem a este documento; crie e gerencie as contas pela aplicação.

## Build, migrations e inicialização segura

Em uma instalação já existente, faça e valide um backup antes de atualizar imagens ou rodar migrations. Em uma instalação nova, comece pela validação da configuração.

```powershell
# 1. Backup da instalação existente (pula-se apenas no primeiro setup)
.\scripts\backup.ps1

# 2. Validar a composição e as variáveis obrigatórias
docker compose config --quiet

# 3. Construir os serviços que usam código do repositório
docker compose build --pull core sidekiq orchestrator

# 4. Subir primeiro as dependências persistentes
docker compose up -d postgres redis mailhog evolution-api
docker compose ps

# 5. Aplicar migrations em processos one-shot
docker compose run --rm core bundle exec rails db:migrate
docker compose run --rm orchestrator npm run db:migrate

# 6. Iniciar ou reconciliar toda a stack
docker compose up -d
docker compose ps
```

O comando normal do Orchestrator também executa sua migration antes do servidor, de forma idempotente. Em produção, use o serviço one-shot dedicado antes de iniciar a nova versão:

```bash
docker compose -f docker-compose.prod.yml config --quiet
docker compose -f docker-compose.prod.yml build --pull
docker compose -f docker-compose.prod.yml run --rm migrate
docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps
```

O `infra/deploy.sh` automatiza essa mesma ordem em produção: valida o `.env`, constrói as imagens, executa a migration, inicia os containers e aguarda o health check do Core.

## Health checks e diagnóstico

Após o start, `postgres`, `redis`, `core`, `sidekiq`, `orchestrator` e `evolution-api` devem aparecer como `healthy`; Mailhog deve aparecer como `Up`.

```powershell
docker compose ps

curl.exe --fail --silent --show-error http://localhost:8086/health
curl.exe --fail --silent --show-error http://localhost:4001/health
curl.exe --fail --silent --show-error http://localhost:8085/
curl.exe --fail --silent --show-error http://localhost:8025/
```

Para recompilar os assets automaticamente durante trabalho de frontend, inicie o watcher apenas enquanto ele for necessário:

```powershell
docker compose --profile frontend-watch up -d core-vite
docker compose stop core-vite
```

O comando do watcher é `vite build --watch`: cada conjunto de alterações pode disparar um build de produção completo. Para identificar um pico sem encerrar serviços, use `docker stats --no-stream`. O processo `vmmemWSL` agrega a memória da VM do Docker/WSL e pode reter cache mesmo quando a soma dos containers ativos já caiu; `wsl --shutdown` libera a VM, mas também interrompe todos os projetos Docker e, por isso, não faz parte do diagnóstico automático.

Se algum check falhar, consulte os logs sem reinicializar os volumes:

```powershell
docker compose logs --tail=200 core sidekiq orchestrator evolution-api postgres redis
docker compose ps
```

Para uma parada reversível, prefira `docker compose stop`; para retomar, use `docker compose start` ou `docker compose up -d` após mudanças de configuração.

> **Proteção de dados:** nunca execute `docker compose down -v`. Também não remova volumes nem use prune de volumes como procedimento de troubleshooting. Essas ações apagam PostgreSQL, Redis, arquivos do Core e dados da Evolution API.

## Backup e reprodutibilidade

O helper local `scripts/backup.ps1` grava artefatos em `backups/<data_hora>/`. Antes de migrations ou deploys, confirme que os dumps do PostgreSQL podem ser lidos e que os dados persistentes necessários — especialmente `core-storage` e os volumes da Evolution — estão cobertos por backup ou snapshot externo. Mantenha ao menos uma cópia fora do host Docker e documente o procedimento de restauração no ambiente operacional.

O `core/Dockerfile` fixa a imagem-base do Chatwoot por digest SHA-256. Isso torna o build reproduzível e evita uma troca implícita para `latest`. Não substitua o digest durante um deploy rotineiro; sua atualização exige auditoria explícita de compatibilidade, novo build, migrations controladas, health checks e um caminho de rollback baseado no backup anterior.
