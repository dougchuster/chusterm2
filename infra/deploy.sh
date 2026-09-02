#!/usr/bin/env bash
# deploy.sh — Deploy ChusteRM na VPS
# Uso: CHUSTERM_VPS=usuario@host ./infra/deploy.sh
# Pré-requisito: SSH configurado para o host de deploy (dados no gerenciador
# de senhas — nunca hardcoded aqui, SEC-06). Preferir usuário de deploy sem root.

set -euo pipefail

VPS="${CHUSTERM_VPS:?Defina CHUSTERM_VPS=usuario@host (ver gerenciador de senhas)}"
APP_DIR="/opt/chusterm"
REPO="https://github.com/dougchuster/chuterm.git"
BRANCH="main"

echo "==> Conectando na VPS..."
ssh "$VPS" bash -s << REMOTE
  set -euo pipefail

  # Clonar ou atualizar repositório
  if [ ! -d "$APP_DIR" ]; then
    echo "==> Clonando repositório em $APP_DIR..."
    git clone --branch $BRANCH $REPO $APP_DIR
    cd $APP_DIR
  else
    echo "==> Atualizando repositório..."
    cd $APP_DIR
    git fetch origin
    git checkout $BRANCH
    git pull origin $BRANCH
  fi

  # Verificar .env
  if [ ! -f "$APP_DIR/.env" ]; then
    echo ""
    echo "ERRO: .env não encontrado em $APP_DIR/.env"
    echo "Copie .env.prod.example para .env e preencha os valores:"
    echo "  cp $APP_DIR/.env.prod.example $APP_DIR/.env"
    echo "  nano $APP_DIR/.env"
    exit 1
  fi

  # Build e subir containers
  echo "==> Build e deploy dos containers..."
  docker compose -f $APP_DIR/docker-compose.prod.yml pull --quiet
  docker compose -f $APP_DIR/docker-compose.prod.yml build --no-cache

  # BUG-10: migrations rodam num serviço one-shot antes do core subir
  echo "==> Rodando migrations (db:migrate)..."
  docker compose -f $APP_DIR/docker-compose.prod.yml run --rm migrate

  docker compose -f $APP_DIR/docker-compose.prod.yml up -d

  # Aguardar Core ficar saudável
  echo "==> Aguardando Core inicializar (pode demorar ~2 min)..."
  for i in \$(seq 1 24); do
    if docker compose -f $APP_DIR/docker-compose.prod.yml exec -T core wget -qO- http://127.0.0.1:3000/health >/dev/null 2>&1; then
      echo "    Core OK!"
      break
    fi
    echo "    Tentativa \$i/24..."
    sleep 10
  done

  # Status final
  echo ""
  echo "==> Status dos containers:"
  docker compose -f $APP_DIR/docker-compose.prod.yml ps

  echo ""
  echo "==> Deploy concluído!"
  echo "    Acesse: https://crm.coimbraeruas.com.br"
REMOTE
