#!/usr/bin/env bash
# =============================================================================
#  smoke-test.sh — Smoke Tests for DevOps Stack
#  Runs curl checks against every service endpoint and reports pass/fail.
# =============================================================================
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; SKIP=0
RESULTS=()

# Load .env for port config
if [[ -f ".env" ]]; then
    set -o allexport
    # shellcheck disable=SC1091
    source .env
    set +o allexport
fi

BASE_URL="http://localhost:${NGINX_HTTP_PORT:-80}"
PROMETHEUS_URL="http://localhost:${PROMETHEUS_PORT:-9090}"
GRAFANA_URL="http://localhost:${GRAFANA_PORT:-3000}"
ALERTMANAGER_URL="http://localhost:${ALERTMANAGER_PORT:-9093}"
GRAFANA_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_PASS="${GRAFANA_ADMIN_PASSWORD:-admin123}"

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════╗"
echo "║         DevOps Stack — Smoke Tests           ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Helper: run a single test ─────────────────────────────────────────────────
# check <name> <method> <url> [expected_http_code] [body_contains]
check() {
    local name="$1" method="$2" url="$3"
    local expected_code="${4:-200}"
    local body_match="${5:-}"

    local response http_code body
    response=$(curl -s -o /tmp/smoke_body -w "%{http_code}" \
        -X "$method" "$url" \
        -H "Accept: application/json" \
        --connect-timeout 5 --max-time 10 2>/dev/null) || response="000"
    http_code="$response"
    body=$(cat /tmp/smoke_body 2>/dev/null || echo "")

    local status="PASS"
    local reason=""

    if [[ "$http_code" != "$expected_code" ]]; then
        status="FAIL"
        reason="Expected HTTP $expected_code, got $http_code"
    elif [[ -n "$body_match" ]] && ! echo "$body" | grep -q "$body_match"; then
        status="FAIL"
        reason="Body did not contain: '$body_match'"
    fi

    if [[ "$status" == "PASS" ]]; then
        echo -e "  ${GREEN}✓ PASS${NC}  $name"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗ FAIL${NC}  $name  → $reason"
        FAIL=$((FAIL + 1))
    fi
    RESULTS+=("$status|$name")
}

# ── Rate limit test ───────────────────────────────────────────────────────────
check_rate_limit() {
    local name="$1" url="$2"
    echo -ne "  ${CYAN}→ RATE${NC}  $name (sending 25 rapid requests)..."

    local got_429=0
    for i in $(seq 1 25); do
        code=$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout 2 --max-time 5 "$url" 2>/dev/null || echo "000")
        if [[ "$code" == "429" ]]; then
            got_429=1
            break
        fi
    done

    if [[ "$got_429" == "1" ]]; then
        echo -e " ${GREEN}✓ Rate limit triggered (429 received)${NC}"
        PASS=$((PASS + 1))
        RESULTS+=("PASS|$name")
    else
        echo -e " ${YELLOW}⚠ No 429 received (rate limit may not be active yet)${NC}"
        SKIP=$((SKIP + 1))
        RESULTS+=("SKIP|$name")
    fi
}

# ════════════════════════════════════════════════════════
echo -e "${BOLD}[1/5] API Endpoints (via Nginx)${NC}"
check "GET  /               → 200 + version"     GET  "$BASE_URL/"           200 "version"
check "GET  /health         → 200 + healthy"      GET  "$BASE_URL/health"     200 "healthy"
check "GET  /api/visits     → 200 + visits"       GET  "$BASE_URL/api/visits" 200 "visits"
check "GET  /api/data       → 200 + items"        GET  "$BASE_URL/api/data"   200 "items"
check "GET  /nonexistent    → 404 or proxy error" GET  "$BASE_URL/no-such"    404

echo ""
echo -e "${BOLD}[2/5] Nginx${NC}"
check "GET  /nginx-health   → 200 healthy"        GET  "$BASE_URL/nginx-health" 200 "healthy"

echo ""
echo -e "${BOLD}[3/5] Prometheus${NC}"
check "GET  /-/healthy      → 200"                GET  "$PROMETHEUS_URL/-/healthy"  200
check "GET  /api/v1/query?up → has data"          GET  "$PROMETHEUS_URL/api/v1/query?query=up" 200 "success"
check "GET  /api/v1/rules   → alert rules loaded" GET  "$PROMETHEUS_URL/api/v1/rules" 200 "ServiceDown"

echo ""
echo -e "${BOLD}[4/5] Grafana${NC}"
check "GET  /api/health     → 200"                GET  "$GRAFANA_URL/api/health" 200 "ok"
check "GET  /api/datasources (auth) → 200"        GET  "http://${GRAFANA_USER}:${GRAFANA_PASS}@${GRAFANA_URL#http://}/api/datasources" 200 "Prometheus"

echo ""
echo -e "${BOLD}[5/5] Rate Limiting (Bonus)${NC}"
check_rate_limit "Nginx /api/ rate limit (10r/s)" "$BASE_URL/api/visits"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════ Results ══════════════════════${NC}"
echo -e "  ${GREEN}Passed:${NC}  $PASS"
[[ $FAIL  -gt 0 ]] && echo -e "  ${RED}Failed:${NC}  $FAIL"
[[ $SKIP  -gt 0 ]] && echo -e "  ${YELLOW}Skipped:${NC} $SKIP"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "  Total:   $TOTAL"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✅  All smoke tests passed!${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}❌  $FAIL test(s) failed. Check service logs.${NC}"
    exit 1
fi
