#!/usr/bin/env bash
# =============================================================================
#  load-test.sh — 30-second load test (k6 preferred, Apache Bench fallback)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Load .env for port config
if [[ -f ".env" ]]; then
    set -o allexport
    # shellcheck disable=SC1091
    source .env
    set +o allexport
fi

BASE_URL="http://localhost:${NGINX_HTTP_PORT:-80}"
DURATION=30   # seconds

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════╗"
echo "║       DevOps Stack — Load Test (30s)         ║"
echo "╚══════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Target:   $BASE_URL/api/visits"
echo "  Duration: ${DURATION}s"
echo ""

# ── k6 (preferred) ────────────────────────────────────────────────────────────
if command -v k6 &>/dev/null; then
    echo -e "${CYAN}[INFO]${NC} Using k6 for load test..."
    echo ""

    # Write k6 script inline
    K6_SCRIPT=$(mktemp /tmp/k6_script_XXXXXX.js)
    cat > "$K6_SCRIPT" << 'EOFK6'
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate  = new Rate('error_rate');
const respTime   = new Trend('resp_time_ms', true);

export const options = {
  stages: [
    { duration: '5s',  target: 20 },   // ramp-up
    { duration: '20s', target: 50 },   // sustained load
    { duration: '5s',  target: 0  },   // ramp-down
  ],
  thresholds: {
    http_req_failed:   ['rate<0.05'],         // < 5% errors
    http_req_duration: ['p(95)<500'],         // 95th pct < 500ms
    error_rate:        ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:80';

export default function () {
  // Mix of endpoints
  const endpoints = [
    `${BASE_URL}/api/visits`,
    `${BASE_URL}/api/data`,
    `${BASE_URL}/health`,
    `${BASE_URL}/`,
  ];

  const url = endpoints[Math.floor(Math.random() * endpoints.length)];
  const res = http.get(url, { timeout: '10s' });

  const ok = check(res, {
    'status is 200 or 429': (r) => r.status === 200 || r.status === 429,
    'response time < 1s':   (r) => r.timings.duration < 1000,
  });

  errorRate.add(!ok);
  respTime.add(res.timings.duration);

  sleep(0.1);
}
EOFK6

    BASE_URL="$BASE_URL" k6 run "$K6_SCRIPT"
    K6_EXIT=$?
    rm -f "$K6_SCRIPT"

    echo ""
    if [[ $K6_EXIT -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✅  Load test passed all thresholds!${NC}"
    else
        echo -e "${RED}${BOLD}❌  Load test FAILED one or more thresholds.${NC}"
        echo "   Check error rates and response times above."
    fi
    exit $K6_EXIT

# ── Apache Bench (fallback) ───────────────────────────────────────────────────
elif command -v ab &>/dev/null; then
    echo -e "${CYAN}[INFO]${NC} k6 not found — using Apache Bench (ab) as fallback."
    echo -e "${YELLOW}[WARN]${NC} Install k6 for richer metrics: https://k6.io/docs/get-started/installation/"
    echo ""

    AB_OUTPUT=$(mktemp /tmp/ab_output_XXXXXX.txt)

    # Run ab: 50 concurrent, 30 seconds
    ab -t $DURATION -c 50 -q \
        -H "Accept: application/json" \
        "$BASE_URL/api/visits" > "$AB_OUTPUT" 2>&1 || true

    cat "$AB_OUTPUT"

    # Parse key metrics
    TOTAL_REQS=$(grep "^Complete requests:" "$AB_OUTPUT" | awk '{print $3}')
    FAILED_REQS=$(grep "^Failed requests:" "$AB_OUTPUT" | awk '{print $3}')
    RPS=$(grep "^Requests per second:" "$AB_OUTPUT" | awk '{print $4}')
    P50=$(grep "  50%" "$AB_OUTPUT" | awk '{print $2}')
    P95=$(grep "  95%" "$AB_OUTPUT" | awk '{print $2}')
    P99=$(grep "  99%" "$AB_OUTPUT" | awk '{print $2}')

    echo ""
    echo -e "${BOLD}══════════════ Load Test Summary ══════════════${NC}"
    echo -e "  Total Requests:  ${TOTAL_REQS:-N/A}"
    echo -e "  Failed Requests: ${FAILED_REQS:-N/A}"
    echo -e "  Requests/sec:    ${RPS:-N/A}"
    echo -e "  Latency p50:     ${P50:-N/A}ms"
    echo -e "  Latency p95:     ${P95:-N/A}ms"
    echo -e "  Latency p99:     ${P99:-N/A}ms"

    rm -f "$AB_OUTPUT"

    # Simple pass/fail: fail if more than 5% requests failed
    if [[ -n "${FAILED_REQS}" ]] && [[ "$FAILED_REQS" -le $(( (TOTAL_REQS * 5) / 100 )) ]]; then
        echo ""
        echo -e "${GREEN}${BOLD}✅  Load test passed (<5% failures)!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}${BOLD}❌  Load test FAILED (>5% failures or could not parse results).${NC}"
        exit 1
    fi

else
    echo -e "${RED}[ERROR]${NC} Neither k6 nor ab (Apache Bench) found."
    echo ""
    echo "Install one of:"
    echo "  k6:           https://k6.io/docs/get-started/installation/"
    echo "  Apache Bench: sudo apt-get install apache2-utils   (Ubuntu/Debian)"
    echo "                sudo yum install httpd-tools          (RHEL/CentOS)"
    exit 1
fi
