#!/usr/bin/env bash
# =============================================================================
#  setup.sh — DevOps Stack Bootstrap Script
#  Validates dependencies, creates .env, starts services, waits for health.
# =============================================================================
set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     DevOps Stack — Full-Stack Automation Setup       ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. Validate Docker & Docker Compose ──────────────────────────────────────
log "Checking dependencies..."

REQUIRED_DOCKER_MAJOR=20
REQUIRED_COMPOSE_MAJOR=2

# Docker
if ! command -v docker &>/dev/null; then
    die "Docker is not installed. Install from https://docs.docker.com/get-docker/"
fi

DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0.0.0")
DOCKER_MAJOR=$(echo "$DOCKER_VERSION" | cut -d. -f1)

if [[ "$DOCKER_MAJOR" -lt "$REQUIRED_DOCKER_MAJOR" ]]; then
    die "Docker version $DOCKER_VERSION is too old. Required: >= $REQUIRED_DOCKER_MAJOR.x"
fi
success "Docker version: $DOCKER_VERSION ✓"

# Docker Compose (v2 plugin style)
if docker compose version &>/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "2.0.0")
    COMPOSE_MAJOR=$(echo "$COMPOSE_VERSION" | cut -d. -f1)
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_VERSION=$(docker-compose version --short 2>/dev/null || echo "1.0.0")
    COMPOSE_MAJOR=$(echo "$COMPOSE_VERSION" | cut -d. -f1)
    COMPOSE_CMD="docker-compose"
    if [[ "$COMPOSE_MAJOR" -lt "$REQUIRED_COMPOSE_MAJOR" ]]; then
        die "docker-compose v1 detected ($COMPOSE_VERSION). Please upgrade to Docker Compose v2."
    fi
else
    die "Docker Compose is not installed. Install from https://docs.docker.com/compose/install/"
fi
success "Docker Compose version: $COMPOSE_VERSION ✓"

# curl (needed for health check probes)
if ! command -v curl &>/dev/null; then
    die "curl is not installed. Please install curl."
fi
success "curl found ✓"

# ── 2. Create .env from template ─────────────────────────────────────────────
log "Checking .env file..."

if [[ -f ".env" ]]; then
    warn ".env already exists — skipping creation. Delete it to re-generate."
else
    if [[ ! -f ".env.template" ]]; then
        die ".env.template not found. Are you in the project root?"
    fi
    cp .env.template .env
    success "Created .env from .env.template"
    warn "Review .env and set WEBHOOK_SITE_ID and GRAFANA_ADMIN_PASSWORD before going to production."
fi

# Source the env file to pick up port values
set -o allexport
# shellcheck disable=SC1091
source .env
set +o allexport

# ── 3. Pre-flight checks ──────────────────────────────────────────────────────
log "Running pre-flight checks..."

# Ensure required config files exist
for f in docker-compose.yml nginx/nginx.conf prometheus/prometheus.yml prometheus/alerts.yml \
          prometheus/alertmanager.yml grafana/dashboards/devops-stack.json; do
    [[ -f "$f" ]] || die "Required file missing: $f"
done
success "All config files present ✓"

# Check for port conflicts
check_port() {
    local port=$1 service=$2
    if lsof -iTCP:"$port" -sTCP:LISTEN -n -P &>/dev/null 2>&1; then
        warn "Port $port ($service) is already in use. Update .env if needed."
    fi
}
check_port "${NGINX_HTTP_PORT:-80}"    "Nginx"
check_port "${PROMETHEUS_PORT:-9090}"  "Prometheus"
check_port "${GRAFANA_PORT:-3000}"     "Grafana"
check_port "${ALERTMANAGER_PORT:-9093}" "Alertmanager"

# ── 4. Build and start services ───────────────────────────────────────────────
log "Building images (this may take a minute on first run)..."
$COMPOSE_CMD build --quiet

log "Starting all services..."
$COMPOSE_CMD up -d --remove-orphans

# ── 5. Wait for health checks ─────────────────────────────────────────────────
TIMEOUT=120   # seconds
INTERVAL=5    # seconds between polls

declare -A SERVICE_CHECKS=(
    ["api"]="http://localhost:${NGINX_HTTP_PORT:-80}/health"
    ["nginx"]="http://localhost:${NGINX_HTTP_PORT:-80}/nginx-health"
    ["prometheus"]="http://localhost:${PROMETHEUS_PORT:-9090}/-/healthy"
    ["grafana"]="http://localhost:${GRAFANA_PORT:-3000}/api/health"
    ["alertmanager"]="http://localhost:${ALERTMANAGER_PORT:-9093}/-/healthy"
)

echo ""
log "Waiting for services to become healthy (timeout: ${TIMEOUT}s)..."

ALL_HEALTHY=true

for service in "${!SERVICE_CHECKS[@]}"; do
    url="${SERVICE_CHECKS[$service]}"
    elapsed=0
    printf "  %-15s " "$service"

    until curl -sf "$url" &>/dev/null; do
        if [[ $elapsed -ge $TIMEOUT ]]; then
            echo -e "${RED}✗ TIMEOUT${NC}"
            error "$service failed health check at $url after ${TIMEOUT}s"
            ALL_HEALTHY=false
            break
        fi
        printf "."
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
    done

    if curl -sf "$url" &>/dev/null; then
        echo -e " ${GREEN}✓ healthy${NC} (${elapsed}s)"
    fi
done

echo ""

# ── 6. Final status ───────────────────────────────────────────────────────────
if [[ "$ALL_HEALTHY" == true ]]; then
    success "All services are healthy! 🚀"
    echo ""
    echo -e "${BOLD}Service URLs:${NC}"
    echo -e "  API         → http://localhost:${NGINX_HTTP_PORT:-80}"
    echo -e "  Prometheus  → http://localhost:${PROMETHEUS_PORT:-9090}"
    echo -e "  Grafana     → http://localhost:${GRAFANA_PORT:-3000}  (admin / \$GRAFANA_ADMIN_PASSWORD)"
    echo -e "  Alertmanager→ http://localhost:${ALERTMANAGER_PORT:-9093}"
    echo ""
    echo -e "  ${CYAN}Run smoke tests:${NC}  bash smoke-test.sh"
    echo -e "  ${CYAN}Run load test:${NC}    bash load-test.sh"
    echo ""
    exit 0
else
    echo ""
    error "Some services failed their health checks. Check logs with:"
    echo "  $COMPOSE_CMD logs --tail=50 <service>"
    exit 1
fi
