#!/usr/bin/env bash
# audit-enterprise.sh — Detecta referências à pasta enterprise/ ou recursos
# proprietários do Chatwoot que não devem ser usados no fork ChusteRM.
set -euo pipefail

TARGET="${1:-./core}"
REPORT_FILE="./docs/audit-enterprise-report.txt"

echo "============================================================"
echo " ChusteRM — Auditoria de Referências Enterprise"
echo " Alvo: $TARGET"
echo " Data: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo ""

TOTAL=0
{
  echo "ChusteRM — Enterprise Audit Report"
  echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Alvo: $TARGET"
  echo "============================================================"
} > "$REPORT_FILE"

# ── 1. Verificar se a pasta enterprise/ existe no fork ─────────────────────────
echo "🔍 Verificando presença da pasta enterprise/..."
if [ -d "$TARGET/enterprise" ]; then
  echo "  ⚠️  ATENÇÃO: pasta '$TARGET/enterprise' existe no fork."
  echo "     Revisar quais arquivos foram incluídos."
  echo "" >> "$REPORT_FILE"
  echo "=== Conteúdo de enterprise/ ===" >> "$REPORT_FILE"
  find "$TARGET/enterprise" -type f | head -100 >> "$REPORT_FILE"
  TOTAL=$((TOTAL + 1))
else
  echo "  ✅ Pasta enterprise/ não encontrada."
fi

echo ""

# ── 2. Verificar imports/require apontando para enterprise ─────────────────────
ENTERPRISE_IMPORT_PATTERNS=(
  "require.*enterprise"
  "from.*enterprise"
  "include.*Enterprise"
  "prepend.*Enterprise"
  "Enterprise::"
)

echo "🔍 Verificando referências a módulos Enterprise no código..."

for pattern in "${ENTERPRISE_IMPORT_PATTERNS[@]}"; do
  MATCHES=$(grep -rn "$pattern" "$TARGET" \
    --include="*.rb" --include="*.js" --include="*.ts" --include="*.vue" \
    --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="vendor" \
    --exclude-dir="enterprise" \
    2>/dev/null || true)

  COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
  if [ "$COUNT" -gt 0 ] && [ -n "$MATCHES" ]; then
    echo "  ⚠️  '$pattern': $COUNT ocorrência(s)"
    echo "" >> "$REPORT_FILE"
    echo "=== Enterprise import: $pattern ===" >> "$REPORT_FILE"
    echo "$MATCHES" >> "$REPORT_FILE"
    TOTAL=$((TOTAL + COUNT))
  fi
done

echo ""

# ── 3. Verificar feature flags de billing/upgrade na UI ────────────────────────
BILLING_PATTERNS=(
  "billing"
  "upgrade"
  "plan_name"
  "trial_"
  "subscription"
  "chatwoot_cloud"
)

echo "🔍 Verificando feature flags de billing/upgrade na UI..."

for pattern in "${BILLING_PATTERNS[@]}"; do
  MATCHES=$(grep -rni "$pattern" "$TARGET/app/javascript" \
    --include="*.vue" --include="*.js" --include="*.ts" \
    --exclude-dir=".git" --exclude-dir="node_modules" \
    2>/dev/null || true)

  COUNT=$(echo "$MATCHES" | grep -c . || echo 0)
  if [ "$COUNT" -gt 0 ] && [ -n "$MATCHES" ]; then
    echo "  ⚠️  '$pattern' (UI): $COUNT ocorrência(s)"
    echo "" >> "$REPORT_FILE"
    echo "=== Billing/upgrade flag: $pattern ===" >> "$REPORT_FILE"
    echo "$MATCHES" >> "$REPORT_FILE"
    TOTAL=$((TOTAL + COUNT))
  fi
done

echo ""
echo "============================================================"
if [ "$TOTAL" -gt 0 ]; then
  echo " ❌ RESULTADO: $TOTAL item(ns) enterprise/billing encontrado(s)."
  echo "    Relatório completo em: $REPORT_FILE"
  echo "============================================================"
  exit 1
else
  echo " ✅ RESULTADO: Nenhuma referência enterprise/billing encontrada."
  echo "============================================================"
  exit 0
fi
