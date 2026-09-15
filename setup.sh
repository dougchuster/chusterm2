#!/usr/bin/env bash
# setup.sh — Instalação e configuração completa do ChusteRM (modo dev sem Core)
set -e

echo "========================================="
echo "  ChusteRM — Setup Automático"
echo "========================================="
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
  echo "❌ Docker não encontrado. Instale Docker Desktop primeiro."
  exit 1
fi

if ! docker compose version &> /dev/null; then
  echo "❌ Docker Compose não encontrado."
  exit 1
fi

echo "✅ Docker OK"
echo ""

# 1. Install dependencies
echo "📦 Instalando dependências Node.js..."
for svc in orchestrator; do
  echo "  → $svc"
  (cd "services/$svc" && npm install --silent 2>&1 | tail -1)
done
echo "✅ Dependências instaladas"
echo ""

# 2. Setup .env
if [ ! -f .env ]; then
  echo "🔧 Criando .env a partir do .env.example..."
  cp .env.example .env
  echo "✅ .env criado — edite com seus valores reais"
else
  echo "✅ .env já existe"
fi
echo ""

# 3. Start infrastructure
echo "🚀 Subindo infraestrutura (PostgreSQL, Redis, Mailhog)..."
docker compose -f docker-compose.dev.yml up -d postgres redis mailhog
echo "⏳ Aguardando PostgreSQL e Redis ficarem healthy..."
sleep 15
echo "✅ Infraestrutura pronta"
echo ""

# 4. Run migrations
echo "🗃️  Rodando migrations..."
echo "  → Orchestrator"
cd services/orchestrator && ORCHESTRATOR_DB_URL="postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_ai" npx tsx src/db/migrate.ts 2>&1 | grep -E "✅|❌|Running"
cd ../..
echo "✅ Migrations concluídas"
echo ""

# 5. Seed data
echo "🌱 Populando dados de exemplo (orchestrator knowledge)..."
npx tsx scripts/seed.ts 2>&1 | grep -E "✅|❌|🌱|🎉"
echo ""

# 6. Start all services
echo "🚀 Subindo todos os serviços..."
docker compose -f docker-compose.dev.yml up -d
echo "⏳ Aguardando serviços inicializarem..."
sleep 10
echo ""

# 7. Verify
echo "========================================="
echo "  Verificação Final"
echo "========================================="

check_health() {
  local url=$1
  local name=$2
  local status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [ "$status" = "200" ]; then
    echo "  ✅ $name ($status)"
  else
    echo "  ❌ $name ($status)"
  fi
}

check_health "http://localhost:4001/health" "Orchestrator"
check_health "http://localhost:3001/" "CRM UI"
check_health "http://localhost:8025/" "Mailhog"

echo ""
echo "========================================="
echo "  URLs Locais"
echo "========================================="
echo "  CRM UI:          http://localhost:3001"
echo "  Orchestrator:    http://localhost:4001"
echo "  Mailhog:         http://localhost:8025"
echo "  PostgreSQL:      localhost:5436"
echo "  Redis:           localhost:6382"
echo ""
echo "========================================="
echo "  Comandos Úteis"
echo "========================================="
echo "  Ver logs:        docker compose -f docker-compose.dev.yml logs -f"
echo "  Parar:           docker compose -f docker-compose.dev.yml down"
echo "  Reset completo:  docker compose -f docker-compose.dev.yml down -v && bash setup.sh"
echo "========================================="
