#!/usr/bin/env bash
# audit-brand.sh — Detecta referências legadas visíveis ao usuário.
# Identificadores técnicos do fork upstream (constantes, eventos e pacotes) são
# compatibilidade interna e não constituem falha de marca.
# Uso: bash scripts/audit-brand.sh [caminho_do_fork]
set -euo pipefail

TARGET="${1:-./core}"
REPORT_FILE="./docs/audit-brand-report.txt"

FORBIDDEN_PATTERNS=(
  "Powered by Chatwoot"
  "support@chatwoot"
  "hello@chatwoot\.com"
  "Chatwoot account"
  "Chatwoot instance"
  "Chatwoot Installation"
  "Chatwoot System"
  "Chatwoot Team"
  "URL pública do Chatwoot"
  "para o Chatwoot"
  "próprio Chatwoot"
)

SCAN_PATHS=(app enterprise/app config/locales)

echo "============================================================"
echo " ChusteRM — Auditoria de Referências de Marca"
echo " Alvo: $TARGET"
echo " Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

TOTAL=0
{
  echo "ChusteRM — Brand Audit Report"
  echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Alvo: $TARGET"
  echo "============================================================"
} > "$REPORT_FILE"

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
  echo "🔍 Buscando: '$pattern'"

  # Limita a busca a fontes rastreadas e evita varrer builds Vite, logs,
  # caches e node_modules locais.
  MATCHES=$(git -C "$TARGET" grep -n -I -i -E "$pattern" -- "${SCAN_PATHS[@]}" 2>/dev/null || true)

  COUNT=$(printf '%s\n' "$MATCHES" | awk 'NF { count++ } END { print count + 0 }')

  if [ "$COUNT" -gt 0 ] && [ -n "$MATCHES" ]; then
    echo "  ⚠️  $COUNT ocorrência(s) encontrada(s)"
    echo ""
    echo "=== Padrão: $pattern ($COUNT ocorrências) ===" >> "$REPORT_FILE"
    echo "$MATCHES" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    TOTAL=$((TOTAL + COUNT))
  else
    echo "  ✅ Nenhuma ocorrência"
  fi
done

echo ""
echo "============================================================"
if [ "$TOTAL" -gt 0 ]; then
  echo " ❌ RESULTADO: $TOTAL referência(s) proibida(s) encontrada(s)."
  echo "    Relatório completo em: $REPORT_FILE"
  echo "============================================================"
  exit 1
else
  echo " ✅ RESULTADO: Nenhuma referência proibida encontrada."
  echo "============================================================"
  exit 0
fi
