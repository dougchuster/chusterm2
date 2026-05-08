#!/usr/bin/env bash
# Cria múltiplos bancos de dados no PostgreSQL durante a inicialização do container.
# Chamado pelo entrypoint do postgres:15-alpine.
set -e

function create_database() {
  local database=$1
  echo "  Criando database '$database'..."
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE $database;
    GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
  echo "Criando databases adicionais: $POSTGRES_MULTIPLE_DATABASES"
  for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
    create_database $db
  done
  echo "Databases criados com sucesso."
fi

# Criar database da Evolution API (WhatsApp não-oficial)
echo "Criando database 'evolution_api' para Evolution API..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  SELECT 'CREATE DATABASE evolution_api'
  WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'evolution_api')\gexec
  GRANT ALL PRIVILEGES ON DATABASE evolution_api TO $POSTGRES_USER;
EOSQL
echo "Database evolution_api pronto."
