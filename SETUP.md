# ChusteRM — Guia de Setup Completo

## Sistema Atual — 100% Operacional

### Serviços Rodando (via Docker Compose)
| Serviço | URL | Status |
|---|---|---|
| **ChusteRM Core** (Chatwoot oficial) | http://localhost:3010 | ✅ Healthy |
| PostgreSQL | localhost:5436 | ✅ Healthy |
| Redis | localhost:6382 | ✅ Healthy |
| CRM Service (API) | localhost:4003 | ✅ Healthy |
| Agent Orchestrator | localhost:4001 | ✅ Healthy |
| Identity Bridge | localhost:4002 | ✅ Healthy |
| CRM UI | localhost:3001 | ✅ Healthy |
| Mailhog | localhost:8025 | ✅ Running |

### Credenciais de Acesso
| Campo | Valor |
|---|---|
| **URL** | http://localhost:3010 |
| **Email** | dougcruvinel@gmail.com |
| **Senha** | `Admin@123` |
| **Account** | Acme Inc |
| **Tipo** | SuperAdmin |

---

## Novo Design: Obsidian Kinetic

O novo design system **Obsidian Kinetic: Ultra Refined** foi criado e está pronto no código:

- **Arquivo CSS**: `core/app/javascript/dashboard/assets/css/obsidian-kinetic.css`
- **Integrado em**: `core/app/javascript/entrypoints/dashboard.js`
- **Design**: Dark mode com gradientes violeta/ciano, Cyber-Glass, Ghost Borders

### Para Ver o Novo Design

O código rebrandado está no `core/` mas o container usa a imagem oficial do Chatwoot. Para ver o novo design:

#### Opção 1 — Rodar Localmente (Recomendado)
```bash
# Requer Ruby 3.4.4 e Node.js
cd core
bundle install
pnpm install
bin/dev
# Acesse http://localhost:3000
```

#### Opção 2 — Build Docker Completo
```bash
# Demora ~20 minutos (compila Ruby from source)
cd core
docker build -t chusterm-core-custom .
# Atualizar docker-compose.yml para usar a imagem customizada
docker compose up -d core
```

---

## Funcionalidades Disponíveis

O ChusteRM tem **todas as funcionalidades do Chatwoot CE**:

### Canais de Atendimento
- ✅ Website (Live Chat / Widget)
- ✅ WhatsApp Business API
- ✅ Facebook Messenger
- ✅ Twitter/X
- ✅ Instagram Direct
- ✅ Email
- ✅ SMS
- ✅ Telegram
- ✅ Line
- ✅ API Customizada

### Gestão
- ✅ Agentes e Times
- ✅ Caixas de Entrada (Inboxes)
- ✅ Marcadores (Labels)
- ✅ Atributos Personalizados
- ✅ Automação
- ✅ Macros
- ✅ Atalhos
- ✅ Integrações
- ✅ Aplicações (Dashboard Apps)

### Relatórios e Analytics
- ✅ Relatórios de conversas
- ✅ Métricas de agentes
- ✅ Tempo de resposta
- ✅ Satisfação do cliente

---

## Como Rodar

```bash
# Iniciar todos os serviços
docker compose up -d

# Verificar status
docker compose ps

# Ver logs
docker compose logs -f core
```

---

## Arquivos Rebrandados no Core

- `core/app/javascript/dashboard/assets/css/obsidian-kinetic.css` — **NOVO** Design System completo
- `core/app/javascript/dashboard/assets/css/tokens.css` — Design tokens
- `core/app/javascript/entrypoints/dashboard.js` — Importa CSS do novo design
- `core/config/application.rb` — Enterprise condicional
- `core/config/initializers/01_inject_enterprise_edition_module.rb` — Early return
- `core/config/locales/pt_BR.yml` — Traduzido
- `core/package.json` — `@chusterm/chusterm`
- `core/app/javascript/**` — 386+ arquivos rebrandados