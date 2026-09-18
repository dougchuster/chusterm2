#!/usr/bin/env bash
# release-deploy.sh — deploy por release nas VPS (layout /opt/chusterm-releases).
#
# Roda NA VPS. Do lado local:
#   SHA=$(git rev-parse --short=7 HEAD); REL="$(date -u +%Y%m%dT%H%M%S)-$SHA-<slug>"
#   git archive --format=tar.gz --prefix=source/ -o /tmp/chusterm-$SHA-<slug>.tar.gz HEAD
#   scp /tmp/chusterm-$SHA-<slug>.tar.gz root@<vps>:/opt/chusterm-releases/
#   scp infra/release-deploy.sh root@<vps>:/root/ && ssh root@<vps> "nohup /root/release-deploy.sh $REL $SHA <slug> > /root/deploy-$REL.log 2>&1 &"
#
# O que faz: extrai o tar, copia o .env do release ativo (opcionalmente
# restaurando variáveis a partir de RESTORE_ENV_FROM), roda o backup pré-deploy,
# builda core/sidekiq, troca o symlink /opt/chusterm-current, roda as migrations
# e recria SÓ core e sidekiq. Nunca toca orchestrator/evolution/postgres/redis:
# o orchestrator guarda node_modules num volume anônimo e a evolution da KVM4
# tem drift manual no compose — recriar qualquer um deles quebra produção.
set -euo pipefail

REL="${1:?release id (ex.: 20260918T182822-c599954-checkup)}"
SHA="${2:?sha curto}"
SLUG="${3:-release}"
BASE="/opt/chusterm-releases/$REL"
CUR="/opt/chusterm-current"
TARBALL="/opt/chusterm-releases/chusterm-$SHA-$SLUG.tar.gz"
# Variáveis que já se perderam entre releases (17/09/2026): se faltarem no .env
# atual, são copiadas do arquivo em RESTORE_ENV_FROM (ex.: .env de um release antigo).
RESTORE_VARS="ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT SERVICE_AUTH_TOKEN ORCHESTRATOR_WEBHOOK_SECRET CORS_ORIGIN LOG_LEVEL EVOLUTION_EXPOSE_TOKEN_IN_FETCH"
compose() { docker compose -p chusterm --env-file .env -f docker-compose.prod.yml "$@"; }

echo "==> [1/6] extraindo $TARBALL em $BASE"
test -f "$TARBALL"
mkdir -p "$BASE" && tar -xzf "$TARBALL" -C "$BASE"
test -f "$BASE/source/docker-compose.prod.yml"

echo "==> [2/6] .env do release ativo"
cp "$CUR/.env" "$BASE/source/.env" && chmod 600 "$BASE/source/.env"
if [ -n "${RESTORE_ENV_FROM:-}" ]; then
  for k in $RESTORE_VARS; do
    grep -q "^$k=" "$BASE/source/.env" || { grep "^$k=" "$RESTORE_ENV_FROM" >> "$BASE/source/.env" && echo "    + $k restaurada de $RESTORE_ENV_FROM"; }
  done
fi
n="$(grep -c '^ACTIVE_RECORD_ENCRYPTION' "$BASE/source/.env" || true)"
[ "$n" = "3" ] || { echo "ERRO: .env sem as 3 chaves de Active Record Encryption (achei $n). Ver /opt/chusterm-backups/active-record-encryption-keys.txt"; exit 1; }

echo "==> [3/6] backup pré-deploy (.env, pg_dumpall, imagens rollback-$REL)"
/root/predeploy-backup.sh "$REL" "$CUR"

echo "==> [4/6] build core/sidekiq"
cd "$BASE/source"
compose build core sidekiq 2>&1 | tail -3

echo "==> [5/6] troca do release ativo + migrations"
ln -sfn "$BASE/source" "$CUR"
cd "$CUR"
# --no-deps é obrigatório: sem ele o `run` recria postgres/redis quando o hash
# de configuração muda (aconteceu na KVM4 em 18/09 — 30 s de banco fora).
compose run --rm --no-deps migrate 2>&1 | grep -E '^== |rror' || true

echo "==> [6/6] core + sidekiq"
compose up -d --no-deps core sidekiq
for _ in $(seq 1 30); do
  docker exec chusterm-core-1 wget -qO- http://127.0.0.1:3000/health >/dev/null 2>&1 && { echo "    core /health OK"; break; }
  sleep 10
done
docker ps --format '{{.Names}}\t{{.Status}}' | grep chusterm
echo "DEPLOY_DONE $REL"
