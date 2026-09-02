#!/usr/bin/env bash
# audit-enterprise.sh — Valida a integridade do overlay Enterprise do ChusteRM.
set -euo pipefail

TARGET="${1:-./core}"
REPORT_FILE="./docs/audit-enterprise-report.txt"

echo "============================================================"
echo " ChusteRM — Auditoria do Overlay Enterprise"
echo " Alvo: $TARGET"
echo " Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

TOTAL=0
{
  echo "ChusteRM — Enterprise Overlay Audit Report"
  echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Alvo: $TARGET"
  echo "============================================================"
} > "$REPORT_FILE"

echo "🔍 Verificando presença e rastreamento do overlay enterprise/..."
if [ ! -d "$TARGET/enterprise" ]; then
  echo "  ❌ Pasta '$TARGET/enterprise' não encontrada."
  TOTAL=$((TOTAL + 1))
else
  TRACKED_COUNT=$(git -C "$TARGET" ls-files 'enterprise/**' | grep -c . || true)
  if [ "$TRACKED_COUNT" -eq 0 ]; then
    echo "  ❌ O overlay existe, mas não possui arquivos rastreados."
    TOTAL=$((TOTAL + 1))
  else
    echo "  ✅ Overlay presente com $TRACKED_COUNT arquivo(s) rastreado(s)."
  fi
fi

echo ""
echo "🔍 Verificando arquivos incompatíveis com o overlay..."
UNSAFE_FILES=$(find "$TARGET/enterprise" \
  \( -type l -o -type f \( -name '.env*' -o -name '*.pem' -o -name '*.key' \
  -o -name '*.p12' -o -name '*.dump' -o -name '*.sql' -o -name '*.tar' \
  -o -name '*.tar.gz' -o -name '*.zip' \) \) -print 2>/dev/null || true)

if [ -n "$UNSAFE_FILES" ]; then
  COUNT=$(printf '%s\n' "$UNSAFE_FILES" | grep -c . || true)
  echo "  ❌ $COUNT arquivo(s) inseguro(s) encontrado(s)."
  printf '\n=== Arquivos inseguros ===\n%s\n' "$UNSAFE_FILES" >> "$REPORT_FILE"
  TOTAL=$((TOTAL + COUNT))
else
  echo "  ✅ Nenhum segredo, link ou arquivo binário indevido encontrado."
fi

if find "$TARGET/enterprise" -mindepth 2 -type d -name .git -print -quit | grep -q .; then
  echo "  ❌ Repositório Git embutido encontrado em enterprise/."
  TOTAL=$((TOTAL + 1))
else
  echo "  ✅ Nenhum repositório Git embutido."
fi

echo ""
echo "============================================================"
if [ "$TOTAL" -gt 0 ]; then
  echo " ❌ RESULTADO: $TOTAL problema(s) estrutural(is) no overlay."
  echo "    Relatório completo em: $REPORT_FILE"
  echo "============================================================"
  exit 1
fi

echo " ✅ RESULTADO: Overlay Enterprise íntegro."
echo "============================================================"
