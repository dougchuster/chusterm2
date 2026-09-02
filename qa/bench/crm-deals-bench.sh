#!/usr/bin/env bash
# Baseline de latencia do GET /crm/deals (F0.3 do PLANO-KANBAN-CRM-2026.md).
#
# Mede p50/p95/max de tres cenarios contra uma instancia local. NUNCA aponte
# para producao: o script so dispara GETs, mas o baseline precisa de um ambiente
# controlado para ter significado.
#
# Uso:
#   CRM_BENCH_TOKEN=... CRM_BENCH_ACCOUNT=115 CRM_BENCH_PIPELINE=37 \
#     bash qa/bench/crm-deals-bench.sh
#
# Variaveis:
#   CRM_BENCH_TOKEN     api_access_token de um usuario da conta (obrigatorio)
#   CRM_BENCH_ACCOUNT   id da conta (obrigatorio)
#   CRM_BENCH_PIPELINE  id do pipeline (obrigatorio)
#   CRM_BENCH_BASE      base URL (padrao http://127.0.0.1:8086)
#   CRM_BENCH_REPS      repeticoes por cenario (padrao 40)
#   CRM_BENCH_BOARD_REPS repeticoes da carga completa do board (padrao 10)
#   CRM_BENCH_STAGE     id da etapa usada no cenario de 10 filtros (opcional)
#   CRM_BENCH_OWNER     id do dono usado no cenario de 10 filtros (opcional)
#   CRM_BENCH_INBOX     id da inbox usada no cenario de 10 filtros (opcional)

set -euo pipefail

TOKEN="${CRM_BENCH_TOKEN:?defina CRM_BENCH_TOKEN}"
ACCOUNT="${CRM_BENCH_ACCOUNT:?defina CRM_BENCH_ACCOUNT}"
PIPELINE="${CRM_BENCH_PIPELINE:?defina CRM_BENCH_PIPELINE}"
BASE="${CRM_BENCH_BASE:-http://127.0.0.1:8086}"
REPS="${CRM_BENCH_REPS:-40}"
WARMUP=5
BOARD_REPS="${CRM_BENCH_BOARD_REPS:-10}"

API="${BASE}/api/v1/accounts/${ACCOUNT}/crm/deals"

# Cenario 3: dez filtros simultaneos, o alvo da meta "p95 < 300ms".
ten_filters() {
  local q="pipeline_id=${PIPELINE}&status=open&operational_status=active&source=qa_fixture"
  q="${q}&score_min=10&score_max=95&search=Negocio&per_page=50&page=1"
  [ -n "${CRM_BENCH_STAGE:-}" ] && q="${q}&stage_id=${CRM_BENCH_STAGE}"
  [ -n "${CRM_BENCH_OWNER:-}" ] && q="${q}&owner_id=${CRM_BENCH_OWNER}"
  [ -n "${CRM_BENCH_INBOX:-}" ] && q="${q}&inbox_id=${CRM_BENCH_INBOX}"
  printf '%s' "$q"
}

# Mede um cenario e imprime uma linha de tabela markdown.
measure() {
  local label="$1" query="$2" samples i ms status

  for ((i = 0; i < WARMUP; i++)); do
    curl -s -o /dev/null -H "api_access_token: ${TOKEN}" "${API}?${query}" || true
  done

  status=$(curl -s -o /dev/null -w '%{http_code}' -H "api_access_token: ${TOKEN}" "${API}?${query}")
  if [ "$status" != "200" ]; then
    printf '| %s | ERRO HTTP %s | - | - | - |\n' "$label" "$status"
    return
  fi

  samples=$(
    for ((i = 0; i < REPS; i++)); do
      curl -s -o /dev/null -w '%{time_total}\n' \
        -H "api_access_token: ${TOKEN}" "${API}?${query}"
    done | sort -n
  )

  printf '%s\n' "$samples" | awk -v label="$label" -v reps="$REPS" '
    # Nearest-rank: o p-esimo percentil e o valor de indice ceil(N * p),
    # com piso em 1. Amostras ja chegam ordenadas.
    function rank(n, p,   idx) {
      idx = int(n * p)
      if (n * p > idx) idx++
      if (idx < 1) idx = 1
      if (idx > n) idx = n
      return idx
    }
    { v[NR] = $1 * 1000 }
    END {
      printf "| %s | %.0f ms | %.0f ms | %.0f ms | %d |\n", \
        label, v[rank(NR, 0.50)], v[rank(NR, 0.95)], v[NR], reps
    }'
}

# O board de hoje nao faz UMA requisicao: `fetchAllCrmDeals` (K-01) pagina
# sequencialmente com per_page=200 ate cobrir o total. O custo real de abrir o
# quadro e a soma dessas paginas, nao a latencia de uma delas.
measure_board_load() {
  local total="$1" pages samples i
  pages=$(((total + 199) / 200))
  [ "$pages" -lt 1 ] && pages=1

  samples=$(
    for ((i = 0; i < BOARD_REPS; i++)); do
      local start end page
      start=$(date +%s%N)
      for ((page = 1; page <= pages; page++)); do
        curl -s -o /dev/null -H "api_access_token: ${TOKEN}" \
          "${API}?pipeline_id=${PIPELINE}&per_page=200&page=${page}"
      done
      end=$(date +%s%N)
      echo $(((end - start) / 1000000))
    done | sort -n
  )

  # Poucas repeticoes: reportar p95 aqui seria so repetir o max e induzir a erro.
  printf '%s\n' "$samples" | awk -v pages="$pages" -v reps="$BOARD_REPS" '
    function rank(n, p,   idx) {
      idx = int(n * p)
      if (n * p > idx) idx++
      if (idx < 1) idx = 1
      if (idx > n) idx = n
      return idx
    }
    { v[NR] = $1 }
    END {
      printf "| carga completa do board (%d req sequenciais) | %d ms | — | %d ms | %d |\n", \
        pages, v[rank(NR, 0.50)], v[NR], reps
    }'
}

deal_total=$(curl -s -H "api_access_token: ${TOKEN}" "${API}?pipeline_id=${PIPELINE}&per_page=1" |
  sed -n 's/.*"total":\([0-9]*\).*/\1/p')

echo "## GET /crm/deals — ${deal_total} negocios no pipeline ${PIPELINE}"
echo
echo "| Cenario | p50 | p95 | max | amostras |"
echo "| :--- | ---: | ---: | ---: | ---: |"
measure "sem filtro, per_page=50"        "pipeline_id=${PIPELINE}&per_page=50&page=1"
measure "board atual, per_page=200"      "pipeline_id=${PIPELINE}&per_page=200&page=1"
measure "10 filtros simultaneos"         "$(ten_filters)"
measure_board_load "${deal_total:-0}"
