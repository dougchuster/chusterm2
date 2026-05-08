#!/usr/bin/env sh
# Reseta uma instância Evolution (Baileys): logout na API + opção de recriar.
# Uso:
#   EVOLUTION_INSTANCE=minha_instancia ./scripts/evolution-reset-instance.sh
#   EVOLUTION_API_URL=http://localhost:8085 EVOLUTION_API_KEY=seu_key ...
#
# Após logout, abra o ChusteRM em Configurações > Inbox > Evolution e escaneie o novo QR,
# ou chame POST /instance/connect/:name na Evolution.

set -eu

EVOLUTION_API_URL="${EVOLUTION_API_URL:-http://localhost:8085}"
EVOLUTION_API_KEY="${EVOLUTION_API_KEY:-evo_chusterm_secret_key}"
EVOLUTION_INSTANCE="${EVOLUTION_INSTANCE:?defina EVOLUTION_INSTANCE}"

BASE="${EVOLUTION_API_URL%/}"

echo "==> Logout instance: ${EVOLUTION_INSTANCE}"
curl -fsS -X DELETE \
  -H "apikey: ${EVOLUTION_API_KEY}" \
  "${BASE}/instance/logout/${EVOLUTION_INSTANCE}" || true

echo ""
echo "==> Opcional: apagar instância completamente (descomente no script se necessário)"
echo "    curl -X DELETE -H apikey:... ${BASE}/instance/delete/${EVOLUTION_INSTANCE}"
echo ""
echo "==> Reconectar (solicita novo QR na Evolution)"
curl -fsS -X GET \
  -H "apikey: ${EVOLUTION_API_KEY}" \
  "${BASE}/instance/connect/${EVOLUTION_INSTANCE}" | head -c 500 || true

echo ""
echo "Pronto. Reconfigure o webhook com: ./scripts/setup-evolution-webhooks.sh"
