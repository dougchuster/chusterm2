#!/usr/bin/env sh
set -eu

EVOLUTION_API_URL="${EVOLUTION_API_URL:-http://localhost:8085}"
EVOLUTION_API_KEY="${EVOLUTION_API_KEY:-evo_chusterm_secret_key}"
EVOLUTION_INSTANCE="${EVOLUTION_INSTANCE:?EVOLUTION_INSTANCE is required}"
EVOLUTION_WEBHOOK_URL="${EVOLUTION_WEBHOOK_URL:?EVOLUTION_WEBHOOK_URL is required}"

curl -fsS \
  -X POST \
  -H "apikey: ${EVOLUTION_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"webhook\": {
      \"enabled\": true,
      \"url\": \"${EVOLUTION_WEBHOOK_URL}\",
      \"headers\": {
        \"apikey\": \"${EVOLUTION_API_KEY}\"
      },
      \"webhookByEvents\": false,
      \"events\": [
        \"MESSAGES_UPSERT\",
        \"MESSAGES_UPDATE\",
        \"CONNECTION_UPDATE\",
        \"QRCODE_UPDATED\",
        \"LOGOUT_INSTANCE\",
        \"REMOVE_INSTANCE\"
      ]
    }
  }" \
  "${EVOLUTION_API_URL%/}/webhook/set/${EVOLUTION_INSTANCE}"

printf '\nEvolution webhook configured for instance %s -> %s\n' "$EVOLUTION_INSTANCE" "$EVOLUTION_WEBHOOK_URL"
