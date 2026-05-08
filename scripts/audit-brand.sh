#!/usr/bin/env bash
# audit-brand.sh — Detecta referências proibidas ao Chatwoot no fork.
# Executar dentro do diretório raiz do repositório ou passar o caminho como argumento.
# Uso: bash scripts/audit-brand.sh [caminho_do_fork]
set -euo pipefail

TARGET="${1:-./core}"
REPORT_FILE="./docs/audit-brand-report.txt"

FORBIDDEN_PATTERNS=(
  "Chatwoot"
  "chatwoot"
  "CHATWOOT"
  "chatwoot\.com"
  "support@chatwoot"
  "Powered by Chatwoot"
  "chatwoot-logo"
  "chatwoot_logo"
)

# Extensões a verificar
EXTENSIONS=("*.rb" "*.erb" "*.html" "*.vue" "*.js" "*.ts" "*.json" "*.yml" "*.yaml" "*.md" "*.txt" "*.css" "*.scss")

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

  INCLUDE_ARGS=()
  for ext in "${EXTENSIONS[@]}"; do
    INCLUDE_ARGS+=("--include=$ext")
  done

  MATCHES=$(grep -rn "$pattern" "$TARGET" "${INCLUDE_ARGS[@]}" \
    --exclude-dir=".git" \
    --exclude-dir="node_modules" \
    --exclude-dir="vendor" \
    --exclude-dir="coverage" \
    --exclude-dir="dist" \
    --exclude-dir="build" \
    2>/dev/null || true)

  COUNT=$(echo "$MATCHES" | grep -c . || echo 0)

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
